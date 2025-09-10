class Admin::ThumbnailsController < ApplicationController
  helper VariantUrlHelper
  before_action :require_admin
  
  def index
    # Load all sessions with their photos, grouped by day
    @sessions_by_day = PhotoSession.visible
                                   .includes(:session_day, photos: { image_attachment: :blob }, sittings: {})
                                   .order('session_days.date ASC, photo_sessions.started_at ASC')
                                   .group_by { |s| s.session_day }
    
    # Calculate global indices for all photos
    @global_indices = {}
    global_index = 0
    @sessions_by_day.each do |day, sessions|
      sessions.each do |session|
        session.photos.order(:position).each do |photo|
          @global_indices[photo.id] = global_index
          global_index += 1
        end
      end
    end
    
    # Calculate stats
    @total_photos = Photo.joins(:photo_session).where(photo_sessions: { hidden: false }).count
    @total_sessions = PhotoSession.visible.count
    
    # Get variant generation status
    @photos_with_thumb = Photo.joins(:photo_session, image_attachment: :blob)
                              .where(photo_sessions: { hidden: false })
                              .count
  end
  
  private
  
  def require_admin
    redirect_to root_path, alert: "Admin access required" unless current_user&.admin?
  end
end