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
    @total_photos = Photo.count
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

    # Handle JSON requests for smooth client-side navigation
    respond_to do |format|
      format.html
      format.json { render json: hero_json_data }
    end
  end

  private

  def hero_json_data
    # Queue background job to pre-generate next/prev portrait variants
    # This happens while the user is viewing the current photo
    if @prev_photo && @prev_photo.portrait_crop_data.present?
      PortraitVariantJob.perform_later(@prev_photo.id)
    end
    if @next_photo && @next_photo.portrait_crop_data.present?
      PortraitVariantJob.perform_later(@next_photo.id)
    end

    {
      photo: {
        id: @photo.id,
        full_url: helpers.smart_variant_url(@photo.image, :large),
        portrait_url: @photo.portrait_crop_url(width: 1080, height: 1920),
        position: @photo.position
      },
      session: {
        id: @session.id,
        session_number: @session.session_number,
        photo_count: @session.photo_count,
        day_name: @session.session_day&.day_name,
        date: @session.session_day&.date&.strftime('%b %d'),
        time: @photo.photo_taken_at ?
          @photo.photo_taken_at.in_time_zone('America/Los_Angeles').strftime('%-l:%M:%S %p') :
          @session.started_at.in_time_zone('America/Los_Angeles').strftime('%-l:%M %p')
      },
      navigation: {
        prev_id: @prev_hero_id,
        next_id: @next_hero_id,
        prev_url: @prev_hero_id ? hero_path(@prev_hero_id) : nil,
        next_url: @next_hero_id ? hero_path(@next_hero_id) : nil,
        prev_portrait_url: @prev_photo&.portrait_crop_url,
        next_portrait_url: @next_photo&.portrait_crop_url,
        prev_full_url: @prev_photo ? helpers.smart_variant_url(@prev_photo.image, :large) : nil,
        next_full_url: @next_photo ? helpers.smart_variant_url(@next_photo.image, :large) : nil
      }
    }
  end
end
