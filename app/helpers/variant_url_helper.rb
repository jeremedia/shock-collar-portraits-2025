module VariantUrlHelper
  # Smart variant URL that uses direct URLs for better performance
  # This avoids proxying through Rails which can be slow
  def smart_variant_url(attachment, variant_name)
    return nil unless attachment.attached?
    
    variant = attachment.variant(variant_name)
    
    # Check if this variant has already been processed
    variant_record = ActiveStorage::VariantRecord.find_by(
      blob_id: attachment.blob.id,
      variation_digest: variant.variation.digest
    )
    
    if variant_record&.image&.blob
      # Variant exists and has been uploaded - use direct URL
      # This serves directly from storage service (disk/S3) for best performance
      rails_blob_url(variant_record.image.blob, only_path: false)
    else
      # Variant doesn't exist yet - use representation URL
      # This will queue processing asynchronously and redirect to storage
      rails_representation_url(variant, only_path: false)
    end
  rescue => e
    Rails.logger.error "Error generating variant URL: #{e.message}"
    # Fallback to representation URL on any error
    rails_representation_url(attachment.variant(variant_name), only_path: false)
  end
end