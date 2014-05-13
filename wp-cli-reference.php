<?php
/**
 * Implements wp-parser-reference command.
 */
class WP_Parser_Reference extends WP_CLI_Command {

    /**
     * Creates static front page and reference page
     *
     * @synopsis <create>
     */
    function pages( $args, $assoc_args ) {
        list( $create ) = $args;
        $templates = wp_get_theme()->get_page_templates();

        $front_page = $has_template = false;

        if ( 'page' == get_option( 'show_on_front' ) ) {
            $page_on_front = get_option( 'page_on_front' ); // id
            $page = get_post( $page_on_front );
            if ( isset( $page->post_title ) && 'Front Page' == $page->post_title ) {
                $front_page = true;
            }
            $template = get_post_meta( $page->ID, '_wp_page_template', true );
            if ( isset( $templates['page-reference-landing.php'] ) && 'page-reference-landing.php' == $template ) {
                $has_template = true;
            }
        }

        // post object
        $my_post = array(
            'post_title'    => 'Front Page',
            'post_status'   => 'publish',
            'post_author'   => 1,
            'post_type' => 'page'
        );

        if ( !( $front_page && $has_template ) ) {

            // Insert the post into the database
            $id_front = wp_insert_post( $my_post );

            if ( $id_front ) {
                update_option( 'page_on_front', $id_front );
                update_option( 'show_on_front', 'page' );
                if ( isset( $templates['page-reference-landing.php'] ) ) {
                    update_post_meta( $id_front, '_wp_page_template', 'page-reference-landing.php' );
                }
                WP_CLI::line( "Created static front page $id_front" );
            } else {
                WP_CLI::line( "Could not create static front page" );
            }


        } else {
            WP_CLI::line( "Front page exists" );
        }

        if ( !get_posts( 'posts_per_page=1&post_type=page&name=reference' ) ) {

            $my_post['post_title'] = 'reference';

            // Insert the post into the database
            $id_reference = wp_insert_post( $my_post );
            if ( $id_reference ) {

                if ( isset( $templates['page-reference-landing.php'] ) ) {
                    update_post_meta( $id_reference, '_wp_page_template', 'page-reference-landing.php' );
                }
                WP_CLI::line( "Created reference page $id_reference" );
            } else {
                WP_CLI::line( "Could not create reference page" );
            }
        } else {
            WP_CLI::line( "Reference page exists." );
        }

        // Print a success message
        WP_CLI::success( 'Done creating pages.' );
    }

    /**
     * get default theme with STDOUT
     *
     * @synopsis <get_default>
     */
    function theme( $args, $assoc_args ) {
        list( $get_default ) = $args;

        $default_theme = 'twentyfourteen';
        if ( defined( 'WP_DEFAULT_THEME' ) ) {
            $default_theme = WP_DEFAULT_THEME;
        }

        WP_CLI::line( $default_theme );
    }
}

WP_CLI::add_command( 'wp-parser-reference', 'WP_Parser_Reference' );
