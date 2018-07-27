wp-reference
============

VVV auto site setup script to mirror the [WordPress code reference](https://developer.wordpress.org).

Parse WordPress with the [WP Parser plugin](https://github.com/rmccue/WP-Parser) and mirror the WordPress code reference using [Varying Vagrant Vagrants](https://github.com/Varying-Vagrant-Vagrants/VVV).

This bash script follows these directions to [mirror the code reference](https://make.wordpress.org/docs/handbook/projects/devhub/#setting-up-your-development-environment).

With some [extra installation steps](https://github.com/keesiemeijer/wp-reference/wiki/Using-WP-Reference-with-the-Local-by-Flywheel-app.) you can also use this script with the [Local by Flywheel app](https://local.getflywheel.com/)

### Installation
There are two ways you can install this script. Since VVV version 2 you can add it with a [vvv-custom.yml](https://varyingvagrantvagrants.org/docs/en-US/adding-a-new-site/) file.

#### VVV version 2
Use the `vvv-custom.yml` file to add the reference site and settings. See [custom settings](https://github.com/keesiemeijer/wp-reference#settings) for more information about these settings.
Here is an example `vvv-custom.yml` file with all the settings you can use.
```YAML
sites:
  wp-reference:
    repo: https://github.com/keesiemeijer/wp-reference.git
    hosts:
      - wp-reference.test
    parse_source_code: true
    wp_parser_quick_mode: false
    reset_wordpress: false
    update_assets: false
    exclude_wp_external_libs: true
    source_code_wp_version: "latest"
    theme: "default"
```
**Note** The `repo` setting is required and needs to point to this repo. All other settings can be changed.

#### VVV version 1
For VVV version 1 you'll have to clone this repo into the `www` directory of your Varying Vagrant Vagrants.

### To get started:
1. If your Vagrant is running, from the Vagrant directory run `vagrant halt`
2. Followed by `vagrant up --provision`. The provisioning may take a while as it will parse all WordPress files.

You can now visit [http://wp-reference.test/](http://wp-reference.test/)

Note: If you don't have the vagrant plugin `vagrant-hostsupdater` installed you'll need to add the domain to your `hosts` file manually before you can visit [http://wp-reference.test/](http://wp-reference.test/).

### Provisioning
When provisioning this script will:
* if the directories /public and /source-code don't exist (inside the wp-reference directory)
  * Create directories /public and /source-code.
  * Download WordPress inside both directories
  * Install Wordpress (in the /public dir) with domain 'wp-reference.test'.
* Update Wordpress in both directories.
* Install and activate assets
  * [wporg-developer](https://github.com/Rarst/wporg-developer)
  * [WP Parser](https://github.com/rmccue/WP-Parser)
  * [SyntaxHighlighter Evolved](https://wordpress.org/plugins/syntaxhighlighter/)
  * [Handbook](https://meta.trac.wordpress.org/browser/sites/trunk/wordpress.org/public_html/wp-content/plugins/handbook)
* Download and edit the [header.php](https://wordpress.org/header.php) and [footer.php](https://wordpress.org/footer.php) files from wordpress.org.
* Parse the /source-code directory with the WP Parser plugin.
* Create a static front page (if needed).
* Create a reference page (if needed).
* Create a nav menu (if needed).

### Parsing code
If the referece site is provisioned you can use this script to parse code (in the source-code directory).

From the Vagrant directory run `vagrant ssh` and go to wp-reference directory
```bash
cd /vagrant/www/wp-reference
```

To parse code with the settings in your [vvv-custom.yml](https://github.com/keesiemeijer/wp-reference#vvv-version-2) file run the following command.
```bash
bash vvv-init.sh
```

### Credentials
* URL:      wp-reference.test
* Username: admin
* Password: password
* DB Name:  wordpress-reference
* DB User:  wp
* DB Pass:  wp

#### MySQL Root
* User: root
* Pass: root

### Settings
For VVV version 2+ you can edit custom settings in the [vvv-custom.yml](https://github.com/keesiemeijer/wp-reference#vvv-version-2) file. For lower versions edit settings variables in the `vvv-init.sh` file. See the commented variables below from the `vvv-init.sh` file for more information.

**Note**: The variables in the `vvv-custom.yml` file are the same but lowercase and will override the variables in the `vvv-init.sh` file. 

```bash
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
#   If 'empty' is used all post data (posts, meta, terms etc) is deleted before parsing
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

# Database Name
#
# default: "wordpress-reference"
DB_NAME="wordpress-reference"

# MySQL root user
#
# Default: "root"
MYSQL_USER='root'

# MySQL root password
#
# Default: "root"
MYSQL_PASSWORD='root'
```