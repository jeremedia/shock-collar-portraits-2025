module VariantUrlHelper
  # Smart variant URL that uses proxy for existing variants, redirect for non-existing
  # This avoids synchronous processing while enabling caching when possible
  def smart_variant_url(attachment, variant_name)
    return nil unless attachment.attached?
    
    variant = attachment.variant(variant_name)
    
    # Check if this variant has already been processed
    variant_record = ActiveStorage::VariantRecord.find_by(
      blob_id: attachment.blob.id,
      variation_digest: variant.variation.digest
    )
    
    if variant_record&.image&.blob
      # Variant exists and has been uploaded - use proxy URL for caching
      # This serves through Rails with cache headers, perfect for service worker
      rails_storage_proxy_url(variant_record.image.blob, only_path: false)
    else
      # Variant doesn't exist yet - use representation URL
      # This will queue processing asynchronously and redirect to S3
      rails_representation_url(variant, only_path: false)
    end
  rescue => e
    Rails.logger.error "Error generating variant URL: #{e.message}"
    # Fallback to representation URL on any error
    rails_representation_url(attachment.variant(variant_name), only_path: false)
  end
end