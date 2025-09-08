class VariantGenerationJob < ApplicationJob
  queue_as :attachments  # Use same queue as image attachments
  
  retry_on StandardError, wait: :polynomially_longer, attempts: 3
  
  def perform(photo_id, variants = [:thumb, :large])
    photo = Photo.find(photo_id)
    
    # Skip if no image attached
    return unless photo.image.attached?
    
    # Pre-generate each variant
    variants.each do |variant_name|
      begin
        # Calling processed triggers the variant generation
        # The URL generation forces processing
        variant = photo.image.variant(variant_name)
        variant.processed
        
        Rails.logger.info "Generated #{variant_name} variant for Photo ##{photo.id}"
      rescue => e
        Rails.logger.error "Failed to generate #{variant_name} variant for Photo ##{photo.id}: #{e.message}"
        # Continue with other variants even if one fails
      end
    end
    
    Rails.logger.info "Variant generation completed for Photo ##{photo.id}"
  rescue => e
    Rails.logger.error "Variant generation failed for Photo ##{photo_id}: #{e.message}"
    raise # Re-raise to trigger retry
  end
end