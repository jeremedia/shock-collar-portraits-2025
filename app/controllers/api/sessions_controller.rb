class Api::SessionsController < ApplicationController
  skip_before_action :verify_authenticity_token
  
  def index
    sessions = PhotoSession.includes(:session_day, :photos)
                          .order('session_days.date ASC, photo_sessions.started_at ASC')
    
    render json: {
      sessions: sessions.map { |session| session_json(session) },
      stats: {
        total_sessions: sessions.count,
        total_photos: Photo.count,
        by_day: stats_by_day,
        by_source: stats_by_source
      }
    }
  end
  
  def show
    session = PhotoSession.includes(:photos, :sittings).find_by(burst_id: params[:id])
    
    if session
      render json: session_json(session, include_photos: true)
    else
      render json: { error: 'Session not found' }, status: 404
    end
  end
  
  def update_hero
    session = PhotoSession.find_by(burst_id: params[:id])
    photo = session&.photos&.find_by(position: params[:hero_index])
    
    if session && photo
      # Update any sittings for this session
      session.sittings.update_all(hero_photo_id: photo.id)
      render json: { success: true }
    else
      render json: { error: 'Session or photo not found' }, status: 404
    end
  end
  
  private
  
  def session_json(session, include_photos: false)
    hero_index = session.sittings.first&.hero_photo&.position || (session.photo_count / 2)
    hero_photo = session.photos.find_by(position: hero_index) || session.photos.first
    
    json = {
      id: session.burst_id,
      sessionNumber: session.session_number,
      timestamp: session.started_at,
      dayOfWeek: session.session_day.day_name,
      source: session.source,
      photoCount: session.photo_count,
      duration: session.ended_at ? (session.ended_at - session.started_at).to_i : 0,
      heroIndex: hero_index,
      heroPhoto: hero_photo&.filename,
      firstPhoto: session.photos.first&.filename
    }
    
    # Add Active Storage URLs if available
    if hero_photo&.image&.attached?
      json[:heroPhotoUrl] = rails_blob_url(hero_photo.image.variant(:thumb))
    end
    
    if include_photos
      json[:photos] = session.photos.order(:position).map do |photo|
        photo_data = {
          filename: photo.filename,
          path: photo.original_path.sub(Rails.root.join('..').to_s + '/', ''),
          position: photo.position,
          rejected: photo.rejected
        }
        
        # Include Active Storage URLs if available
        if photo.image.attached?
          photo_data[:urls] = {
            thumb: rails_blob_url(photo.image.variant(:thumb)),
            medium: rails_blob_url(photo.image.variant(:medium)),
            large: rails_blob_url(photo.image.variant(:large)),
            original: rails_blob_url(photo.image)
          }
        end
        
        photo_data
      end
    end
    
    json
  end
  
  def stats_by_day
    SessionDay.joins(:photo_sessions).group('session_days.day_name').count
  end
  
  def stats_by_source
    PhotoSession.group(:source).count
  end
end