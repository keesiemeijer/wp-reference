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
REFERENCE_HOME_URL="wp-reference.dev"

# Parse the source code with WP Parser when provisioning.
PARSE_SOURCE_CODE=true

# If set to true the --quick subcommand is added to the "wp parser" command. Default: false
WP_PARSER_QUICK_MODE=false

# Delete all tables in the database when provisioning (re-installs WP). Default: false
RESET_WORDPRESS=false

# Update the plugin wp-parser and theme wporg-developer when provisioning. Default: false
UPDATE_ASSETS=false

# WordPress version (in the /source-code directory) to be parsed by WP Parser. Default: "latest"
# 
# Note: If not set to "latest" it's best to delete the /source-code directory manually prior to provisioning.
#       This will re-install (instead of update) the older WP version and ensures only files from that version will be parsed.
SOURCE_CODE_WP_VERSION="latest"


# =============================================================================
# 
# That's all, stop editing! Happy parsing.
# 
# =============================================================================


# =============================================================================
# Directories 
# =============================================================================

# current path
CURRENT_PATH=`pwd`

# DocumentRoot dir in .conf file (if server is Apache)
CURRENT_DIR="${PWD##*/}"

# path to the WordPress install for the developer reference website
REFERENCE_SITE_PATH="$CURRENT_PATH/public"

# source code directory to be parsed by WP Parser
SOURCE_CODE_PATH="$CURRENT_PATH/source-code"

# WP-CLI command file. Creates pages and gets the default theme for a WordPress install
WPCLI_COMMAND_FILE_PATH="$CURRENT_PATH/wp-cli-reference.php"


printf "\nCommencing Setup $REFERENCE_HOME_URL\n"

# =============================================================================
# Create vvv-hosts file (if it doesn't exist)
# =============================================================================

if [[ ! -f $CURRENT_PATH/vvv-hosts ]]; then
	printf "Creating vvv-hosts file in $CURRENT_PATH\n"
	touch $CURRENT_PATH/vvv-hosts
	printf "$REFERENCE_HOME_URL\n" >> $CURRENT_PATH/vvv-hosts
fi

# =============================================================================
# Create .conf file for Apache (if it doesn't exist)
# =============================================================================

if [[ -d /srv/config/apache-config/sites ]]; then
	if [[ ! -f /srv/config/apache-config/sites/$CURRENT_DIR.conf ]]; then
		cd srv/config/apache-config/sites
		printf "Creating $CURRENT_DIR.conf in /srv/config/apache-config/sites/...\n"
		sed -e "s/testserver\.com/$REFERENCE_HOME_URL/" \
		-e "s/wordpress-local/$CURRENT_DIR\/public/" local-apache-example.conf-sample > $CURRENT_DIR.conf
	fi
fi


# =============================================================================
# Create database
# =============================================================================

printf "Creating database 'wordpress-reference' if needed...\n"
mysql -u root --password=root -e "CREATE DATABASE IF NOT EXISTS \`wordpress-reference\`"
mysql -u root --password=root -e "GRANT ALL PRIVILEGES ON \`wordpress-reference\`.* TO wp@localhost IDENTIFIED BY 'wp';"

# =============================================================================
# function to install wordpress
# =============================================================================
function install_wordpress {

	wp_ref_path=$1
	wp_ref_url=$2
	drop_tables=$3

	cd $wp_ref_path

	if ! $(wp core is-installed --allow-root 2> /dev/null); then
		printf "Installing $wp_ref_url in $wp_ref_path...\n"
		wp core install --url=$wp_ref_url --title="WordPress Developer Reference" --admin_user=admin --admin_password=password --admin_email=demo@example.com --allow-root
	else
		if [[ "$drop_tables" = true ]]; then
			printf "Dropping all tables in 'wordpress-reference' database...\n"
			wp db reset --yes --allow-root
			printf "Installing $wp_ref_url in $wp_ref_path...\n"
			wp core install --url=$wp_ref_url --title="WordPress Developer Reference" --admin_user=admin --admin_password=password --admin_email=demo@example.com --allow-root
		fi
	fi

	return
}


# =============================================================================
# Connection
#
# Capture a basic ping result to Google's primary DNS server to determine if
# outside access is available to us. If this does not reply after 2 attempts,
# we try one of Level3's DNS servers as well. If neither IP replies to a ping,
# then we'll skip a few things further in provisioning rather than creating a
# bunch of errors.
# =============================================================================

printf "Checking network connection...\n"

ping_result="$(ping -c 2 8.8.4.4 2>&1)"
if [[ $ping_result != *bytes?from* ]]; then
	ping_result="$(ping -c 2 4.2.2.2 2>&1)"
fi

if [[ $ping_result == *bytes?from* ]]; then	
	CONNECTION=true
else
	CONNECTION=false
fi

# =============================================================================
# Create dir for reference
# =============================================================================
instal_new=false
if [[ ! -d $REFERENCE_SITE_PATH ]]; then
	printf "Creating directory $REFERENCE_SITE_PATH...\n"
	instal_new=true
	mkdir $REFERENCE_SITE_PATH
fi

# =============================================================================
# Install all the things if connected
# =============================================================================
if [[ "$CONNECTION" = true ]]; then

	# =============================================================================
	# download WordPress
	# =============================================================================
	if [[ "$instal_new" = true ]]; then

		cd $REFERENCE_SITE_PATH

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
	install_wordpress $REFERENCE_SITE_PATH $REFERENCE_HOME_URL $RESET_WORDPRESS

	cd $REFERENCE_SITE_PATH

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
			default_theme=$(wp --require=$WPCLI_COMMAND_FILE_PATH wp-parser-reference theme get_default --allow-root)
			wp theme activate $default_theme --allow-root
			wp theme delete wporg-developer --allow-root 2>&1 >/dev/null
		fi

		cd $REFERENCE_PLUGIN_PATH

		printf 'Installing plugin wp-parser...\n'
		git clone https://github.com/rmccue/WP-Parser.git wp-parser

		printf 'Installing wp-parser dependencies'
		cd wp-parser
		composer install

		cd $REFERENCE_THEME_PATH

		#install theme wporg-developer
		printf 'Installing theme wporg-developer...\n'
		git clone https://github.com/Rarst/wporg-developer

		printf "Downloading header.php and footer.php in $REFERENCE_THEME_PATH...\n"
		curl -s -O https://wordpress.org/header.php
		printf "\n<?php wp_head(); ?>\n" >> header.php
	    curl -s -O https://wordpress.org/footer.php
	    sed -e 's|</body>|<?php wp_footer(); ?>\n</body>\n|g' footer.php > footer.php.tmp && mv footer.php.tmp footer.php
	fi

	cd $REFERENCE_SITE_PATH

	# =============================================================================
	# Update wp-reference.dev website 
	# =============================================================================
	if [[ "$instal_new" = false ]]; then
		if $(wp core is-installed --allow-root 2> /dev/null); then
			cd $REFERENCE_SITE_PATH
			printf "Updating WordPress in $REFERENCE_SITE_PATH\n"
			wp core update --allow-root
		fi
	fi

	# =============================================================================
	# Install or Update WP in source code directory
	# =============================================================================
	if [[ ! -d $SOURCE_CODE_PATH ]]; then
		#install WordPress in source code directory
		mkdir $SOURCE_CODE_PATH

		cd $SOURCE_CODE_PATH

		printf "Downloading WordPress $SOURCE_CODE_WP_VERSION in $SOURCE_CODE_PATH...\n"
		if [[ $SOURCE_CODE_WP_VERSION = "latest" ]]; then
			wp core download --allow-root
		else
			wp core download --version=$SOURCE_CODE_WP_VERSION --force --allow-root
		fi

		wp core config --dbname="wordpress-reference" --dbuser=wp --dbpass=wp --dbhost="localhost" --skip-check --allow-root
	else
		cd $SOURCE_CODE_PATH

		printf "Updating WordPress $SOURCE_CODE_WP_VERSION in $SOURCE_CODE_PATH\n"

		if [[ $SOURCE_CODE_WP_VERSION = "latest" ]]; then
			wp core update --force --allow-root 
		else
			wp core update --version=$SOURCE_CODE_WP_VERSION --force --allow-root
		fi
	fi

else
	# no network connection
	printf "No network connection available, skipping downloading or updating WordPress Reference\n"
	if [[ "$instal_new" = false ]]; then
		install_wordpress $REFERENCE_SITE_PATH $REFERENCE_HOME_URL $RESET_WORDPRESS
	fi
fi

cd $REFERENCE_SITE_PATH

if $(wp core is-installed --allow-root 2> /dev/null); then

	REFERENCE_PLUGIN_PATH=$(wp plugin path --allow-root)
	REFERENCE_THEME_PATH=$(wp theme path --allow-root)

	# =============================================================================
	# activate plugin, theme and set permalink structure
	# =============================================================================
	if $(wp plugin is-installed wp-parser --allow-root 2> /dev/null); then
		#activate plugin wp-parser
		printf 'Activating plugin wp-parser...\n'
		wp plugin activate wp-parser --allow-root
	else
		printf 'Notice: plugin WP Parser is not installed\n'
	fi

	if $(wp theme is-installed wporg-developer --allow-root 2> /dev/null); then
		#activate theme
		printf 'Activating theme wporg-developer...\n'
		wp theme activate wporg-developer --allow-root
	else
		printf 'Notice: theme wporg-developer is not installed\n'
	fi

	#set permalinks
	printf 'Set permalink structure to Post Name...\n'
	wp rewrite structure '/%postname%/' --allow-root
	wp rewrite flush --allow-root

	# =============================================================================
	# parse source code with WP Parser
	# =============================================================================
	if [[ -d $SOURCE_CODE_PATH ]]; then

		if [[ "$PARSE_SOURCE_CODE" = true ]]; then
			cd $REFERENCE_PLUGIN_PATH

			printf "Proceed parsing source code directory $SOURCE_CODE_PATH...\n"
			if [[ "$WP_PARSER_QUICK_MODE" = true  ]]; then
				wp parser create $SOURCE_CODE_PATH --user=1 --quick --allow-root
			else
				wp parser create $SOURCE_CODE_PATH --user=1 --allow-root
			fi
		fi

	else
		printf "Skipped parsing. Source code directory doesn't exist\n"
	fi

	# =============================================================================
	# create pages if needed
	# =============================================================================
	if [[ -f $WPCLI_COMMAND_FILE_PATH ]]; then

		cd $REFERENCE_SITE_PATH

		printf 'Creating reference pages (if needed)...\n'
		wp --require=$WPCLI_COMMAND_FILE_PATH wp-parser-reference pages create --allow-root
		printf 'Flushing permalink structure...\n'
		wp rewrite flush --allow-root
	fi
else
	printf "Skipped parsing. WordPress is not installed in: $REFERENCE_SITE_PATH\n"
fi

printf "Finished creating or updating $REFERENCE_HOME_URL!\n"