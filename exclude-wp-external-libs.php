<?php
/**
 * Plugin Name: WP Parser Exclude External Libs
 * Description: Exclude external libs when parsing WordPress with the WP Parser.
 * Author: keesiemeijer
 * Author URI:
 * Plugin URI:
 * Version: 4.1
 */

add_filter( 'wp_parser_pre_import_file', 'wppeel_exclude_external_libs', 10, 2 );

function wppeel_exclude_external_libs( $include, $file ) {

	if ( ! ( isset( $file['path'] ) && $file['path'] ) ) {
		return $include;
	}

	// Files to exclude.
	$exclude_files = array(
		'wp-admin/includes/class-pclzip.php',
		'wp-admin/includes/class-ftp-pure.php',
		'wp-admin/includes/class-ftp-sockets.php',
		'wp-admin/includes/class-ftp.php',
		'wp-includes/class-snoopy.php',
		'wp-includes/class-simplepie.php',
		'wp-includes/class-IXR.php',
		'wp-includes/class-phpass.php',
		'wp-includes/class-phpmailer.php',
		'wp-includes/class-pop3.php',
		'wp-includes/class-json.php',
		'wp-includes/class-smtp.php',
	);

	// Directories to exclude.
	$exclude_dirs = array(
		'wp-includes/ID3/',
		'wp-includes/Text/',
		'wp-includes/SimplePie/',
	);

	// Files to include from wp-content.
	$include_wp_content_files  = array(
		'wp-content/plugins/hello.php',
	);

	// Directories to Include from wp-content.
	$include_wp_content_dirs  = array(
		'wp-content/themes/twentyfourteen/',
		'wp-content/themes/twentythirteen/',
		'wp-content/themes/twentytwelve/',
		'wp-content/themes/twentyeleven/',
		'wp-content/themes/twentyten/',
	);


	if ( in_array( $file['path'], $exclude_files ) ) {
		return false;
	}

	foreach ( $exclude_dirs as $dir ) {
		if ( 0 === strpos( $file['path'], $dir ) ) {
			return false;
		}
	}

	// Check if path starts with wp-content.
	if ( 0 !== strpos( $file['path'], 'wp-content/' ) ) {
		return $include;
	}

	$wp_content = array_merge( $include_wp_content_dirs, $include_wp_content_files );

	$include = false;
	foreach ( $wp_content as $dir ) {
		// Check if file or directory is whitelisted.
		if ( 0 === strpos( $file['path'], $dir ) || ( $file['path'] === $dir ) ) {
			$include = true;
			break;
		}
	}

	// Exclude directories and files from wp-content if they're not whitelisted.
	if ( ! $include ) {
		return false;
	}

	return $include;
}
