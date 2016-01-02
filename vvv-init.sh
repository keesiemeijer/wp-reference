# =============================================================================
# VVV auto site setup script to mirror the WordPress code reference.
# https://developer.wordpress.org
# 
# By keesiemeijer
# https://github.com/keesiemeijer/wp-reference
# 
# Also Compatible with the VVV Apache variant.
# https://github.com/ericmann/vvv-apache
# 
# This script follows these directions to mirror the code reference:
# http://make.wordpress.org/docs/handbook/projects/devhub/
# 
# When provisioning this script will:
# 	if the directories /public and /source-code don't exist (inside the wp-reference directory):
# 	    Create directories /public and /source-code.
# 	    Download WordPress inside both directories
# 	    Install Wordpress (in the /public dir) with domain 'wp-reference.dev'.
# 	Update Wordpress in both directories.
# 	Install and activate the plugin WP Parser and theme wporg-developer.
# 	Download and edit the header.php and footer.php files from wordpress.org.
# 	Parse the /source-code directory with the WP Parser plugin.
# 	Create a static front page (if needed).
# 	Create a reference page (if needed).
# 
# Credentials
# 	URL:      wp-reference.dev
# 	Username: admin
# 	Password: password
# 	DB Name:  wordpress-reference
# 
# Resources
# 	https://github.com/keesiemeijer/wp-reference
# 	https://github.com/Varying-Vagrant-Vagrants/VVV
# 	https://github.com/varying-vagrant-vagrants/vvv/wiki/Auto-site-Setup
# 	https://github.com/rmccue/WP-Parser
# 	https://github.com/Rarst/wporg-developer
# 
# To change the domain name 'wp-reference.dev':
# 	- edit the domain in REFERENCE_HOME_URL below
# 	- edit the domain in the vvv-hosts file
# 	- edit the domain in the vvv-nginx.conf file
# 
# Notes:
# 	- WordPress will be updated (if needed) when provisioning
# 	- Manually deleting the /public or /source-code directory prior to provisioning will re-install WordPress
# 	- If you want to parse older versions of wordpress it's best to manually delete the source-code dir before provisioning
# 
# =============================================================================


# =============================================================================
# Variables
# 
# Note: Don't use spaces around the equal sign when editing variables below.
# =============================================================================

# Domain name
#
# Note: If edited, you'll need to edit it in the vvv-hosts and the vvv-nginx.conf files as well.
readonly REFERENCE_HOME_URL="wp-reference.dev"

# Parse the source code with WP Parser when provisioning.
readonly PARSE_SOURCE_CODE=true

# If set to true the --quick subcommand is added to the "wp parser" command. Default: false
readonly WP_PARSER_QUICK_MODE=false

# Delete all tables in the database when provisioning (re-installs WP). Default: false
readonly RESET_WORDPRESS=false

# Update the plugin wp-parser and theme wporg-developer when provisioning. Default: false
readonly UPDATE_ASSETS=false

# WordPress version (in the /source-code directory) to be parsed by WP Parser. Default: "latest"
# 
# Note: If not set to "latest" it's best to delete the /source-code directory manually prior to provisioning.
#       This will re-install (instead of update) the older WP version and ensures only files from that version will be parsed.
readonly SOURCE_CODE_WP_VERSION="latest"

# Exclude external libraries when parsing.
readonly EXCLUDE_WP_EXTERNAL_LIBS=true


# =============================================================================
# 
# That's all, stop editing! Happy parsing.
# 
# =============================================================================


# =============================================================================
# Directories 
# =============================================================================

# current path
readonly CURRENT_PATH=`pwd`

# DocumentRoot dir in .conf file (if server is Apache)
readonly CURRENT_DIR="${PWD##*/}"

# path to the WordPress install for the developer reference website
readonly REFERENCE_SITE_PATH="$CURRENT_PATH/public"

# source code directory to be parsed by WP Parser
readonly SOURCE_CODE_PATH="$CURRENT_PATH/source-code"

# WP-CLI command file. Creates pages and gets the default theme for a WordPress install
readonly WPCLI_COMMANDS_FILE="$CURRENT_PATH/wp-cli-reference.php"


# =============================================================================
# Functions
# =============================================================================
function is_file() {
	local file=$1
	[[ -f $file ]]
}


function is_dir() {
	local dir=$1
	[[ -d $dir ]]
}


function wp_core_is_installed(){
	$(wp core is-installed --allow-root 2> /dev/null)
}

function is_activated(){
	local name=$1
	local wptype=$2

	local status='inactive'
	if [[ $wptype == "plugin" ]]; then
		local activated=$(wp plugin list --status=active --fields=name --format=csv --allow-root)
	fi

	if [[ $wptype == "theme" ]]; then
		local activated=$(wp theme list --status=active --fields=name --format=csv --allow-root)
	fi

	while read -r line; do
		if [[ $line == $name ]]; then
			status='active'
		fi
	done <<< "$activated"

	echo $status;
}


function install_WordPress {

	cd "$REFERENCE_SITE_PATH"

	if ! wp_core_is_installed; then
		# tables don't exist
		printf "Installing $REFERENCE_HOME_URL in $REFERENCE_SITE_PATH...\n"
		wp core install --url="$REFERENCE_HOME_URL" --title="WordPress Developer Reference" --admin_user=admin --admin_password=password --admin_email=demo@example.com --allow-root
	else
		#tables exist
		if [[ "$RESET_WORDPRESS" = true ]]; then
			printf "Dropping tables in 'wordpress-reference' database...\n"
			wp db reset --yes --allow-root
			printf "Installing $REFERENCE_HOME_URL in $REFERENCE_SITE_PATH...\n"
			wp core install --url="$REFERENCE_HOME_URL" --title="WordPress Developer Reference" --admin_user=admin --admin_password=password --admin_email=demo@example.com --allow-root
		fi
	fi

	return
}


function create_files {

	# =============================================================================
	# Create vvv-hosts file (if it doesn't exist)
	# =============================================================================

	if ! is_file "$CURRENT_PATH/vvv-hosts"; then
		printf "Creating vvv-hosts file in $CURRENT_PATH\n"
		touch "$CURRENT_PATH/vvv-hosts"
		printf "$REFERENCE_HOME_URL\n" >> "$CURRENT_PATH/vvv-hosts"
	fi

	# =============================================================================
	# Create .conf file for Apache (if it doesn't exist)
	# =============================================================================

	if is_dir "/srv/config/apache-config/sites"; then
		if ! is_file "/srv/config/apache-config/sites/$CURRENT_DIR.conf"; then
			cd srv/config/apache-config/sites
			printf "Creating $CURRENT_DIR.conf in /srv/config/apache-config/sites/...\n"
			sed -e "s/testserver\.com/$REFERENCE_HOME_URL/" \
			-e "s/wordpress-local/$CURRENT_DIR\/public/" local-apache-example.conf-sample > "$CURRENT_DIR.conf"
		fi
	fi
}

# =============================================================================
# Main function for reference creation
# =============================================================================
function setup_reference {

	local REFERENCE_PLUGIN_PATH
	local REFERENCE_THEME_PATH
	
	printf "Checking network connection...\n"

	# =============================================================================
	# Network Detection
	#
	# Make an HTTP request to google.com to determine if outside access is available
	# to us. If 3 attempts with a timeout of 5 seconds are not successful, then we'll
	# skip a few things further in provisioning rather than create a bunch of errors.
	# =============================================================================
	if [[ "$(wget --tries=3 --timeout=5 --spider http://google.com 2>&1 | grep 'connected')" ]]; then
		printf "Network connection detected...\n"
		local ping_result="Connected"
	else
		printf "Network connection not detected. Unable to reach google.com...\n"
		local ping_result="Not Connected"
	fi

	# =============================================================================
	# Create database for reference
	# =============================================================================
	
	# check if database exists
	printf "Creating database 'wordpress-reference' (if it doesn't exist yet)...\n"
	mysql -u root --password=root -e "CREATE DATABASE IF NOT EXISTS \`wordpress-reference\`"
	mysql -u root --password=root -e "GRANT ALL PRIVILEGES ON \`wordpress-reference\`.* TO wp@localhost IDENTIFIED BY 'wp';"


	# =============================================================================
	# Create dir for reference
	# =============================================================================
	local instal_new=false
	if ! is_dir "$REFERENCE_SITE_PATH"; then
		printf "Creating directory $REFERENCE_SITE_PATH...\n"
		instal_new=true
		mkdir "$REFERENCE_SITE_PATH"
	fi

	# =============================================================================
	# Install/update all the things if connected
	# =============================================================================
	if [[ $ping_result == "Connected" ]]; then

		cd "$REFERENCE_SITE_PATH"

		# =============================================================================
		# download WordPress
		# =============================================================================
		if [[ "$instal_new" = true ]]; then
		
			printf "Downloading WordPress in $REFERENCE_SITE_PATH...\n"
			wp core download --allow-root

			printf "Creating wp-config in $REFERENCE_SITE_PATH...\n"
			wp core config --dbname="wordpress-reference" --dbuser=wp --dbpass=wp --dbhost="localhost" --allow-root --extra-php <<PHP
define( 'WPORGPATH', "$REFERENCE_SITE_PATH/wp-content/themes/" );
define ('WP_DEBUG', false);
PHP
		fi

		# =============================================================================
		# Install WordPress
		# =============================================================================
		install_WordPress

		if wp_core_is_installed; then
		
			REFERENCE_PLUGIN_PATH=$(wp plugin path --allow-root)
			REFERENCE_THEME_PATH=$(wp theme path --allow-root)

			# =============================================================================
			# Install and update assets
			# =============================================================================
			if [[ "$instal_new" = true || "$UPDATE_ASSETS" = true ]]; then

				#delete plugin wp-parser (if it exists)
				if $(wp plugin is-installed wp-parser --allow-root); then
					wp plugin delete wp-parser --allow-root 2>&1 >/dev/null
				fi

				#delete theme wporg-developer (if it exists)
				if $(wp theme is-installed wporg-developer --allow-root); then
					if is_file "$WPCLI_COMMANDS_FILE"; then
						local default_theme="$(wp --require="$WPCLI_COMMANDS_FILE" wp-parser-reference theme get_default --allow-root)"
						wp theme activate "$default_theme" --allow-root
					fi
					wp theme delete wporg-developer --allow-root 2>&1 >/dev/null
				fi

				cd "$REFERENCE_PLUGIN_PATH"

				printf 'Installing plugin wp-parser...\n'
				git clone https://github.com/WordPress/phpdoc-parser.git wp-parser
				printf 'Installing wp-parser dependencies...\n'
				cd wp-parser
				composer install
				composer dump-autoload

				cd "$REFERENCE_THEME_PATH"

				#install theme wporg-developer
				printf 'Installing theme wporg-developer...\n'
				svn checkout http://meta.svn.wordpress.org/sites/trunk/wordpress.org/public_html/wp-content/themes/pub/wporg-developer/

				printf "Downloading and editing header.php and footer.php in $REFERENCE_THEME_PATH...\n"
				curl -s -O https://wordpress.org/header.php
				printf "\n<?php wp_head(); ?>\n" >> header.php
				curl -s -O https://wordpress.org/footer.php
				sed -e 's|</body>|<?php wp_footer(); ?>\n</body>\n|g' footer.php > footer.php.tmp && mv footer.php.tmp footer.php
			fi

			cd "$REFERENCE_SITE_PATH"

			# =============================================================================
			# Update wp-reference.dev website
			# =============================================================================
			if [[ "$instal_new" = false ]]; then
					printf "Updating WordPress in $REFERENCE_SITE_PATH\n"
					wp core update --allow-root
			fi
		fi

		# =============================================================================
		# Install or Update WP in source code directory
		# =============================================================================
		if ! is_dir "$SOURCE_CODE_PATH"; then
			#install WordPress in source code directory
			mkdir "$SOURCE_CODE_PATH"

			cd "$SOURCE_CODE_PATH"

			printf "Downloading WordPress $SOURCE_CODE_WP_VERSION in $SOURCE_CODE_PATH...\n"
			if [[ "$SOURCE_CODE_WP_VERSION" = "latest" ]]; then
				wp core download --allow-root
			else
				wp core download --version="$SOURCE_CODE_WP_VERSION" --force --allow-root
			fi

			# Create wp-config without checking if database exist.
			wp core config --dbname="wordpress-source-reference" --dbuser=wp --dbpass=wp --dbhost="localhost" --skip-check --allow-root
		else

			cd "$SOURCE_CODE_PATH"

			printf "Updating WordPress $SOURCE_CODE_WP_VERSION in $SOURCE_CODE_PATH\n"

			# install source to update
			if ! wp_core_is_installed; then
				mysql -u root --password=root -e "CREATE DATABASE IF NOT EXISTS \`wordpress-source-reference\`"
				mysql -u root --password=root -e "GRANT ALL PRIVILEGES ON \`wordpress-source-reference\`.* TO wp@localhost IDENTIFIED BY 'wp';"

				wp core install --url="wp-source.dev" --title="Source" --admin_user=admin --admin_password=password --admin_email=demo@example.com --allow-root 2>&1 >/dev/null
			fi

			if [[ "$SOURCE_CODE_WP_VERSION" = "latest" ]]; then
				wp core update --force --allow-root 
			else
				wp core update --version="$SOURCE_CODE_WP_VERSION" --force --allow-root
			fi

			wp db drop --yes --allow-root 2>&1 >/dev/null
		fi

	else
		# no network connection
		printf "Skipped installing/updating. No network connection found\n"
		if [[ "$instal_new" = false ]]; then
			# maybe reset and install WordPress again 
			install_WordPress
		fi
	fi

	cd "$REFERENCE_SITE_PATH"

	if wp_core_is_installed; then
	
		REFERENCE_PLUGIN_PATH=$(wp plugin path --allow-root)
		REFERENCE_THEME_PATH=$(wp theme path --allow-root)

		# =============================================================================
		# delete exclude-wp-external-libs.php before parsing
		# =============================================================================
		if $(wp plugin is-installed exclude-wp-external-libs --allow-root); then
			wp plugin delete exclude-wp-external-libs --allow-root 2>&1 >/dev/null
		fi

		# =============================================================================
		# activate exclude-wp-external-libs.php if $EXCLUDE_WP_EXTERNAL_LIBS is true
		# =============================================================================
		if [[ "$EXCLUDE_WP_EXTERNAL_LIBS" = true ]]; then
			if is_file "$CURRENT_PATH/exclude-wp-external-libs.php"; then
				cp "$CURRENT_PATH/exclude-wp-external-libs.php" "$REFERENCE_PLUGIN_PATH/exclude-wp-external-libs.php"
				if $(wp plugin is-installed exclude-wp-external-libs --allow-root 2> /dev/null); then
					if [ $(is_activated exclude-wp-external-libs plugin) != 'active' ]; then
						printf 'Activating plugin exclude-wp-external-libs...\n'
						wp plugin activate exclude-wp-external-libs --allow-root
					else
						printf 'Plugin exclude-wp-external-libs is activated...\n'
					fi
				fi
			fi
		fi

		# =============================================================================
		# activate wp-parser and wporg-developer and set permalink structure
		# =============================================================================
		if $(wp plugin is-installed wp-parser --allow-root 2> /dev/null); then
			#activate plugin wp-parser
			if [ $(is_activated wp-parser plugin) != 'active' ]; then
				printf 'Activating plugin wp-parser...\n'
				wp plugin activate wp-parser --allow-root
			else
				printf 'Plugin wp-parser is activated...\n'
			fi
		else
			printf 'Notice: plugin WP Parser is not installed\n'
		fi

		if $(wp theme is-installed wporg-developer --allow-root 2> /dev/null); then
			#activate theme
			if [ $(is_activated wporg-developer theme) != 'active' ]; then
				printf 'Activating theme wporg-developer...\n'
				wp theme activate wporg-developer --allow-root
			else
				printf 'Theme wporg-developer is activated...\n'
			fi
		else
			printf 'Notice: theme wporg-developer is not installed\n'
		fi

		# =============================================================================
		# Set permalink structure
		# =============================================================================
		printf 'Set permalink structure to postname...\n'
		wp rewrite structure '/%postname%/' --allow-root
		wp rewrite flush --allow-root

		# =============================================================================
		# parse source code with WP Parser
		# =============================================================================
		if is_dir "$SOURCE_CODE_PATH"; then

			if [[ "$PARSE_SOURCE_CODE" = true ]]; then
				cd "$REFERENCE_PLUGIN_PATH"

				printf "Proceed parsing source code directory $SOURCE_CODE_PATH...\n"
				if [[ "$WP_PARSER_QUICK_MODE" = true  ]]; then
					wp parser create "$SOURCE_CODE_PATH" --user=1 --quick --allow-root
				else
					wp parser create "$SOURCE_CODE_PATH" --user=1 --allow-root
				fi
			fi

		else
			printf "Skipped parsing. Source code directory doesn't exist\n"
		fi

		# =============================================================================
		# create pages if needed
		# =============================================================================
		if is_file "$WPCLI_COMMANDS_FILE"; then

			cd "$REFERENCE_SITE_PATH"

			printf 'Creating reference pages (if needed)...\n'
			wp --require="$WPCLI_COMMANDS_FILE" wp-parser-reference pages create --allow-root
			printf 'Flushing permalink structure...\n'
			wp rewrite flush --allow-root
		fi
	else
		printf "Skipped parsing. WordPress is not installed in: $REFERENCE_SITE_PATH\n"
	fi

	cd "$REFERENCE_SITE_PATH"

	# =============================================================================
	# delete exclude-wp-external-libs.php from /wp-content/plugins/ after parsing
	# =============================================================================
	if $(wp plugin is-installed exclude-wp-external-libs --allow-root); then
		wp plugin delete exclude-wp-external-libs --allow-root 2>&1 >/dev/null
	fi

	cd "$CURRENT_PATH"
	printf "Finished Setup $REFERENCE_HOME_URL!\n"
}

printf "\nCommencing Setup $REFERENCE_HOME_URL\n"

# create vvv-hosts file or .conf file if it's an Apache box.
create_files

# create reference
setup_reference