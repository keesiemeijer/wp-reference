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

	// Bail early if file is already being skipped.
	if ( ! $include ) {
		return $include;
	}

	if ( ! ( isset( $file['path'] ) && $file['path'] ) ) {
		return $include;
	}

	$exclude = array(
		'wp-admin/css/',
		'wp-admin/includes/class-ftp',
		'wp-admin/includes/class-pclzip.php',
		'wp-admin/includes/class-ftp-sockets.php',
		'wp-admin/includes/class-ftp.php',
		'wp-admin/js/',
		'wp-content/',
		'wp-includes/ID3/',
		'wp-includes/IXR/',
		'wp-includes/SimplePie/',
		'wp-includes/Text/',
		'wp-includes/certificates/',
		'wp-includes/class-IXR.php',
		'wp-includes/class-json.php',
		'wp-includes/class-phpass.php',
		'wp-includes/class-phpmailer.php',
		'wp-includes/class-pop3.php ',
		'wp-includes/class-simplepie.php',
		'wp-includes/class-smtp.php',
		'wp-includes/class-snoopy.php',
		'wp-includes/js/',
	);

	// Skip file if it matches anything in the list.
	foreach ( $exclude as $skip ) {
		if ( 0 === strpos( $file['path'], $skip ) ) {
			$include = false;
			break;
		}
	}

	return $include;
}
