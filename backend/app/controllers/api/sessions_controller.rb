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
    json = {
      id: session.burst_id,
      sessionNumber: session.session_number,
      timestamp: session.started_at,
      dayOfWeek: session.session_day.day_name,
      source: session.source,
      photoCount: session.photo_count,
      duration: session.ended_at ? (session.ended_at - session.started_at).to_i : 0,
      heroIndex: session.sittings.first&.hero_photo&.position || (session.photo_count / 2)
    }
    
    if include_photos
      json[:photos] = session.photos.order(:position).map do |photo|
        {
          filename: photo.filename,
          path: photo.original_path.sub(Rails.root.join('..').to_s + '/', ''),
          position: photo.position,
          rejected: photo.rejected
        }
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