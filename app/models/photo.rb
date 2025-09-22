class Photo < ApplicationRecord
  belongs_to :photo_session
  belongs_to :sitting, optional: true
  has_one_attached :image do |attachable|
    attachable.variant :tiny_square_thumb, resize_to_fill: [40, 40],    format: :webp, saver: { quality: 70 }
    attachable.variant :thumb,              resize_to_limit: [300, 300],  format: :webp, saver: { quality: 80 }
    attachable.variant :medium,             resize_to_limit: [800, 800],  format: :webp, saver: { quality: 85 }
    attachable.variant :large,              resize_to_limit: [1600, 1600], format: :webp, saver: { quality: 90 }
    attachable.variant :gallery,            resize_to_limit: [1200, 1200], format: :jpeg, saver: { quality: 85 }
  end

  scope :not_rejected, -> { where(rejected: false) }
  scope :accepted, -> { where(rejected: false) }
  scope :rejected, -> { where(rejected: true) }
  scope :heroes, -> { joins("INNER JOIN sittings ON sittings.hero_photo_id = photos.id") }
  scope :without_face_detection, -> { where(face_data: nil) }
  scope :without_gender_analysis, -> { where(gender_analyzed_at: nil) }
  scope :with_gender_analysis, -> { where.not(gender_analyzed_at: nil) }


  def self.generate_all_variants
    find_each do |photo|
      photo.generate_variants
    end
  end

  # Generate all variants for this photo
  # This method is called by VariantGenerationJob
  # It processes the named variants and the dynamic face crop variant if faces exist
  # Silences ActiveRecord logging to reduce noise during batch processing
  def generate_variants
    # silence active storage and active record logging for this operation
    #p "Generating variants for Photo ##{id}"
    ActiveRecord::Base.logger.silence do
      VariantGenerationJob.perform_now(id, [:tiny_square_thumb, :thumb, :medium, :large, :gallery, :face_thumb, :portrait_crop])
    end
    #p "Variant generation complete for Photo ##{id}"
  end
  # Class method to report on variant processing status
  def self.variant_processing_report
    variant_names = [:tiny_square_thumb, :thumb, :medium, :large, :gallery]

    total_photos = count
    photos_with_attachments = joins(:image_attachment).count
    photos_without_attachments = total_photos - photos_with_attachments

    report = {
      total_photos: total_photos,
      photos_with_attachments: photos_with_attachments,
      photos_without_attachments: photos_without_attachments,
      variants: {},
      photos_with_all_variants: 0,
      processing_percentage: 0.0,
      total_variant_records: ActiveStorage::VariantRecord.count
    }

    # Check each variant individually using ActiveStorage::VariantRecord
    variant_names.each do |variant_name|
      # Count variant records that match this variant's transformations
      # In Rails 8, variants are tracked in active_storage_variant_records table
      variant_count = 0

      if photos_with_attachments > 10000
        # For large datasets, use sampling
        sample_size = 100
        sample = joins(:image_attachment).limit(sample_size).to_a
        sample_processed = sample.count do |photo|
          begin
            # Check if variant record exists for this photo and variant
            variant = photo.image.variant(variant_name)
            # In Rails 8, we check if the variant record exists
            variant.send(:record).present?
          rescue
            false
          end
        end
        variant_count = (sample_processed.to_f / sample_size * photos_with_attachments).round
        report[:variants][variant_name] = {
          count: variant_count,
          percentage: photos_with_attachments > 0 ? (variant_count.to_f / photos_with_attachments * 100).round(1) : 0,
          estimated: true
        }
      else
        # For smaller datasets, check all
        variant_count = joins(:image_attachment).select do |photo|
          begin
            variant = photo.image.variant(variant_name)
            variant.send(:record).present?
          rescue
            false
          end
        end.count
        report[:variants][variant_name] = {
          count: variant_count,
          percentage: photos_with_attachments > 0 ? (variant_count.to_f / photos_with_attachments * 100).round(1) : 0,
          estimated: false
        }
      end
    end

    # Check photos with ALL variants processed
    if photos_with_attachments > 10000
      sample_size = 100
      sample = joins(:image_attachment).limit(sample_size).to_a
      all_variants_count = sample.count do |photo|
        variant_names.all? do |v|
          begin
            variant = photo.image.variant(v)
            variant.send(:record).present?
          rescue
            false
          end
        end
      end
      report[:photos_with_all_variants] = (all_variants_count.to_f / sample_size * photos_with_attachments).round
      report[:all_variants_estimated] = true
    else
      report[:photos_with_all_variants] = joins(:image_attachment).select do |photo|
        variant_names.all? do |v|
          begin
            variant = photo.image.variant(v)
            variant.send(:record).present?
          rescue
            false
          end
        end
      end.count
      report[:all_variants_estimated] = false
    end

    report[:processing_percentage] = photos_with_attachments > 0 ?
      (report[:photos_with_all_variants].to_f / photos_with_attachments * 100).round(1) : 0

    report
  end

  # Pretty print the variant processing report
  def self.print_variant_report
    report = variant_processing_report

    puts "\n" + "="*60
    puts "PHOTO VARIANT PROCESSING REPORT"
    puts "="*60
    puts "Total Photos: #{report[:total_photos]}"
    puts "  With attachments: #{report[:photos_with_attachments]}"
    puts "  Without attachments: #{report[:photos_without_attachments]}"
    puts "Total Variant Records in DB: #{report[:total_variant_records]}"
    puts "\nVariant Processing Status:"

    report[:variants].each do |variant_name, data|
      estimated = data[:estimated] ? " (estimated)" : ""
      puts "  #{variant_name.to_s.ljust(20)} #{data[:count].to_s.rjust(5)} / #{report[:photos_with_attachments]} (#{data[:percentage]}%)#{estimated}"
    end

    estimated = report[:all_variants_estimated] ? " (estimated)" : ""
    puts "\nPhotos with ALL variants: #{report[:photos_with_all_variants]} / #{report[:photos_with_attachments]} (#{report[:processing_percentage]}%)#{estimated}"
    puts "="*60 + "\n"

    nil # Return nil to avoid printing the report hash
  end

  # Automatically enqueue processing for new photos
  after_create :enqueue_image_attachment
  after_create :enqueue_face_detection
  after_create :enqueue_variant_generation
  after_create :enqueue_exif_extraction

  # Rails 8 uses coder instead of second argument for serialize
  serialize :metadata, coder: JSON
  serialize :exif_data, coder: JSON

  validates :filename, presence: true
  
  def image_url(variant = nil)
    return nil unless image.attached?
    
    if variant
      # Rails 8 syntax - directly access named variant
      image.variant(variant).url
    else
      image.url
    end
  end
  
  # Face detection methods
  def detect_faces!
    ::FaceDetectionService.detect_for_photo(self)
  end
  
  # Enqueue image attachment job for this photo
  def enqueue_image_attachment
    return if image.attached? # Skip if already attached
    return unless original_path.present? # Skip if no file path
    ImageAttachmentJob.perform_later(id)
  end
  
  # Enqueue face detection job for this photo
  def enqueue_face_detection
    return if face_data.present? # Skip if already processed
    FaceDetectionJob.perform_later(id)
  end
  
  # Enqueue variant generation job for this photo
  def enqueue_variant_generation
    # Queue variant generation after attachment (will be skipped if no attachment)
    VariantGenerationJob.perform_later(id, [:thumb, :large, :gallery, :tiny_square_thumb, :medium, :face_thumb, :portrait_crop])
  end
  
  # Enqueue EXIF extraction job for this photo
  # Extracts DateTimeOriginal to determine actual photo taken time
  # Important for maintaining correct chronological order when sessions are split
  def enqueue_exif_extraction
    return if exif_data && exif_data['DateTimeOriginal'].present? # Skip if already extracted
    ExifExtractionJob.perform_later(id)
  end
  
  def has_faces?
    return false unless face_data.present? && face_data['faces'].present?
    faces = face_data['faces']
    faces.is_a?(Array) && faces.any?
  end
  
  def face_count
    return 0 unless has_faces?
    face_data['faces'].length
  end
  
  def primary_face
    return nil unless has_faces?
    face_data['faces'].max_by { |face| face['width'] * face['height'] }
  end
  
  # Dynamic face crop variant (libvips)
  def face_crop_variant(size)
    { resize_to_fill: [size, size], format: :webp, saver: { quality: 85 } }
  end
  
  # Get face crop URL
  def face_crop_url(size: 300)
    p "Generating face crop URL for Photo ##{id} at size #{size}"
    return nil unless has_faces? && image.attached?

    crop_params = ::FaceDetectionService.face_crop_params(self)
    return nil unless crop_params
    
    # Generate dynamic variant for face crop using libvips extract_area
    begin
      blob_w = image.blob.metadata['width']
      blob_h = image.blob.metadata['height']
      Rails.logger.info(
        "Face crop for Photo ##{id}: left=#{crop_params[:left]} top=#{crop_params[:top]} " \
        "width=#{crop_params[:width]} height=#{crop_params[:height]} " \
        "blob_dims=#{blob_w}x#{blob_h} size=#{size}"
      )
    rescue => e
      Rails.logger.warn("Failed to log face crop params for Photo ##{id}: #{e.message}")
    end

    variant_params = {
      extract_area: [crop_params[:left], crop_params[:top], crop_params[:width], crop_params[:height]],
      resize_to_fill: [size, size],
      format: :webp,
      saver: { quality: 85 }
    }
    
    begin
      Rails.application.routes.url_helpers.rails_blob_url(image.variant(variant_params).processed, only_path: true)
    rescue ActiveStorage::FileNotFoundError
      # Return nil if the file doesn't exist (e.g., still being uploaded to S3)
      nil
    end
  end

  def portrait_crop_rect
    rect = portrait_crop_data&.symbolize_keys || default_portrait_crop_rect
    rect ? normalize_portrait_rect(rect) : nil
  end

  def portrait_crop_variant(width: 720, height: 1280)
    rect = portrait_crop_rect
    return nil unless rect

    normalized = normalize_portrait_rect(rect)
    return nil unless normalized

    {
      extract_area: [normalized[:left], normalized[:top], normalized[:width], normalized[:height]],
      resize_to_fill: [width, height],
      saver: { quality: 90 },
      format: :webp
    }
  end

  def portrait_crop_url(width: 720, height: 1280)
    return nil unless image.attached?
    variant_params = portrait_crop_variant(width: width, height: height)
    return nil unless variant_params

    begin
      # Don't call .processed here - it forces synchronous generation!
      # Just return the URL and let it process on first actual request
      variant = image.variant(variant_params)
      Rails.application.routes.url_helpers.rails_blob_url(
        variant,
        only_path: true
      )
    rescue ActiveStorage::FileNotFoundError
      nil
    end
  end

  def ensure_portrait_processed!(width: 720, height: 1280)
    return nil unless image.attached?
    variant_params = portrait_crop_variant(width: width, height: height)
    return nil unless variant_params

    # This method explicitly processes the variant
    image.variant(variant_params).processed
  rescue ActiveStorage::FileNotFoundError
    nil
  end

  def reset_portrait_crop!
    rect = default_portrait_crop_rect
    update!(portrait_crop_data: rect)
    rect
  end

  def update_portrait_crop!(rect_params)
    update!(portrait_crop_data: sanitize_portrait_crop(rect_params))
    # Clear cached portrait crop variants so they regenerate with new crop
    # purge_portrait_crop_variants
  end

  def default_portrait_crop_rect
    return nil unless image.attached?

    ensure_blob_dimensions

    blob_metadata = image.blob.metadata
    blob_width = blob_metadata['width']
    blob_height = blob_metadata['height']

    if face_data.present?
      blob_width ||= face_data['image_width']
      blob_height ||= face_data['image_height']
    end

    blob_width = blob_width&.to_f
    blob_height = blob_height&.to_f
    return nil unless blob_width&.positive? && blob_height&.positive?

    aspect_ratio = 9.0 / 16.0

    crop_height = blob_height
    crop_width = (crop_height * aspect_ratio)

    if crop_width > blob_width
      crop_width = blob_width
      crop_height = (crop_width / aspect_ratio)
    end

    face_center_x = if has_faces?
                      params = ::FaceDetectionService.face_crop_params(self)
                      if params
                        params[:left].to_f + (params[:width].to_f / 2.0)
                      end
                    end
    face_center_x ||= blob_width / 2.0

    left = (face_center_x - (crop_width / 2.0))
    left = 0 if left.negative?
    left = blob_width - crop_width if left + crop_width > blob_width

    top = ((blob_height - crop_height) / 2.0)
    top = 0 if top.negative?
    top = blob_height - crop_height if top + crop_height > blob_height

    normalize_portrait_rect(
      {
        left: left.round,
        top: top.round,
        width: crop_width.round,
        height: crop_height.round,
        source: 'default'
      }
    )
  end

  def sanitize_portrait_crop(rect_params)
    rect_params = rect_params.to_unsafe_h if rect_params.respond_to?(:to_unsafe_h)
    rect_params = rect_params.to_h if rect_params.respond_to?(:to_h) && !rect_params.is_a?(Hash)
    return default_portrait_crop_rect unless rect_params.is_a?(Hash)

    symbolized = rect_params.symbolize_keys
    permitted = symbolized.slice(:left, :top, :width, :height)
    image_width_hint = symbolized[:image_width]
    image_height_hint = symbolized[:image_height]

    ensure_blob_dimensions

    blob_metadata = image&.blob&.metadata || {}
    face_dimensions = face_data || {}
    blob_width = (blob_metadata['width'] || face_dimensions['image_width'] || image_width_hint || permitted[:width])&.to_f
    blob_height = (blob_metadata['height'] || face_dimensions['image_height'] || image_height_hint || permitted[:height])&.to_f

    return default_portrait_crop_rect unless blob_width && blob_height

    aspect_ratio = 9.0 / 16.0
    height = permitted[:height].to_f
    height = default_portrait_crop_rect[:height].to_f if height <= 0
    min_height = [[blob_height * 0.1, 50].max, blob_height].min
    height = [[height, min_height].max, blob_height].min
    width = height * aspect_ratio
    width = blob_width if width > blob_width
    height = width / aspect_ratio if width >= blob_width

    left = permitted[:left].to_f
    top = permitted[:top].to_f

    left = [[left, 0].max, blob_width - width].min
    top = [[top, 0].max, blob_height - height].min

    normalize_portrait_rect(
      {
        left: left.round,
        top: top.round,
        width: width.round,
        height: height.round,
        source: 'manual'
      }
    )
  end
  
  # Check if face detection is needed
  def needs_face_detection?
    face_detected_at.nil? && (image.attached? || original_path.present?)
  end
  
  # Extract EXIF datetime from original file using exiftool
  # The DateTimeOriginal field contains when the photo was actually taken
  # Format: "2025:08:25 15:14:48" (in camera's local time - PST at Burning Man)
  def extract_exif_datetime
    return unless original_path && File.exist?(original_path)
    
    # Use exiftool to extract DateTimeOriginal
    # -s3 flag returns just the value without field name
    result = `exiftool -DateTimeOriginal -s3 "#{original_path}" 2>/dev/null`.strip
    
    if result.present?
      self.exif_data ||= {}
      self.exif_data['DateTimeOriginal'] = result
      save! if persisted?
      result
    end
  end
  
  # Get the actual time the photo was taken
  # CRITICAL: This method is used for chronological sorting of sessions!
  # Returns UTC time to match the burst folder timestamps
  def photo_taken_at
    # First try to get from stored EXIF data
    if exif_data && exif_data['DateTimeOriginal']
      begin
        # EXIF datetime is in camera's local time (PST at Burning Man)
        # Format: "2025:08:25 15:14:48" - this is PST time
        # Must convert to UTC to match burst folder timestamps which are already UTC
        local_time = DateTime.strptime(exif_data['DateTimeOriginal'], '%Y:%m:%d %H:%M:%S')
        # Burning Man is in PST (UTC-7), so add 7 hours to get UTC
        local_time.change(offset: '-0700').utc
      rescue => e
        Rails.logger.warn "Failed to parse EXIF datetime for photo #{id}: #{e.message}"
        calculated_taken_at
      end
    else
      # Extract EXIF if not already done
      datetime_str = extract_exif_datetime
      if datetime_str.present?
        begin
          # EXIF datetime is in camera's local time (PST at Burning Man)
          local_time = DateTime.strptime(datetime_str, '%Y:%m:%d %H:%M:%S')
          # Burning Man is in PST (UTC-7)
          local_time.change(offset: '-0700').utc
        rescue => e
          Rails.logger.warn "Failed to parse extracted EXIF datetime for photo #{id}: #{e.message}"
          calculated_taken_at
        end
      else
        calculated_taken_at
      end
    end
  end
  
  # Fallback calculated time based on position in burst
  # Used when EXIF data is not available
  # Burst folder timestamp (already UTC) + offset based on photo position
  def calculated_taken_at
    # Canon R5 shoots approximately 0.5fps in burst mode (2 seconds per photo)
    # Position 0 = burst start time, Position 1 = +2 seconds, etc.
    photo_session.started_at + (position * 2).seconds
  end

  # Gender analysis - delegates to photo session
  def detected_gender
    photo_session&.detected_gender
  end

  def gender_confidence
    photo_session&.gender_confidence
  end

  def gender_data
    photo_session&.gender_data
  end

  private :sanitize_portrait_crop

  private

  def normalize_portrait_rect(rect)
    return nil unless rect.is_a?(Hash)

    ensure_blob_dimensions

    metadata = image&.blob&.metadata || {}
    actual_width = metadata['width']&.to_i
    actual_height = metadata['height']&.to_i

    return rect.symbolize_keys unless actual_width&.positive? && actual_height&.positive?

    left = rect[:left].to_i
    top = rect[:top].to_i
    width = rect[:width].to_i
    height = rect[:height].to_i

    left = left.clamp(0, actual_width - 1)
    top = top.clamp(0, actual_height - 1)

    max_width = [actual_width - left, 1].max
    max_height = [actual_height - top, 1].max

    width = width.clamp(1, max_width)
    height = height.clamp(1, max_height)

    {
      left: left,
      top: top,
      width: width,
      height: height,
      source: rect[:source]
    }
  end

  def ensure_blob_dimensions
    return unless image.attached?

    metadata = image.blob.metadata || {}
    return if metadata['width'].present? && metadata['height'].present?

    begin
      image.blob.analyze
      image.blob.reload
    rescue => e
      Rails.logger.warn("Failed to analyze blob dimensions for Photo ##{id}: #{e.message}")
    end
  end
end
