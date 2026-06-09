<?php
/**
 * PHP file to use when rendering the block type on the server to show on the front end.
 *
 * The following variables are exposed to the file:
 *     $attributes (array): The block attributes.
 *     $content (string): The block default content.
 *     $block (WP_Block): The block instance.
 *
 * @see https://github.com/WordPress/gutenberg/blob/trunk/docs/reference-guides/block-api/block-metadata.md#render
 */
?>
<p
	<?php echo get_block_wrapper_attributes(); ?>
	data-start-date="<?php echo esc_attr($attributes['startDate'] ?? ''); ?>"
	data-end-date="<?php echo esc_attr($attributes['endDate'] ?? ''); ?>"
>
	<?php echo wp_kses_post($attributes['content'] ?? ''); ?>
</p>