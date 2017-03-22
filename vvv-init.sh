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
# MySQL Root
# 	User: root
# 	pass: root
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
# Note: If edited, you'll need to edit it also in the vvv-hosts and the vvv-nginx.conf files as well.
# Default: "wp-reference.dev"
readonly REFERENCE_HOME_URL="wp-reference.dev"

# Parse the source code with WP Parser when provisioning.
# Default: true
readonly PARSE_SOURCE_CODE=true

# If set to true the --quick subcommand is added to the "wp parser" command. 
# Default: false
readonly WP_PARSER_QUICK_MODE=false

# Delete all tables in the database when provisioning (re-installs WP).
# Default: false
readonly RESET_WORDPRESS=false

# Update the assets when provisioning.
# Note:
#   Assets are deleted before being updated if set to true.
#
# Default: false
readonly UPDATE_ASSETS=false

# The WordPress version (in the /source-code directory) to be parsed by the WP Parser.
#
# Note:
# 	Use "latest" or a valid WordPress version in quotes (e.g. "4.4")
# 	Deleting the /source-code dir will re-install WordPress (instead of updating it).
# 	Use an empty string "" to not install/update WP in the /source-code dir. This Let's you parse other code than WP
#
# Default: "latest"
readonly SOURCE_CODE_WP_VERSION="latest"

# Exclude external libraries when parsing.
# Default: true
readonly EXCLUDE_WP_EXTERNAL_LIBS=true


# =============================================================================
# 
# That's all, stop editing! Happy parsing.
# 
# =============================================================================


# =============================================================================
# Root mysql credentials
# =============================================================================

readonly MYSQL_USER='root'

readonly MYSQL_PASSWORD='root'


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

	local activated=$(wp $wptype list --status=active --fields=name --format=csv --allow-root)

	while read -r line; do
		if [[ $line == $name ]]; then
			return 0
		fi
	done <<< "$activated"

	return 1
}

function assets(){
	local action=$1
	local wptype=$2
	local asset=$3

	if [[ $action == "delete" ]]; then
		if $(wp "$wptype" is-installed "$asset" --allow-root); then
			if is_file "$WPCLI_COMMANDS_FILE" && [[ "$wptype" == "theme" ]]; then
				local default_theme="$(wp --require="$WPCLI_COMMANDS_FILE" wp-parser-reference theme get_default --allow-root)"
				wp theme activate "$default_theme" --allow-root
			fi
			wp "$wptype" delete "$asset" --allow-root 2>&1 >/dev/null
		fi
	fi

	if [[ $action == "activate" ]]; then
		if $(wp "$wptype" is-installed "$asset" --allow-root 2> /dev/null); then
			#activate plugin wp-parser
			if ! is_activated "$asset" "$wptype"; then
				printf "Activating $wptype $asset...\n"
				wp "$wptype" activate "$asset" --allow-root
			else
				printf "$wptype $asset is activated...\n"
			fi
		else
			printf "\033[0m\nNotice: $wptype $asset is not installed\033[0m\n"
		fi
	fi
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
		printf "\e[31mNo network connection detected. Unable to reach google.com...\033[0m\n"
		local ping_result="Not Connected"
	fi

	# =============================================================================
	# Create database for reference
	# =============================================================================
	
	# check if database exists
	printf "Creating database 'wordpress-reference' (if it doesn't exist yet)...\n"
	mysql -u $MYSQL_USER --password="$MYSQL_PASSWORD" -e "CREATE DATABASE IF NOT EXISTS \`wordpress-reference\`"
	mysql -u $MYSQL_USER --password="$MYSQL_PASSWORD" -e "GRANT ALL PRIVILEGES ON \`wordpress-reference\`.* TO wp@localhost IDENTIFIED BY 'wp';"


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
	# Install or update all the things if connected
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

			if [[ "$instal_new" = true || "$UPDATE_ASSETS" = true ]]; then

				# =============================================================================
				# Delete assets
				# =============================================================================

				assets "delete" "plugin" "hello"
				assets "delete" "plugin" "wp-parser"
				assets "delete" "plugin" "syntaxhighlighter"
				assets "delete" "plugin" "handbook"
				assets "delete" "theme" "wporg-developer"

				# =============================================================================
				# install assets
				# =============================================================================

				cd "$REFERENCE_PLUGIN_PATH"

				# Install phpdoc-parser
				printf "Installing plugin wp-parser...\n"
				git clone https://github.com/WordPress/phpdoc-parser.git wp-parser
				printf "Installing wp-parser dependencies...\n"
				cd wp-parser
				composer install
				composer dump-autoload

				# Install syntaxhighlighter
				printf "Installing plugin syntaxhighlighter...\n"
				svn checkout https://plugins.svn.wordpress.org/syntaxhighlighter/trunk "$REFERENCE_PLUGIN_PATH/syntaxhighlighter"

				# Install handbook
				printf "Installing plugin handbook...\n"
				svn checkout http://meta.svn.wordpress.org/sites/trunk/wordpress.org/public_html/wp-content/plugins/handbook/ "$REFERENCE_PLUGIN_PATH/handbook"

				cd "$REFERENCE_THEME_PATH"

				# Install theme wporg-developer
				printf "Installing theme wporg-developer...\n"
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

			if [[ "$SOURCE_CODE_WP_VERSION" != "" ]]; then

				cd "$SOURCE_CODE_PATH"

				printf "Downloading WordPress $SOURCE_CODE_WP_VERSION in $SOURCE_CODE_PATH...\n"
				if [[ "$SOURCE_CODE_WP_VERSION" = "latest" ]]; then
					wp core download --allow-root
				else
					wp core download --version="$SOURCE_CODE_WP_VERSION" --force --allow-root
				fi

				# Create wp-config without checking if database exist.
				wp core config --dbname="wordpress-source-reference" --dbuser=wp --dbpass=wp --dbhost="localhost" --skip-check --allow-root
			fi
		else

			if [[ "$SOURCE_CODE_WP_VERSION" != "" ]]; then

				cd "$SOURCE_CODE_PATH"

				printf "Updating WordPress $SOURCE_CODE_WP_VERSION in $SOURCE_CODE_PATH\n"

				# Install the source-code WordPress install to be able to update
				if ! wp_core_is_installed && is_file "$SOURCE_CODE_PATH/wp-config.php"; then
					mysql -u "$MYSQL_USER" --password="$MYSQL_PASSWORD" -e "CREATE DATABASE IF NOT EXISTS \`wordpress-source-reference\`"
					mysql -u "$MYSQL_USER" --password="$MYSQL_PASSWORD" -e "GRANT ALL PRIVILEGES ON \`wordpress-source-reference\`.* TO wp@localhost IDENTIFIED BY 'wp';"

					wp core install --url="wp-source.dev" --title="Source" --admin_user=admin --admin_password=password --admin_email=demo@example.com --allow-root 2>&1 >/dev/null
				else
					printf "\e[31mNo WordPress install found in $SOURCE_CODE_PATH\n"
					printf "To re-install WordPress delete the directory $SOURCE_CODE_PATH\033[0m\n"
				fi

				if wp_core_is_installed; then
					if [[ "$SOURCE_CODE_WP_VERSION" = "latest" ]]; then
						wp core update --force --allow-root
					else
						wp core update --version="$SOURCE_CODE_WP_VERSION" --force --allow-root
					fi

				fi

				# Delete database as it's only needed for updating WordPress
				$(wp db drop --yes --quiet --allow-root 2> /dev/null)
			fi
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
		# Activate assets
		# =============================================================================
		assets "activate" "plugin" "wp-parser"
		assets "activate" "plugin" "syntaxhighlighter"
		assets "activate" "plugin" "handbook/handbook"
		assets "activate" "plugin" "handbook/functionality-for-pages"
		assets "activate" "theme" "wporg-developer"

		assets "delete" "plugin" "exclude-wp-external-libs"
		if is_file "$CURRENT_PATH/exclude-wp-external-libs.php" && [[ "$EXCLUDE_WP_EXTERNAL_LIBS" = true ]]; then
			cp "$CURRENT_PATH/exclude-wp-external-libs.php" "$REFERENCE_PLUGIN_PATH/exclude-wp-external-libs.php"
			assets "activate" "plugin" "exclude-wp-external-libs"
		fi

		# =============================================================================
		# Set permalink structure
		# =============================================================================
		printf "Set permalink structure to postname...\n"
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
			printf "\e[31mSkipped parsing. Source code directory doesn't exist\033[0m\n"
		fi

		# =============================================================================
		# create pages and nav menu if needed
		# =============================================================================
		if is_file "$WPCLI_COMMANDS_FILE"; then

			cd "$REFERENCE_SITE_PATH"

			printf "Creating reference pages (if needed)...\n"
			wp --require="$WPCLI_COMMANDS_FILE" wp-parser-reference pages create --allow-root
			printf "Creating empty nav menu (if needed)...\n"
			wp --require="$WPCLI_COMMANDS_FILE" wp-parser-reference nav_menu create --allow-root
		fi
	else
		printf "\e[31mSkipped parsing. WordPress is not installed in: $REFERENCE_SITE_PATH\033[0m\n"
	fi

	cd "$REFERENCE_SITE_PATH"

	assets "delete" "plugin" "exclude-wp-external-libs"

	printf "Flushing permalink structure...\n"
	wp rewrite flush --allow-root

	cd "$CURRENT_PATH"
	printf "Finished Setup $REFERENCE_HOME_URL!\n"
}

printf "\nCommencing Setup $REFERENCE_HOME_URL\n"

# create vvv-hosts file or .conf file if it's an Apache box.
create_files

# create reference
setup_reference