class PortraitVariantJob < ApplicationJob
  queue_as :default

  def perform(photo_id)
    photo = Photo.find_by(id: photo_id)
    return unless photo

    # Pre-generate the portrait variants that will be needed
    # Standard portrait size for hero view
    photo.ensure_portrait_processed!(width: 1080, height: 1920)

    # Smaller size that might be used for thumbnails
    photo.ensure_portrait_processed!(width: 720, height: 1280)

    Rails.logger.info "Pre-processed portrait variants for Photo ##{photo.id}"
  rescue => e
    Rails.logger.error "Failed to process portrait variants for Photo ##{photo_id}: #{e.message}"
  end
end
