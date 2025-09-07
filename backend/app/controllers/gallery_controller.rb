class GalleryController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [:update_hero, :reject_photo, :save_email, :hide_session]
  def index
    @sessions_by_day = PhotoSession.visible
                                   .includes(:session_day, :photos, sittings: :hero_photo)
                                   .order('session_days.date ASC, photo_sessions.started_at ASC')
                                   .group_by { |s| s.session_day.day_name }
    
    @stats = {
      total_sessions: PhotoSession.visible.count,
      total_photos: Photo.joins(:photo_session).where(photo_sessions: { hidden: false }).count,
      by_day: SessionDay.joins(:photo_sessions).where(photo_sessions: { hidden: false }).group('session_days.day_name').count
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
    
    # Find adjacent sessions for navigation (only visible sessions)
    all_sessions = PhotoSession.visible
                               .includes(:session_day)
                               .order('session_days.date ASC, photo_sessions.started_at ASC')
                               .pluck(:burst_id)
    current_index = all_sessions.index(@session.burst_id)
    
    @prev_session = current_index && current_index > 0 ? all_sessions[current_index - 1] : nil
    @next_session = current_index && current_index < all_sessions.length - 1 ? all_sessions[current_index + 1] : nil
  end
  
  def update_hero
    @session = PhotoSession.find_by!(burst_id: params[:id])
    @photo = @session.photos.find(params[:photo_id])
    
    # Create sitting if it doesn't exist, or update existing ones
    if @session.sittings.exists?
      @session.sittings.update_all(hero_photo_id: @photo.id)
    else
      # Create a sitting record with placeholder email to store hero selection
      @session.sittings.create!(
        email: "placeholder@placeholder.com", 
        hero_photo_id: @photo.id
      )
    end
    
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

  def download_photo
    @session = PhotoSession.find_by!(burst_id: params[:id])
    @photo = @session.photos.find(params[:photo_id])
    
    # Get the original file path
    file_path = @photo.original_path
    
    unless File.exist?(file_path)
      redirect_to gallery_path(@session.burst_id), alert: "Photo file not found"
      return
    end
    
    # Determine MIME type based on file extension
    extension = File.extname(file_path).downcase
    content_type = case extension
                   when '.jpg', '.jpeg'
                     'image/jpeg'
                   when '.heic'
                     'image/heic'
                   when '.png'
                     'image/png'
                   else
                     'application/octet-stream'
                   end
    
    # Send the original file with proper filename
    send_file file_path, 
              filename: File.basename(file_path),
              type: content_type,
              disposition: 'attachment'
  rescue ActiveRecord::RecordNotFound
    redirect_to gallery_path(@session.burst_id), alert: "Photo not found"
  end

  def download_all
    @session = PhotoSession.find_by!(burst_id: params[:id])
    
    photos = @session.photos.accepted.order(:position)
    
    if photos.empty?
      redirect_to gallery_path(@session.burst_id), alert: "No photos found in this session"
      return
    end
    
    Rails.logger.info "Starting download_all for session #{@session.burst_id} with #{photos.count} photos"
    
    require 'tempfile'
    require 'fileutils'
    require 'shellwords'
    
    temp_zip = nil
    temp_dir = nil
    
    begin
      # Create temporary directory for organizing files
      temp_dir = Dir.mktmpdir('session_photos')
      Rails.logger.info "Created temp directory: #{temp_dir}"
      
      # Copy photos to temp directory with clean names
      copied_count = 0
      photos.each do |photo|
        if File.exist?(photo.original_path)
          filename = "#{photo.position.to_s.rjust(3, '0')}_#{File.basename(photo.original_path)}"
          dest_path = File.join(temp_dir, filename)
          FileUtils.cp(photo.original_path, dest_path)
          copied_count += 1
          Rails.logger.info "Copied #{filename}"
        else
          Rails.logger.warn "Photo file not found: #{photo.original_path}"
        end
      end
      
      if copied_count == 0
        redirect_to gallery_path(@session.burst_id), alert: "No photo files could be found"
        return
      end
      
      # Create ZIP file using system command (most reliable)
      temp_zip = Tempfile.new(['session_photos', '.zip'])
      
      # Use absolute paths and proper escaping
      zip_command = "cd #{Shellwords.escape(temp_dir)} && zip -q -r #{Shellwords.escape(temp_zip.path)} ."
      Rails.logger.info "Running ZIP command: #{zip_command}"
      
      zip_result = system(zip_command)
      zip_exit_status = $?.exitstatus
      
      Rails.logger.info "ZIP command result: #{zip_result}, exit status: #{zip_exit_status}"
      
      unless zip_result && zip_exit_status == 0
        Rails.logger.error "ZIP command failed with exit status #{zip_exit_status}"
        redirect_to gallery_path(@session.burst_id), alert: "Failed to create download archive"
        return
      end
      
      # Check if zip file was created and has content
      unless File.exist?(temp_zip.path) && File.size(temp_zip.path) > 0
        Rails.logger.error "ZIP file was not created or is empty"
        redirect_to gallery_path(@session.burst_id), alert: "Failed to create download archive"
        return
      end
      
      Rails.logger.info "ZIP file created successfully, size: #{File.size(temp_zip.path)} bytes"
      
      # Get session info for filename
      session_number = @session.burst_id.match(/burst_(\d+)/)&.[](1) || @session.burst_id
      zip_filename = "Session_#{session_number}_Photos.zip"
      
      # Send the zip file
      send_file temp_zip.path,
                filename: zip_filename,
                type: 'application/zip',
                disposition: 'attachment'
      
      Rails.logger.info "ZIP file sent successfully"
      
    rescue => e
      Rails.logger.error "Error in download_all: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      redirect_to gallery_path(@session.burst_id), alert: "An error occurred while preparing the download"
    ensure
      # Clean up temp files
      if temp_dir && Dir.exist?(temp_dir)
        FileUtils.remove_entry(temp_dir)
        Rails.logger.info "Cleaned up temp directory"
      end
      if temp_zip
        temp_zip.close
        temp_zip.unlink rescue nil
        Rails.logger.info "Cleaned up temp ZIP file"
      end
    end
  rescue ActiveRecord::RecordNotFound
    redirect_to root_path, alert: "Session not found"
  end

  def hide_session
    @session = PhotoSession.find_by!(burst_id: params[:id])
    
    @session.update!(hidden: true)
    
    respond_to do |format|
      format.html { redirect_to root_path, notice: "Session #{@session.session_number} has been hidden." }
      format.json { render json: { success: true, message: "Session hidden successfully" } }
    end
  rescue ActiveRecord::RecordNotFound
    respond_to do |format|
      format.html { redirect_to root_path, alert: "Session not found" }
      format.json { render json: { success: false, error: "Session not found" }, status: :not_found }
    end
  end

  def download_test
    @session = PhotoSession.find_by!(burst_id: params[:id])
    
    # Create a simple test file to download
    require 'tempfile'
    temp_file = Tempfile.new(['test', '.txt'])
    temp_file.write("Test download for session #{@session.burst_id}")
    temp_file.close
    
    send_file temp_file.path,
              filename: "test_session_#{@session.burst_id.split('_')[1]}.txt",
              type: 'text/plain',
              disposition: 'attachment'
  ensure
    temp_file&.unlink
  end
end