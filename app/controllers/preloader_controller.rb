class PreloaderController < ApplicationController
  before_action :check_if_preloader_shown, only: [:index]
  
  def index
    # Determine optional limit (allow ?limit=all or numeric; default = all)
    limit_param = params[:limit]
    limit_value = nil
    if limit_param.present?
      if limit_param.to_s.downcase == 'all'
        limit_value = nil
      elsif limit_param.to_i > 0
        limit_value = limit_param.to_i
      end
    end

    # Get all photos with their sessions for organization
    @photos = Photo.includes(:photo_session, image_attachment: :blob)
                   .where.not(active_storage_attachments: { id: nil })
                   .order('photo_sessions.started_at DESC, photos.position ASC')
    # Only apply a limit if explicitly requested
    @photos = @photos.limit(limit_value) if limit_value
    
    # Just pass photo IDs - generate URLs via AJAX when needed
    @photo_data = @photos.map do |photo|
      next unless photo.image.attached?
      
      {
        id: photo.id,
        session_id: photo.photo_session_id,
        position: photo.position,
        filename: photo.filename,
        has_faces: photo.has_faces?
      }
    end.compact
    
    # Group by session for better organization
    @sessions = @photos.group_by(&:photo_session).map do |session, photos|
      {
        id: session.id,
        burst_id: session.burst_id,
        photo_count: photos.count,
        started_at: session.started_at
      }
    end
    
    # Calculate total variants to download (5 base + face if applicable)
    @total_variants = @photo_data.sum do |photo|
      5 + (photo[:has_faces] ? 1 : 0) # 5 standard variants + face variant if has faces
    end
    
    # Mark as shown when they complete or skip
    @preloader_data = {
      photos: @photo_data,
      sessions: @sessions,
      total_photos: @photo_data.count,
      total_variants: @total_variants,
      estimated_size: estimate_total_size(@total_variants)
    }
  end
  
  def complete
    # Mark preloader as shown
    cookies.permanent[:preloader_shown] = 'true'
    redirect_to gallery_index_path, notice: 'Gallery optimized for offline viewing!'
  end
  
  def skip
    # Mark as shown but skipped
    cookies.permanent[:preloader_shown] = 'skipped'
    cookies.permanent[:preloader_skipped_at] = Time.current.to_s
    redirect_to gallery_index_path
  end
  
  def variant_urls
    # Generate variant URLs for a batch of photos (called via AJAX)
    photo_ids = params[:photo_ids] || []
    variant_type = params[:variant] || 'thumb'
    
    urls = {}
    Photo.where(id: photo_ids).includes(image_attachment: :blob).each do |photo|
      next unless photo.image.attached?
      
      begin
        case variant_type
        when 'face_thumb'
          urls[photo.id] = photo.face_crop_url(size: 300) if photo.has_faces?
        else
          variant = photo.image.variant(variant_type.to_sym)
          urls[photo.id] = rails_representation_url(variant, only_path: true)
        end
      rescue => e
        Rails.logger.error "Failed to generate #{variant_type} URL for photo #{photo.id}: #{e.message}"
      end
    end
    
    render json: urls
  end
  
  def all_photo_metadata
    # Return photo metadata with variant URLs in one response
    # Cache this response for 1 hour since URLs don't change frequently
    
    limit_param = params[:limit]
    limit_value = nil
    if limit_param.present?
      if limit_param.to_s.downcase == 'all'
        limit_value = nil
      elsif limit_param.to_i > 0
        limit_value = limit_param.to_i
      end
    end

    cache_key = "preloader_all_photo_metadata_v2_#{limit_value || 'all'}"
    
    metadata = Rails.cache.fetch(cache_key, expires_in: 1.hour) do
      photos = Photo.includes(:photo_session, image_attachment: :blob)
                    .where.not(active_storage_attachments: { id: nil })
                    .order('photo_sessions.started_at DESC, photos.position ASC')
      # Only apply a limit if explicitly requested
      photos = photos.limit(limit_value) if limit_value
      
      photos.map do |photo|
        next unless photo.image.attached?
        
        # Generate all variant URLs for this photo
        variants = {}
        
        begin
          # Standard variants
          variants['tiny_square_thumb'] = rails_representation_url(photo.image.variant(:tiny_square_thumb), only_path: true)
          variants['thumb'] = rails_representation_url(photo.image.variant(:thumb), only_path: true)
          variants['medium'] = rails_representation_url(photo.image.variant(:medium), only_path: true)
          variants['large'] = rails_representation_url(photo.image.variant(:large), only_path: true)
          
          # Face variant if applicable
          if photo.has_faces?
            variants['face_thumb'] = photo.face_crop_url(size: 300)
          end
        rescue => e
          Rails.logger.error "Failed to generate URLs for photo #{photo.id}: #{e.message}"
        end
        
        {
          id: photo.id,
          session_id: photo.photo_session_id,
          position: photo.position,
          filename: photo.filename,
          has_faces: photo.has_faces?,
          variants: variants,
          created_at: photo.created_at
        }
      end.compact
    end
    
    render json: {
      photos: metadata,
      generated_at: Time.current,
      total_count: metadata.size
    }
  end
  
  private
  
  def check_if_preloader_shown
    # Allow re-showing if explicitly requested or if skipped more than 7 days ago
    return if params[:force] == 'true'
    
    if cookies[:preloader_shown] == 'true'
      redirect_to gallery_index_path
    elsif cookies[:preloader_shown] == 'skipped'
      # Check if skipped more than 7 days ago
      skipped_at = cookies[:preloader_skipped_at]
      if skipped_at && Time.parse(skipped_at) < 7.days.ago
        cookies.delete(:preloader_shown)
        cookies.delete(:preloader_skipped_at)
      else
        redirect_to gallery_index_path
      end
    end
  end
  
  
  def estimate_total_size(variant_count)
    # Rough estimates based on variant type
    avg_variant_size = 150 * 1024 # 150KB average
    variant_count * avg_variant_size
  end
end
