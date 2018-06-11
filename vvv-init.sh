#!/usr/bin/env bash

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
# 	    Install Wordpress (in the /public dir) with domain 'wp-reference.test'.
# 	Update Wordpress in both directories.
# 	Install and activate the plugin WP Parser and theme wporg-developer.
# 	Download and edit the header.php and footer.php files from wordpress.org.
# 	Parse the /source-code directory with the WP Parser plugin.
# 	Create a static front page (if needed).
# 	Create a reference page (if needed).
# 
# Credentials
# 	URL:      wp-reference.test
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
# To change the domain name 'wp-reference.test':
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
# Default: "wp-reference.test"
REFERENCE_HOME_URL="wp-reference.test"

# Parse the source code with WP Parser when provisioning.
# Default: true
PARSE_SOURCE_CODE=true

# If set to true the --quick subcommand is added to the "wp parser" command.
# Default: false
WP_PARSER_QUICK_MODE=false

# Delete all tables in the database when provisioning (re-installs WP).
# Boolean value or 'empty'
#   If 'empty' is used all post data (posts, meta, terms etc) is deleted
# Default: false
RESET_WORDPRESS=false

# Update the assets when provisioning.
# Note:
#   Assets are deleted before being updated if set to true.
#
# Default: false
UPDATE_ASSETS=false

# The WordPress version (in the /source-code directory) to be parsed by the WP Parser.
#
# Note:
#   Use "latest" or a valid WordPress version in quotes (e.g. "4.4")
#   Deleting the /source-code dir will re-install WordPress (instead of updating it).
#   Use an empty string "" to not install/update WP in the /source-code dir. This Let's you parse other code than WP
#
# Default: "latest"
SOURCE_CODE_WP_VERSION="latest"

# Exclude external libraries when parsing (same as developer.wordpress.org).
# Default: true
EXCLUDE_WP_EXTERNAL_LIBS=true

# Theme used for the reference site.
# The theme needs to exist in the site's themes folder.
#
# Default: "default"
THEME="default"


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
readonly CURRENT_PATH=$(pwd)

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
	# Check for wp-config.php file
	if ! config_exists; then
		return 1
	fi

	# Check if WP tables exist
	wp core is-installed --allow-root 2> /dev/null
}

function config_exists() {
	if is_file "wp-config.php"; then
		return 0
	fi
	return 1
}

function is_activated(){
	local name=$1
	local wptype=$2
	local activated

	activated=$(wp "$wptype" list --status=active --fields=name --format=csv --allow-root)

	while read -r line; do
		if [[ "$line" = "$name" ]]; then
			return 0
		fi
	done <<< "$activated"

	return 1
}

function assets(){
	local action=$1
	local wptype=$2
	local asset=$3
	local default_theme

	if [[ $action = "delete" ]]; then
		if wp "$wptype" is-installed "$asset" --allow-root; then
			if is_file "$WPCLI_COMMANDS_FILE" && [[ "$wptype" = "theme" ]]; then
				default_theme="$(wp --require="$WPCLI_COMMANDS_FILE" wp-parser-reference theme get_default --allow-root)"
				if ! is_activated "$default_theme" "theme"; then
					wp theme activate "$default_theme" --allow-root
				fi
			fi
			wp "$wptype" delete "$asset" --allow-root > /dev/null 2>&1
		fi
	fi

	if [[ $action = "activate" ]]; then
		if wp "$wptype" is-installed "$asset" --allow-root 2> /dev/null; then
			#activate plugin wp-parser
			if ! is_activated "$asset" "$wptype"; then
				printf "Activating %s...\n" "$wptype $asset"
				wp "$wptype" activate "$asset" --allow-root
			else
				printf "%s is activated\n" "$wptype $asset"
			fi
		else
			printf "\033[0m\nNotice: %s is not installed\033[0m\n" "$wptype $asset"
		fi
	fi
}

function install_WordPress {

	cd "$REFERENCE_SITE_PATH" || exit

	if ! wp_core_is_installed; then
		if ! config_exists; then
			return 1
		fi

		# tables don't exist
		printf "Installing %s in %s...\n" "$REFERENCE_HOME_URL" "$REFERENCE_SITE_PATH"
		wp core install --url="$REFERENCE_HOME_URL" --title="WordPress Developer Reference" --admin_user=admin --admin_password=password --admin_email=demo@example.com --allow-root
	else
		#tables exist
		if [[ "$RESET_WORDPRESS" = 'empty' ]]; then
			printf "Empty post tables in 'wordpress-reference' database...\n"
			wp site empty --yes --allow-root
			return 0
		fi

		if [[ "$RESET_WORDPRESS" = true ]]; then
			wp db reset --yes --allow-root
			printf "Installing %s in %s...\n" "$REFERENCE_HOME_URL" "$REFERENCE_SITE_PATH"
			wp core install --url="$REFERENCE_HOME_URL" --title="WordPress Developer Reference" --admin_user=admin --admin_password=password --admin_email=demo@example.com --allow-root
		fi


	fi
}

function create_files {

	# =============================================================================
	# Create vvv-hosts file (if it doesn't exist)
	# =============================================================================

	if ! is_file "$CURRENT_PATH/vvv-hosts"; then
		printf "Creating vvv-hosts file in %s...\n" "$CURRENT_PATH"
		touch "$CURRENT_PATH/vvv-hosts"
		printf "%s\n" "$REFERENCE_HOME_URL" >> "%s/vvv-hosts" "$CURRENT_PATH"
	fi

	# =============================================================================
	# Create .conf file for Apache (if it doesn't exist)
	# =============================================================================

	if is_dir "/srv/config/apache-config/sites"; then
		if ! is_file "/srv/config/apache-config/sites/$CURRENT_DIR.conf"; then
			cd srv/config/apache-config/sites || return 1
			printf "Creating %s.conf in /srv/config/apache-config/sites/...\n" "$CURRENT_DIR"
			sed -e "s/testserver\.com/$REFERENCE_HOME_URL/" \
			-e "s/wordpress-local/$CURRENT_DIR\/public/" local-apache-example.conf-sample > "$CURRENT_DIR.conf"
		fi
	fi
}

function is_yaml_type() {
	local yaml_file=$1
	local yaml_key=$2
	local check_type=$3
	local yaml_value_type

	yaml_value_type=$(shyaml get-type "sites.wp-reference.$yaml_key" 2> /dev/null < "${yaml_file}")

	if [[ $yaml_value_type = "$check_type" ]]; then
		return 0
	fi

	return 1
}

# =============================================================================
# Set variables found in vvv-custom.yml
# since vvv 2+
# =============================================================================
function set_yaml_values() {
	local yaml_value
	local variable_name
	local config_file

	if ! is_file "/vagrant/vvv-custom.yml"; then
		return 1
	fi

	# Check if shyaml command exists
	# Todo: Check with <command> or <type>
	exists_shyaml="$(which shyaml)"
	if [[ "/usr/local/bin/shyaml" != "${exists_shyaml}" ]]; then
		return 1
	fi

	# Boolean settings used in vvv-custom.yml
	declare -a yaml_bool_vars=("parse_source_code" "wp_parser_quick_mode" "reset_wordpress" "update_assets" "exclude_wp_external_libs")
	config_file=/vagrant/vvv-custom.yml

	for i in "${yaml_bool_vars[@]}"
	do
		if ! is_yaml_type "$config_file" "$i" "bool"; then
			continue
		fi

		yaml_value=$(shyaml get-value "sites.wp-reference.$i" 2> /dev/null < "${config_file}")
		variable_name="$( echo "$i" | tr /a-z/ /A-Z/)"

		# Convert values to booleans
		if [[ "False" = "$yaml_value" ]]; then
			eval "${variable_name}"=false
		fi

		if [[ "True" = "$yaml_value" ]]; then
			eval "${variable_name}"=true
		fi
	done

	if is_yaml_type "$config_file" "reset_wordpress" "str"; then
		RESET_WORDPRESS=$(shyaml get-value "sites.wp-reference.reset_wordpress" 2> /dev/null < "${config_file}")
		if [[ "empty" != "$RESET_WORDPRESS" ]]; then
			RESET_WORDPRESS=false
		fi
	fi

	if is_yaml_type "$config_file" "theme" "str"; then
		THEME=$(shyaml get-value "sites.wp-reference.theme" 2> /dev/null < "${config_file}")
	fi

	if is_yaml_type "$config_file" "hosts.0" "str"; then
		REFERENCE_HOME_URL=$(shyaml get-value "sites.wp-reference.hosts.0" 2> /dev/null < "${config_file}")
	fi

	if is_yaml_type "$config_file" "source_code_wp_version" "str"; then
		SOURCE_CODE_WP_VERSION=$(shyaml get-value "sites.wp-reference.source_code_wp_version" 2> /dev/null < "${config_file}")
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
	if ping -c 3 -W 5 8.8.8.8 >> /dev/null 2>&1; then
		printf "Network connection detected\n"
		local ping_result="Connected"
	else
		printf "\e[31mNo network connection detected. Unable to reach google.com\033[0m\n"
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
		printf "Creating directory %s...\n" "$REFERENCE_SITE_PATH"
		instal_new=true
		mkdir "$REFERENCE_SITE_PATH"
	fi

	# =============================================================================
	# Install or update all the things if connected
	# =============================================================================
	if [[ $ping_result = "Connected" ]]; then

		cd "$REFERENCE_SITE_PATH" || exit

		# =============================================================================
		# download WordPress
		# =============================================================================
		if [[ "$instal_new" = true ]]; then
		
			printf "Downloading WordPress in %s...\n" "$REFERENCE_SITE_PATH"
			wp core download --allow-root

			printf "Creating wp-config in %s...\n" "$REFERENCE_SITE_PATH"
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

				cd "$REFERENCE_PLUGIN_PATH" || exit

				# Install phpdoc-parser
				printf "Installing plugin wp-parser...\n"
				git clone https://github.com/WordPress/phpdoc-parser.git wp-parser
				printf "Installing wp-parser dependencies...\n"
				cd wp-parser || exit
				composer install
				composer dump-autoload

				# Install syntaxhighlighter
				printf "Installing plugin syntaxhighlighter...\n"
				svn checkout https://plugins.svn.wordpress.org/syntaxhighlighter/trunk "$REFERENCE_PLUGIN_PATH/syntaxhighlighter"

				# Install handbook
				printf "Installing plugin handbook...\n"
				svn checkout http://meta.svn.wordpress.org/sites/trunk/wordpress.org/public_html/wp-content/plugins/handbook/ "$REFERENCE_PLUGIN_PATH/handbook"

				cd "$REFERENCE_THEME_PATH" || exit

				# Install theme wporg-developer
				printf "Installing theme wporg-developer...\n"
				svn checkout http://meta.svn.wordpress.org/sites/trunk/wordpress.org/public_html/wp-content/themes/pub/wporg-developer/

				local success
				local fail
				success="Downloading header.php in $REFERENCE_THEME_PATH..."
				fail="\e[31mCould not download header.php\033[0m"

				# Download header.php and print message
				curl -f -s -O https://wordpress.org/header.php && printf "%s\n" "$success" || printf "%s\n" "$fail"

				if is_file "$REFERENCE_THEME_PATH/header.php"; then
					sed -i -e "s/<\/head>/<?php wp_head(); ?>\n<\/head>/g" header.php
					sed -i -e "s/<body id=\"wordpress-org\" >/<body id=\"wordpress-org\" <?php body_class(); ?>>/g" header.php
					printf "Done editing header.php\n"
				fi

				success="${success/header.php/footer.php}"
				fail="${fail/header.php/footer.php}"

				# Download footer.php and print message
				curl -f -s -O https://wordpress.org/footer.php && printf "%s\n" "$success" || printf "%s\n" "$fail"

				if is_file "$REFERENCE_THEME_PATH/footer.php"; then
					sed -i -e 's|</body>|<?php wp_footer(); ?>\n</body>\n|g' footer.php
					printf "Done editing footer.php\n"
				fi
			fi

			cd "$REFERENCE_SITE_PATH" || exit

			# =============================================================================
			# Update wp-reference.test website
			# =============================================================================
			if [[ "$instal_new" = false ]]; then
					printf "Updating WordPress in %s...\n" "$REFERENCE_SITE_PATH"
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

				cd "$SOURCE_CODE_PATH" || exit

				printf "Downloading WordPress %s in %s...\n" "$SOURCE_CODE_WP_VERSION" "$SOURCE_CODE_PATH"
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

				cd "$SOURCE_CODE_PATH" || exit

				printf "Updating WordPress %s in %s...\n" "$SOURCE_CODE_WP_VERSION" "$SOURCE_CODE_PATH"

				# Install the source-code WordPress install to be able to update
				if ! wp_core_is_installed && config_exists; then
					mysql -u "$MYSQL_USER" --password="$MYSQL_PASSWORD" -e "CREATE DATABASE IF NOT EXISTS \`wordpress-source-reference\`"
					mysql -u "$MYSQL_USER" --password="$MYSQL_PASSWORD" -e "GRANT ALL PRIVILEGES ON \`wordpress-source-reference\`.* TO wp@localhost IDENTIFIED BY 'wp';"

					wp core install --url="wp-source.dev" --title="Source" --admin_user=admin --admin_password=password --admin_email=demo@example.com --allow-root > /dev/null 2>&1
				else
					printf "\e[31mNo WordPress install found in %s\n" "$SOURCE_CODE_PATH"
					printf "To re-install WordPress delete the directory %s\033[0m\n" "$SOURCE_CODE_PATH"
				fi

				if wp_core_is_installed; then
					if [[ "$SOURCE_CODE_WP_VERSION" = "latest" ]]; then
						wp core update --force --allow-root
					else
						wp core update --version="$SOURCE_CODE_WP_VERSION" --force --allow-root
					fi

				fi

				# Delete database as it's only needed for updating WordPress
				wp db drop --yes --quiet --allow-root 2> /dev/null
			else
				printf "Skipped installing WordPress in %s\n" "$SOURCE_CODE_PATH"
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

	cd "$REFERENCE_SITE_PATH" || exit

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

		if [[ "default" = "$THEME" ]]; then
			assets "activate" "theme" "wporg-developer"
		else
			assets "activate" "theme" "$THEME"
			if ! is_activated "$THEME" "theme"; then
				assets "activate" "theme" "wporg-developer"
			fi
		fi

		assets "delete" "plugin" "exclude-wp-external-libs"
		if is_file "$CURRENT_PATH/exclude-wp-external-libs.php" && [[ "$EXCLUDE_WP_EXTERNAL_LIBS" = true ]]; then
			cp "$CURRENT_PATH/exclude-wp-external-libs.php" "$REFERENCE_PLUGIN_PATH/exclude-wp-external-libs.php"
			assets "activate" "plugin" "exclude-wp-external-libs"
		fi

		# =============================================================================
		# Set permalink structure
		# =============================================================================
		printf "Set permalink structure to /%%postname%%/...\n"
		wp rewrite structure '/%postname%/' --allow-root
		wp rewrite flush --allow-root

		# =============================================================================
		# parse source code with WP Parser
		# =============================================================================
		if is_dir "$SOURCE_CODE_PATH"; then

			if [[ "$PARSE_SOURCE_CODE" = true ]]; then
				cd "$REFERENCE_PLUGIN_PATH" || exit

				printf "Parsing source code directory %s...\n" "$SOURCE_CODE_PATH"
				if [[ "$WP_PARSER_QUICK_MODE" = true  ]]; then
					wp parser create "$SOURCE_CODE_PATH" --user=1 --quick --allow-root
				else
					wp parser create "$SOURCE_CODE_PATH" --user=1 --allow-root
				fi
			else
				printf "Skipped parsing source code directory\n"
			fi

		else
			printf "\e[31mSkipped parsing. Source code directory doesn't exist\033[0m\n"
		fi

		cd "$REFERENCE_SITE_PATH" || exit

		# =============================================================================
		# create pages and nav menu if needed
		# =============================================================================
		if is_file "$WPCLI_COMMANDS_FILE"; then

			printf "Creating reference pages (if needed)...\n"
			wp --require="$WPCLI_COMMANDS_FILE" wp-parser-reference pages create --allow-root
			printf "Creating empty nav menu (if needed)...\n"
			wp --require="$WPCLI_COMMANDS_FILE" wp-parser-reference nav_menu create --allow-root
		fi

		assets "delete" "plugin" "exclude-wp-external-libs"
		wp plugin deactivate "wp-parser" --allow-root

		printf "Flushing permalink structure...\n"
		wp rewrite flush --allow-root
	else
		printf "\e[31mSkipped parsing. Could not find a WordPress install in: %s\033[0m\n" "$REFERENCE_SITE_PATH"
	fi

	cd "$CURRENT_PATH" || exit
	printf "Finished Setup %s\n" "$REFERENCE_HOME_URL"
}

printf "\nCommencing Setup %s\n" "$REFERENCE_HOME_URL"

# set variables if found in vvv-custom.yml
set_yaml_values

# set variables to readonly
readonly REFERENCE_HOME_URL=$REFERENCE_HOME_URL
readonly PARSE_SOURCE_CODE=$PARSE_SOURCE_CODE
readonly WP_PARSER_QUICK_MODE=$WP_PARSER_QUICK_MODE
readonly RESET_WORDPRESS=$RESET_WORDPRESS
readonly UPDATE_ASSETS=$UPDATE_ASSETS
readonly SOURCE_CODE_WP_VERSION=$SOURCE_CODE_WP_VERSION
readonly EXCLUDE_WP_EXTERNAL_LIBS=$EXCLUDE_WP_EXTERNAL_LIBS

# create vvv-hosts file or .conf file if it's an Apache box.
create_files

# create reference
setup_reference