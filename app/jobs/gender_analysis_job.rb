require "vips"

class GenderAnalysisJob < ApplicationJob
  queue_as :default

  def perform(photo_session_id)
    session = PhotoSession.find(photo_session_id)

    # Skip if already analyzed
    return if session.gender_analyzed_at.present?

    Rails.logger.info "Analyzing gender for PhotoSession ##{session.id} (#{session.photos.count} photos)"

    result = session.analyze_gender!

    if result
      Rails.logger.info "Gender analysis completed for PhotoSession ##{session.id}: #{result[:gender]} (confidence: #{result[:confidence]})"
    else
      Rails.logger.warn "Gender analysis failed for PhotoSession ##{session.id}"
    end
  rescue => e
    Rails.logger.error "GenderAnalysisJob error for session #{photo_session_id}: #{e.message}"
    raise # Re-raise to trigger retry
  end

  # Batch process all sessions that need analysis
  def self.enqueue_all_pending
    sessions_needing_analysis = PhotoSession.visible
                                           .without_gender_analysis
                                           .joins(photos: :image_attachment)
                                           .where.not(photos: { face_data: nil })
                                           .distinct

    Rails.logger.info "Enqueuing gender analysis for #{sessions_needing_analysis.count} sessions"

    sessions_needing_analysis.find_each do |session|
      GenderAnalysisJob.perform_later(session.id)
    end
  end
end
