module ActiveStorageHelper
  # Use proxy URLs for better caching with service workers
  # Proxy URLs serve images through Rails instead of redirecting to S3
  def cached_variant_url(attachment, variant_name)
    return nil unless attachment.attached?
    
    variant = attachment.variant(variant_name)
    
    # Use rails_storage_proxy_url for serving through Rails with proper cache headers
    # This avoids the redirect to S3 and allows service workers to cache properly
    rails_storage_proxy_url(
      variant.processed,
      only_path: false,
      host: request.base_url
    )
  rescue
    # Fallback to redirect URL if proxy fails
    rails_blob_url(variant)
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