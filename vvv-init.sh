# =============================================================================
# VVV auto site setup script to mirror the wordpress developer reference.
# https://developer.wordpress.org
# 
# By keesiemeijer
# https://github.com/keesiemeijer
# 
# Also Compatible with the VVV Apache variant.
# https://github.com/ericmann/vvv-apache
# 
# This script follows the directions to mirror the dev reference found on the devhub page:
# http://make.wordpress.org/docs/handbook/projects/devhub/
# 
# When provisioning this script will:
# 	Download WordPress in the directories /public and /source-code.
# 	Install Wordpress (in the public dir) with domain 'wp-reference.dev'.
# 	Install the plugin WP Parser and theme wporg-developer.
# 	Download and edit the header.php and footer.php files from wordpress.org.
# 	Parse the /source-code directory with the WP Parser plugin.
# 	Create a static front page.
# 	Create a reference page.
# 	
# Resources
# 	https://github.com/varying-vagrant-vagrants/vvv/wiki/Auto-site-Setup	
# 	https://github.com/rmccue/WP-Parser
# 	https://github.com/Rarst/wporg-developer
# 
# To change the domain 'wp-reference.dev':
# 	- edit the domain in REFERENCE_HOME_URL below
# 	- edit the domain in the vvv-hosts file
# 	- edit the domain in the vvv-nginx.conf file
# 	
# Notes:
# 	- Make sure you're online when provisioning for the first time.
# 	- WordPress will be updated when provisioning, except when a version is set (for the /source-code WP install)	
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


echo -e "\nCommencing Setup $REFERENCE_HOME_URL"

# =============================================================================
# Create vvv-hosts file (if it doesn't exist)
# =============================================================================

if [[ ! -f $CURRENT_PATH/vvv-hosts ]]; then
	echo "creating vvv-hosts file in $CURRENT_PATH"
	touch $CURRENT_PATH/vvv-hosts
	printf "$REFERENCE_HOME_URL\n" >> $CURRENT_PATH/vvv-hosts
fi

# =============================================================================
# Create .conf file for Apache (if it doesn't exist)
# =============================================================================

if [[ -d /srv/config/apache-config/sites ]]; then
	if [[ ! -f /srv/config/apache-config/sites/$CURRENT_DIR.conf ]]; then
		cd srv/config/apache-config/sites
		echo "Creating $CURRENT_DIR.conf in /srv/config/apache-config/sites/... "
		sed -e "s/testserver\.com/$REFERENCE_HOME_URL/" \
		-e "s/wordpress-local/$CURRENT_DIR\/public/" local-apache-example.conf-sample > $CURRENT_DIR.conf
	fi
fi


# =============================================================================
# Create database
# =============================================================================

echo "Creating database 'wordpress-reference' (if it does not exist)..."
mysql -u root --password=root -e "CREATE DATABASE IF NOT EXISTS \`wordpress-reference\`"
mysql -u root --password=root -e "GRANT ALL PRIVILEGES ON \`wordpress-reference\`.* TO wp@localhost IDENTIFIED BY 'wp';"


# =============================================================================
# Connection
#
# Capture a basic ping result to Google's primary DNS server to determine if
# outside access is available to us. If this does not reply after 2 attempts,
# we try one of Level3's DNS servers as well. If neither IP replies to a ping,
# then we'll skip a few things further in provisioning rather than creating a
# bunch of errors.
# =============================================================================
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
# Install all the stuff if connected
# =============================================================================
if [[ "$CONNECTION" = true ]]; then

	instal_new=false

	# =============================================================================
	# New install if directory doesn't exist
	# =============================================================================
	if [[ ! -d $REFERENCE_SITE_PATH ]]; then

		instal_new=true

		#install WordPress
		mkdir $REFERENCE_SITE_PATH
		cd $REFERENCE_SITE_PATH

		echo "Downloading WordPress in $REFERENCE_SITE_PATH..."
		wp core download --allow-root

		echo "Creating wp-config in $REFERENCE_SITE_PATH..."
		wp core config --dbname="wordpress-reference" --dbuser=wp --dbpass=wp --dbhost="localhost" --allow-root --extra-php <<PHP
define( 'WPORGPATH', "$REFERENCE_SITE_PATH/wp-content/themes/" );
define ('WP_DEBUG', false);
PHP
	fi

	# from now on $REFERENCE_SITE_PATH should exist
	cd $REFERENCE_SITE_PATH

	# start from scratch if $RESET_WORDPRESS is set
	if [[ "$RESET_WORDPRESS" = true  ]]; then
		echo "Dropping all tables in 'wordpress-reference' database..."
		wp db reset --yes --allow-root
	fi

	echo "Installing $REFERENCE_HOME_URL in $REFERENCE_SITE_PATH..."
	wp core install --url=$REFERENCE_HOME_URL --title="WordPress Developer Reference" --admin_user=admin --admin_password=password --admin_email=demo@example.com --allow-root

	# =============================================================================
	# Install and Update (assets) plugin WP Parser and theme wpord-developer
	# =============================================================================
	if [[ "$instal_new" = true || "$UPDATE_ASSETS" = true ]]; then

		cd $REFERENCE_SITE_PATH/wp-content/themes

		echo "Downloading header.php and footer.php in $REFERENCE_SITE_PATH/wp-content/themes/..."
		curl -s -O https://wordpress.org/header.php
		printf "\n<?php wp_head(); ?>\n" >> header.php

	    curl -s -O https://wordpress.org/footer.php 
	    sed -e 's|</body>|<?php wp_footer(); ?>\n</body>\n|g' footer.php > footer.php.tmp && mv footer.php.tmp footer.php
		
		#delete plugin wp-parser (if it exists)
		if [[ -d $REFERENCE_SITE_PATH/wp-content/plugins/wp-parser ]]; then
			cd $REFERENCE_SITE_PATH
			wp plugin delete wp-parser --allow-root 2>&1 >/dev/null
		fi	
		
		echo 'Installing plugin wp-parser...'
		cd $REFERENCE_SITE_PATH/wp-content/plugins
		composer create-project rmccue/wp-parser:dev-master --no-dev	

		#delete theme wporg-developer (if it exists)
		if [[ -d $REFERENCE_SITE_PATH/wp-content/themes/wporg-developer ]]; then
			cd $REFERENCE_SITE_PATH
			default_theme=$(wp --require=$WPCLI_COMMAND_FILE_PATH wp-parser-reference theme get_default --allow-root)
			wp theme activate $default_theme --allow-root
			wp theme delete wporg-developer --allow-root 2>&1 >/dev/null
		fi
		
		#install theme wporg-developer
		echo 'Installing theme wporg-developer...'
		cd $REFERENCE_SITE_PATH/wp-content/themes
		git clone https://github.com/Rarst/wporg-developer
		cd $CURRENT_PATH
	fi

	# =============================================================================
	# Update wp-reference.dev website 
	# =============================================================================
	if [[ "$instal_new" = false ]]; then
		echo "Updating $REFERENCE_HOME_URL..."
		cd $REFERENCE_SITE_PATH
		wp core update --allow-root
		cd $CURRENT_PATH
	fi

	# =============================================================================
	# Install or Update WP in source code directory
	# =============================================================================
	if [[ ! -d $SOURCE_CODE_PATH ]]; then
		#install WordPress in source code directory
		mkdir $SOURCE_CODE_PATH
		cd $SOURCE_CODE_PATH
		echo "Downloading WordPress $SOURCE_CODE_WP_VERSION in $SOURCE_CODE_PATH..."
		if [[ $SOURCE_CODE_WP_VERSION = "latest" ]]; then
			wp core download --allow-root
		else
			wp core download --version=$SOURCE_CODE_WP_VERSION --allow-root
		fi
		wp core config --dbname="wordpress-reference" --dbuser=wp --dbpass=wp --dbhost="localhost" --allow-root --skip-check
		cd $CURRENT_PATH
	else
		# update or install WordPress in source code directory depending if version is set
		cd $SOURCE_CODE_PATH
		echo "Updating WordPress $SOURCE_CODE_WP_VERSION in $SOURCE_CODE_PATH"
		if [[ $SOURCE_CODE_WP_VERSION = "latest" ]]; then
			wp core update --allow-root
		else
			wp core update --version=$SOURCE_CODE_WP_VERSION --force --allow-root
		fi

		cd $CURRENT_PATH
	fi

else
	# no internet connection
	echo -e "\nNo network connection available, skipping downloading or updating WordPress Reference"

	if [[ -d $REFERENCE_SITE_PATH ]]; then
		cd $REFERENCE_SITE_PATH

		if [[ "$RESET_WORDPRESS" = true  ]]; then
			echo "Dropping all tables in 'wordpress-reference' database..."
			wp db reset --yes --allow-root
		fi

		echo "installing $REFERENCE_HOME_URL... in $REFERENCE_SITE_PATH"
		wp core install --url=$REFERENCE_HOME_URL --title="WordPress Developer Reference" --admin_user=admin --admin_password=password --admin_email=demo@example.com --allow-root
		cd $CURRENT_PATH
	fi
fi

# todo: delete wp-content and external libraries so they don't get parsed
# 
# delete wp-content in /source-code
# if [[ -d $SOURCE_CODE_PATH/wp-content ]]; then
# 		echo "deleting $SOURCE_CODE_PATH/wp-content..."
# 		rm -rf $SOURCE_CODE_PATH/wp-content
# fi

# =============================================================================
# activate plugins and themes and set permalink structure
# =============================================================================
if [[ -d $REFERENCE_SITE_PATH ]]; then
	
	cd $REFERENCE_SITE_PATH

	#activate plugin wp-parser
	echo 'Activating plugin wp-parser...'
	wp plugin activate wp-parser --allow-root	

	#activate theme
	echo 'Activating theme wporg-developer...'
	wp theme activate wporg-developer --allow-root

	#set permalinks
	echo 'Set permalink structure...'
	wp rewrite structure '/%postname%/' --allow-root
	wp rewrite flush --allow-root	

	cd $CURRENT_PATH
fi

# =============================================================================
# function to parse source code with WP Parser
# =============================================================================
provision_wp_parser_init() {

	sc_path=$1
	wp_path=$2
	quick_mode=$3

	#check if the WordPress directory for the reference exists
	if [[ ! -d $wp_path ]]; then
		echo "Skipped parsing, reference site directory doesn't exist: $wp_path"
		return
	fi

	#check if the source code directory for WP Parser exists
	if [[ ! -d $sc_path ]]; then
		sc_path=$wp_path
		echo -e "\nWarning: source code directory doesn't exist\n"
		echo -e "New source code directory is  $sc_path\n"
	fi

	cd $wp_path/wp-content/plugins	

	#import source code directory
	echo "Proceed parsing source code directory $sc_path ..."
	if [[ "$quick_mode" = true  ]]; then
		wp parser create $sc_path --user=1 --quick --allow-root
	else
		wp parser create $sc_path --user=1 --allow-root
	fi	
	
	return
}


# =============================================================================
# parse source code with WP Parser
# =============================================================================
if [[ "$PARSE_SOURCE_CODE" = true ]]; then
	provision_wp_parser_init $SOURCE_CODE_PATH $REFERENCE_SITE_PATH $WP_PARSER_QUICK_MODE
fi


# =============================================================================
# create pages if needed
# =============================================================================
if [[ -d $REFERENCE_SITE_PATH ]]; then
	
	if [[ -f $WPCLI_COMMAND_FILE_PATH ]]; then

		cd $REFERENCE_SITE_PATH
		echo 'Creating reference pages (if needed)...'
		wp --require=$WPCLI_COMMAND_FILE_PATH wp-parser-reference pages create --allow-root

		echo 'Flushing permalink structure...'
		wp rewrite flush --allow-root
	fi
fi
echo -e "Done creating or updating $REFERENCE_HOME_URL!\n"