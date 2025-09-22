class ImageAttachmentJob < ApplicationJob
  queue_as :attachments

  retry_on StandardError, wait: :polynomially_longer, attempts: 3

  def perform(photo_id)
    photo = Photo.find(photo_id)

    # Skip if already has attachment
    return if photo.image.attached?

    # Skip if no original path
    return unless photo.original_path.present?

    # Skip if file doesn't exist
    unless File.exist?(photo.original_path)
      Rails.logger.error "ImageAttachmentJob: File not found for Photo ##{photo.id}: #{photo.original_path}"
      return
    end

    # Attach the image
    ImageAttachmentService.attach_image(photo)

    Rails.logger.info "Image attachment completed for Photo ##{photo.id} (#{photo.filename})"
  rescue => e
    Rails.logger.error "Image attachment failed for Photo ##{photo_id}: #{e.message}"
    raise # Re-raise to trigger retry
  end
end
