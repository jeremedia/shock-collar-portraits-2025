require 'vips'

class VariantGenerationJob < ApplicationJob
  queue_as :attachments  # Use same queue as image attachments
  
  retry_on StandardError, wait: :polynomially_longer, attempts: 3
  
  def perform(photo_id, variants = [:thumb, :large])
    photo = Photo.find(photo_id)
    
    # Skip if no image attached
    return unless photo.image.attached?
    # p "Starting variant generation for Photo ##{photo.id}"
    # Pre-generate each variant
    variants.each do |variant_name|
      # p "Processing #{variant_name} variant for Photo ##{photo.id}"
      begin
        if variant_name.to_sym == :face_thumb
          # Generate dynamic face crop variant if faces exist
          if photo.has_faces?
            # This triggers processing of a dynamic variant via libvips extract_area
            photo.face_crop_url(size: 300)
          else
            #p "Skipping face_thumb for Photo ##{photo.id} - no faces detected"
          end
        else
          # Named Active Storage variant
          variant = photo.image.variant(variant_name)
          if variant.send(:record).present?
            #p "#{variant_name} variant already exists for Photo ##{photo.id}"
          else
            variant.processed
            #p "Generated #{variant_name} variant for Photo ##{photo.id}"
          end
        end
        

      rescue => e
        Rails.logger.error "Failed to generate #{variant_name} variant for Photo ##{photo.id}: #{e.message}"
        # Continue with other variants even if one fails
      end
    end
    
    #Rails.logger.info "Variant generation completed for Photo ##{photo.id}"
  rescue => e
    Rails.logger.error "Variant generation failed for Photo ##{photo_id}: #{e.message}"
    raise # Re-raise to trigger retry
  end
end
