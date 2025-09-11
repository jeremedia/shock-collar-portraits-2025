class HeroesController < ApplicationController
  skip_before_action :authenticate_user!  # Make it public
  
  def index
    # Get all sittings that have a hero photo selected
    # Preload all associations and Active Storage attachments to avoid N+1 queries
    @hero_sittings = Sitting.includes(
                              hero_photo: { image_attachment: :blob },
                              photo_session: :session_day
                            )
                            .where.not(hero_photo_id: nil)
                            .joins(:photo_session)
                            .merge(PhotoSession.visible)  # Only visible sessions
                            .order('photo_sessions.started_at DESC')
    
    # Group by day for better organization
    @heroes_by_day = @hero_sittings.group_by { |sitting| 
      sitting.photo_session.session_day 
    }.sort_by { |day, _| day.date }.reverse
    
    # Stats for header
    @total_heroes = @hero_sittings.count
    @total_days = @heroes_by_day.count
    
    # Cache the page for 5 minutes to improve performance
    expires_in 5.minutes, public: true
  end
  
  def show
    @photo = Photo.find(params[:id])
    @sitting = @photo.sittings.first
    
    # Only show if it's actually a hero photo
    unless Sitting.exists?(hero_photo_id: @photo.id)
      redirect_to heroes_path, alert: "Photo not found"
      return
    end
    
    # Find adjacent heroes for navigation
    all_hero_ids = Sitting.where.not(hero_photo_id: nil)
                          .joins(:photo_session)
                          .merge(PhotoSession.visible)
                          .order('photo_sessions.started_at DESC')
                          .pluck(:hero_photo_id)
    
    current_index = all_hero_ids.index(@photo.id)
    @prev_hero_id = all_hero_ids[current_index - 1] if current_index && current_index > 0
    @next_hero_id = all_hero_ids[current_index + 1] if current_index && current_index < all_hero_ids.length - 1
  end
end