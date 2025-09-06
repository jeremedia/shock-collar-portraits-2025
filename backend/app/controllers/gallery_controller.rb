class GalleryController < ApplicationController
  def index
    @sessions_by_day = PhotoSession.includes(:session_day, :photos, sittings: :hero_photo)
                                   .order('session_days.date ASC, photo_sessions.started_at ASC')
                                   .group_by { |s| s.session_day.day_name }
    
    @stats = {
      total_sessions: PhotoSession.count,
      total_photos: Photo.count,
      by_day: SessionDay.joins(:photo_sessions).group('session_days.day_name').count
    }
  end
  
  def show
    @session = PhotoSession.includes(:photos, :sittings).find_by!(burst_id: params[:id])
    
    # Handle rejected photo filtering
    @show_rejected = params[:show_rejected] == 'true'
    
    if @show_rejected
      @photos = @session.photos.order(:position)
    else
      @photos = @session.photos.accepted.order(:position)
    end
    
    # Get rejected photo count for toggle button
    @rejected_count = @session.photos.rejected.count
    
    @sitting = @session.sittings.first
    @hero_photo = @sitting&.hero_photo || @photos[@photos.length / 2]
    
    # Find adjacent sessions for navigation
    all_sessions = PhotoSession.includes(:session_day)
                               .order('session_days.date ASC, photo_sessions.started_at ASC')
                               .pluck(:burst_id)
    current_index = all_sessions.index(@session.burst_id)
    
    @prev_session = current_index > 0 ? all_sessions[current_index - 1] : nil
    @next_session = current_index < all_sessions.length - 1 ? all_sessions[current_index + 1] : nil
  end
  
  def update_hero
    @session = PhotoSession.find_by!(burst_id: params[:id])
    @photo = @session.photos.find(params[:photo_id])
    
    @session.sittings.update_all(hero_photo_id: @photo.id)
    
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to gallery_path(@session.burst_id) }
    end
  end
  
  def save_email
    @session = PhotoSession.find_by!(burst_id: params[:id])
    @sitting = @session.sittings.first_or_create!
    
    @sitting.update!(
      name: params[:name],
      email: params[:email]
    )
    
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to gallery_path(@session.burst_id) }
    end
  end
  
  def reject_photo
    @session = PhotoSession.find_by!(burst_id: params[:id])
    @photo = @session.photos.find(params[:photo_id])
    
    @photo.update!(rejected: !@photo.rejected)
    
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to gallery_path(@session.burst_id, show_rejected: params[:show_rejected]) }
    end
  end
  
  def split_session
    @session = PhotoSession.find_by!(burst_id: params[:id])
    @photo = @session.photos.find(params[:photo_id])
    
    new_session = @session.split_at_photo(@photo.id)
    
    if new_session
      respond_to do |format|
        format.json { render json: { success: true, new_session_id: new_session.burst_id } }
        format.html { redirect_to gallery_path(new_session.burst_id), notice: "Session split successfully" }
      end
    else
      respond_to do |format|
        format.json { 
          render json: { 
            success: false, 
            error: @session.errors.full_messages.join(", "),
            errors: @session.errors.full_messages 
          }, status: :unprocessable_entity 
        }
        format.html { 
          redirect_to gallery_path(@session.burst_id), alert: @session.errors.full_messages.join(", ")
        }
      end
    end
  rescue ActiveRecord::RecordNotFound
    respond_to do |format|
      format.json { render json: { success: false, error: "Photo not found", errors: ["Photo not found"] }, status: :not_found }
      format.html { redirect_to gallery_path(@session.burst_id), alert: "Photo not found" }
    end
  end
end