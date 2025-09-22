module ActiveStorageHelper
  # Use direct URLs for better performance
  # Direct URLs serve images directly from storage service without Rails proxy overhead
  def cached_variant_url(attachment, variant_name)
    return nil unless attachment.attached?

    variant = attachment.variant(variant_name)

    # Use direct blob URL to avoid proxying through Rails
    # This improves performance by serving directly from disk/S3
    rails_blob_url(
      variant.processed,
      only_path: false
    )
  rescue
    # Fallback to representation URL if processing fails
    rails_representation_url(attachment.variant(variant_name), only_path: false)
  end

  # Helper for thumbnail URLs with caching
  def cached_thumb_url(photo)
    cached_variant_url(photo.image, :thumb)
  end

  # Helper for medium URLs with caching
  def cached_medium_url(photo)
    cached_variant_url(photo.image, :medium)
  end

  # Helper for large URLs with caching
  def cached_large_url(photo)
    cached_variant_url(photo.image, :large)
  end
end
