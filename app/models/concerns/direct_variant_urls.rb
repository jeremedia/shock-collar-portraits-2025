module DirectVariantUrls
  extend ActiveSupport::Concern

  # Generate a stable S3 URL that won't change regardless of Rails config
  def stable_variant_url(variant_name)
    return nil unless image.attached?
    
    blob = image.blob
    variant_key = case variant_name
    when :thumb
      "variants/#{blob.key}/thumb_300x300.jpg"
    when :large
      "variants/#{blob.key}/large_1920x1920.jpg"
    else
      return nil
    end
    
    # Direct S3 URL - bypasses Rails entirely
    "https://#{ENV.fetch('AWS_BUCKET', 'shock-collar-photos')}.s3.#{ENV.fetch('AWS_REGION', 'us-west-2')}.amazonaws.com/#{variant_key}"
  end
  
  # Check if variant exists on S3
  def variant_exists?(variant_name)
    return false unless image.attached?
    
    # We could check S3 directly here if needed
    # For now, assume it exists if we've processed it before
    true
  end
  
  # Get variant URL - tries stable URL first, falls back to Rails
  def smart_variant_url(variant_name)
    # For now, just use the regular Rails URL
    # We can switch to stable URLs once variants are generated
    rails_blob_url(image.variant(variant_name))
  end
end