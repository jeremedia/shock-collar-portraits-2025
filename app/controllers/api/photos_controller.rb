class Api::PhotosController < ApplicationController
  before_action :authenticate_user!, except: [ :random_hero_faces ]
  before_action :require_admin, only: [ :extract_exif, :portrait_crop, :update_portrait_crop, :reset_portrait_crop ]
  before_action :set_photo, only: [ :extract_exif, :portrait_crop, :update_portrait_crop, :reset_portrait_crop ]

  def exif_config
    render json: {
      status: "success",
      visible_fields: AppSetting.exif_visible_fields
    }
  end

  def random_hero_faces
    # Get random hero photos that have face data
    # Hero photos are identified through sittings that reference them
    hero_photo_ids = Sitting.where.not(hero_photo_id: nil).pluck(:hero_photo_id)
    hero_photos = Photo.where(id: hero_photo_ids)
                       .where.not(face_data: nil)
                       .order("RANDOM()")
                       .limit(30)

    # Return URLs for face crops
    faces = hero_photos.map do |photo|
      {
        id: photo.id,
        url: photo.face_crop_url(size: 300)
      }
    end.compact

    render json: {
      status: "success",
      faces: faces
    }
  end

  def portrait_crop
    return if performed?
    render_portrait_crop(@photo)
  end

  def update_portrait_crop
    return if performed?
    @photo.update_portrait_crop!(portrait_crop_params)
    render_portrait_crop(@photo)
  rescue => e
    Rails.logger.error "Failed to update portrait crop for photo #{@photo.id}: #{e.message}"
    render json: { status: "error", message: e.message }, status: 422
  end

  def reset_portrait_crop
    return if performed?
    @photo.reset_portrait_crop!
    render_portrait_crop(@photo)
  rescue => e
    Rails.logger.error "Failed to reset portrait crop for photo #{@photo.id}: #{e.message}"
    render json: { status: "error", message: e.message }, status: 500
  end

  def extract_exif
    return if performed?
    Rails.logger.info "Starting EXIF extraction for photo #{@photo.id} at path: #{@photo.original_path}"

    # Check if photo has an attachment
    unless @photo.image.attached?
      Rails.logger.warn "Photo #{@photo.id} has no image attachment"
      return render json: {
        status: "error",
        message: "Photo has no image attachment"
      }, status: 422
    end

    # Extract full EXIF data using exiftool
    exif_data = extract_full_exif(@photo)

    if exif_data.present?
      # Merge with existing EXIF data
      merged_data = (@photo.exif_data || {}).merge(exif_data)
      @photo.update!(exif_data: merged_data)

      Rails.logger.info "Successfully extracted EXIF data for photo #{@photo.id}: #{exif_data.keys.join(', ')}"

      render json: {
        status: "success",
        exif_data: exif_data,
        message: "EXIF data extracted successfully"
      }
    else
      Rails.logger.warn "No EXIF data extracted for photo #{@photo.id}"
      render json: {
        status: "error",
        message: "No EXIF data could be extracted from this file"
      }, status: 422
    end

  rescue ActiveRecord::RecordNotFound
    render json: {
      status: "error",
      message: "Photo not found"
    }, status: 404
  rescue => e
    Rails.logger.error "EXIF extraction failed for photo #{params[:id]}: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    render json: {
      status: "error",
      message: "Internal server error: #{e.message}"
    }, status: 500
  end

  private

  def extract_full_exif(photo)
    return {} unless photo.image.attached?

    # Download the image attachment to a temporary file
    temp_file = nil
    begin
      # Download the blob to a temporary file
      temp_file = Tempfile.new([ "photo_exif_", File.extname(photo.image.filename.to_s) ])
      temp_file.binmode

      Rails.logger.debug "Downloading image attachment to temp file: #{temp_file.path}"
      photo.image.download do |chunk|
        temp_file.write(chunk)
      end
      temp_file.close

      # Use exiftool to extract comprehensive EXIF data from temp file
      # -j flag outputs JSON format for easy parsing
      # -n flag outputs numerical values where possible
      # -G1 flag adds group names to organize data
      command = %(exiftool -j -n -G1 "#{temp_file.path}" 2>&1)
      Rails.logger.debug "Running command: #{command}"

      result = `#{command}`
      exit_status = $?.exitstatus

      Rails.logger.debug "Command exit status: #{exit_status}"
      Rails.logger.debug "Command output length: #{result.length} chars"

      if exit_status != 0
        Rails.logger.error "exiftool command failed with exit status #{exit_status}: #{result}"
        return {}
      end

      if result.present? && result.strip.length > 0
        begin
          # Remove any stderr output that might be mixed with JSON
          json_start = result.index("[")
          if json_start
            json_content = result[json_start..-1]
            parsed_data = JSON.parse(json_content)
            exif_hash = parsed_data.first || {}

            Rails.logger.debug "Raw EXIF fields count: #{exif_hash.keys.count}"

            # Clean up and organize the data
            organized_data = organize_exif_data(exif_hash)
            Rails.logger.info "Organized EXIF data for photo #{photo.id}: #{organized_data.keys.count} categories"
            organized_data
          else
            Rails.logger.error "No JSON found in exiftool output for photo #{photo.id}: #{result[0..200]}"
            {}
          end
        rescue JSON::ParserError => e
          Rails.logger.error "Failed to parse EXIF JSON for photo #{photo.id}: #{e.message}"
          Rails.logger.error "Raw output: #{result[0..500]}"
          {}
        end
      else
        Rails.logger.warn "No EXIF data returned from exiftool for photo #{photo.id}"
        {}
      end

    ensure
      # Clean up temp file
      if temp_file
        temp_file.close unless temp_file.closed?
        temp_file.unlink
        Rails.logger.debug "Cleaned up temp file"
      end
    end
  end

  def organize_exif_data(raw_exif)
    # Organize EXIF data into logical groups for display
    organized = {
      "Camera" => {},
      "Exposure" => {},
      "Image" => {},
      "GPS" => {},
      "Other" => {}
    }

    raw_exif.each do |key, value|
      next if value.nil? || value == "" || value == "undef"

      # Skip very long binary data fields
      next if value.is_a?(String) && value.length > 200

      # Clean up the key name by removing EXIF group prefixes
      # Handle both "IFD0:Make" and "ExifIFD:SerialNumber" formats
      clean_key = key.gsub(/^[A-Za-z]+[0-9]*:/, "").strip

      case key
      when /Make|Model|SerialNumber|FirmwareVersion|LensModel|LensSerialNumber/i
        organized["Camera"][clean_key] = value
      when /ExposureTime|FNumber|ISO|ExposureProgram|MeteringMode|Flash|WhiteBalance|ExposureCompensation/i
        organized["Exposure"][clean_key] = value
      when /ImageWidth|ImageHeight|Orientation|ColorSpace|Resolution|DateTime/i
        organized["Image"][clean_key] = value
      when /GPS/i
        organized["GPS"][clean_key] = value
      else
        organized["Other"][clean_key] = value
      end
    end

    # Remove empty categories
    organized.reject { |_, v| v.empty? }
  end

  def set_photo
    @photo = Photo.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { status: "error", message: "Photo not found" }, status: 404
  end

  def require_admin
    unless current_user&.admin?
      render json: { status: "error", message: "Admin access required" }, status: 403
    end
  end

  def portrait_crop_params
    params.require(:portrait_crop).permit(:left, :top, :width, :height, :image_width, :image_height)
  end

  def render_portrait_crop(photo)
    rect = photo.portrait_crop_rect
    blob_metadata = photo.image&.blob&.metadata || {}
    image_width = blob_metadata["width"] || rect&.[](:width)
    image_height = blob_metadata["height"] || rect&.[](:height)

    render json: {
      status: "success",
      photo_id: photo.id,
      rect: rect,
      image_width: image_width,
      image_height: image_height,
      updated_at: photo.updated_at
    }
  end
end
