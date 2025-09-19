class HeroesController < ApplicationController
  helper HeroHelper
  before_action :authenticate_user!  # Require login

  def index
    # Get all photo sessions that have hero photos selected
    @hero_sessions = PhotoSession.includes(
                                   :session_day,
                                   :tags,
                                   :appearance_tags,
                                   :expression_tags,
                                   :accessory_tags,
                                   hero_photo: { image_attachment: :blob }
                                 )
                                 .visible
                                 .where.not(hero_photo_id: nil)
                                 .order(started_at: :asc)

    # Group by day for better organization (Monday to Friday)
    @heroes_by_day = @hero_sessions.group_by(&:session_day)
                                   .sort_by { |day, _| day.date }

    # Stats for header
    @total_sessions = PhotoSession.visible.count
    @total_heroes = @hero_sessions.count
    @total_days = @heroes_by_day.count

    # Cache the page for 5 minutes to improve performance
    expires_in 5.minutes, public: true
  end
  
  def show
    @photo = Photo.find(params[:id])
    @session = @photo.photo_session

    # Only show if it's actually a hero photo
    unless PhotoSession.exists?(hero_photo_id: @photo.id)
      redirect_to heroes_path, alert: "Photo not found"
      return
    end

    # Find adjacent heroes for navigation
    all_hero_sessions = PhotoSession.visible
                                   .where.not(hero_photo_id: nil)
                                   .order(started_at: :asc)

    # Get all hero photo IDs in order
    all_hero_ids = all_hero_sessions.pluck(:hero_photo_id)

    current_index = all_hero_ids.index(@photo.id)
    @prev_hero_id = all_hero_ids[current_index - 1] if current_index && current_index > 0
    @next_hero_id = all_hero_ids[current_index + 1] if current_index && current_index < all_hero_ids.length - 1

    # Get the actual photo objects for preloading
    @prev_photo = Photo.find(@prev_hero_id) if @prev_hero_id
    @next_photo = Photo.find(@next_hero_id) if @next_hero_id
  end
end
