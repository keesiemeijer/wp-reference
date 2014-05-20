wp-reference
============

VVV auto site setup script to mirror the [WordPress code reference](https://developer.wordpress.org).

Parse WordPress with the [WP Parser plugin](https://github.com/rmccue/WP-Parser) and mirror the WordPress code reference using [Varying Vagrant Vagrants](https://github.com/Varying-Vagrant-Vagrants/VVV).

This bash script follows these directions to [mirror the code reference](https://make.wordpress.org/docs/handbook/projects/devhub/#setting-up-your-development-environment).


#### To get started:
1. Setup [Varying Vagrant Vagrants](https://github.com/Varying-Vagrant-Vagrants/VVV) (If you don't already have it)
2. Clone this branch of this repo into the www directory of your Vagrant as www/wp-reference
3. If your Vagrant is running, from the Vagrant directory run `vagrant halt`
4. Followed by `vagrant up --provision`. The provisioning may take a while as it will parse all WordPress files.

You can now visit [http://wp-reference.dev/](http://wp-reference.dev/)

Note: If you don't have the vagrant plugin `vagrant-hostsupdater` installed you'll need to add the domain to your `hosts` file manually before you can visit [http://wp-reference.dev/](http://wp-reference.dev/).

#### Provisioning
When provisioning this script will:
* if the directories /public and /source-code don't exist (inside the wp-reference directory)
  * Create directories /public and /source-code.
  * Download WordPress inside both directories
  * Install Wordpress (in the /public dir) with domain 'wp-reference.dev'.
* Update Wordpress in both directories.
* Install and activate the plugin [WP Parser](https://github.com/rmccue/WP-Parser) and theme [wporg-developer](https://github.com/Rarst/wporg-developer).
* Download and edit the [header.php](https://wordpress.org/header.php) and [footer.php](https://wordpress.org/footer.php) files from wordpress.org.
* Parse the /source-code directory with the WP Parser plugin.
* Create a static front page (if needed).
* Create a reference page (if needed).

#### Credentials
* URL:      wp-reference.dev
* Username: admin
* Password: password
* DB Name:  wordpress-reference

#### Variables
After the first `vagrant up --provision` you can set it to not parse the source code again when provisioning. Just set `PARSE_SOURCE_CODE` to false in the vvv-init.sh file.

    PARSE_SOURCE_CODE=false

Other variables you can set in the vvv-init.sh file.

```
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
```
