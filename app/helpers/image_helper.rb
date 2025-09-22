module ImageHelper
  # Override image_tag to always include crossorigin attribute for proper caching
  def cached_image_tag(source, options = {})
    # Add crossorigin attribute to enable non-opaque responses
    options[:crossorigin] = "anonymous" unless options.key?(:crossorigin)

    # Add loading lazy by default for performance
    options[:loading] ||= "lazy"

    image_tag(source, options)
  end

  # Helper specifically for Active Storage images with caching support
  def active_storage_image_tag(blob_or_variant, options = {})
    return unless blob_or_variant

    # Ensure crossorigin for proper caching
    options[:crossorigin] = "anonymous"
    options[:loading] ||= "lazy"

    if blob_or_variant.respond_to?(:variant)
      image_tag(rails_blob_url(blob_or_variant), options)
    else
      image_tag(blob_or_variant, options)
    end
  end
end
