require 'open3'
require 'tempfile'

class FaceDetectionService
  DETECTION_SCRIPT = Rails.root.join('bin', 'detect_faces.swift').to_s.freeze
  
  attr_reader :photo, :result
  
  def initialize(photo)
    @photo = photo
    @result = nil
  end
  
  def self.detect_for_photo(photo)
    new(photo).detect
  end
  
  def self.detect_for_session(session)
    session.photos.find_each do |photo|
      detect_for_photo(photo)
      sleep 0.1 # Be nice to the CPU
    end
  end
  
  def detect
    return if photo.face_detected_at.present? && photo.face_data.present?
    
    image_path = get_image_path
    return unless image_path && File.exist?(image_path)
    
    # Execute Swift face detection script
    output = execute_detection(image_path)
    return unless output
    
    # Parse and save results
    parse_and_save_results(output)
    
    photo
  end
  
  private
  
  def get_image_path
    if photo.image.attached?
      # For Active Storage files, download to temp file
      temp_file = Tempfile.new(['face_detect', File.extname(photo.image.filename.to_s)])
      temp_file.binmode
      photo.image.download { |chunk| temp_file.write(chunk) }
      temp_file.close
      temp_file.path
    elsif photo.original_path.present?
      # For original file paths
      full_path = if photo.original_path.start_with?('/')
        photo.original_path
      else
        "/Users/jeremy/Desktop/OK-SHOCK-25/#{photo.original_path}"
      end
      
      full_path if File.exist?(full_path)
    end
  end
  
  def execute_detection(image_path)
    command = "swift #{DETECTION_SCRIPT} \"#{image_path}\""
    
    stdout, stderr, status = Open3.capture3(command)
    
    if status.success?
      stdout
    else
      Rails.logger.error "Face detection failed for photo #{photo.id}: #{stderr}"
      nil
    end
  rescue => e
    Rails.logger.error "Face detection error for photo #{photo.id}: #{e.message}"
    nil
  end
  
  def parse_and_save_results(output)
    @result = JSON.parse(output)
    
    if @result['success']
      face_data = {
        'image_width' => @result['imageWidth'],
        'image_height' => @result['imageHeight'],
        'faces' => @result['faces'],
        'detection_version' => '1.0'
      }
      
      photo.update!(
        face_data: face_data,
        face_detected_at: Time.current
      )
      
      Rails.logger.info "Detected #{@result['faces'].length} face(s) in photo #{photo.id}"
    else
      Rails.logger.warn "Face detection returned error for photo #{photo.id}: #{@result['error']}"
    end
  rescue JSON::ParserError => e
    Rails.logger.error "Failed to parse face detection output for photo #{photo.id}: #{e.message}"
  end
  
  # Helper method to get the primary face (largest)
  def self.primary_face(photo)
    return nil unless photo.face_data.present? && photo.face_data['faces'].present?
    
    faces = photo.face_data['faces']
    faces.max_by { |face| face['width'] * face['height'] }
  end
  
  # Helper method to get face crop parameters with padding
  def self.face_crop_params(photo, padding_percent: 20)
    face = primary_face(photo)
    return nil unless face
    
    image_width = photo.face_data['image_width']
    image_height = photo.face_data['image_height']
    
    # Calculate padding
    padding_x = face['width'] * (padding_percent / 100.0)
    padding_y = face['height'] * (padding_percent / 100.0)
    
    # Calculate crop with padding
    left = [(face['x'] - padding_x), 0].max
    top = [(face['y'] - padding_y), 0].max
    width = [face['width'] + (padding_x * 2), image_width - left].min
    height = [face['height'] + (padding_y * 2), image_height - top].min
    
    {
      left: left.round,
      top: top.round,
      width: width.round,
      height: height.round
    }
  end
end