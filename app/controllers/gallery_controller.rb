class GalleryController < ApplicationController
  helper VariantUrlHelper
  helper HeroHelper
  skip_before_action :verify_authenticity_token, only: [ :update_hero, :reject_photo, :save_email, :hide_session ]
  # Preloader disabled - all variants are pre-generated
  # before_action :check_preloader_shown, only: [:index]

  def index
    force_refresh = params[:refresh] == "1"
    @gallery_version = GalleryCache.version

    # Apply hero filter if requested by admin (from session)
    @hide_heroes = current_user&.admin? && session[:hide_heroes] == true

    payload = GalleryCache.index_payload(
      version: @gallery_version,
      hide_heroes: @hide_heroes,
      force: force_refresh
    )

    session_ids = payload[:session_ids]
    sessions = if session_ids.any?
                 PhotoSession.includes(:session_day, hero_photo: { image_attachment: :blob })
                             .where(id: session_ids)
    else
                 []
    end
    sessions_by_id = sessions.index_by(&:id)

    @sessions_by_day = payload[:session_ids_by_day].transform_values do |ids|
      ids.filter_map { |session_id| sessions_by_id[session_id] }
    end

    middle_photo_ids = payload[:middle_photo_ids].values.compact
    middle_photos = if middle_photo_ids.any?
                      Photo.includes(image_attachment: :blob).where(id: middle_photo_ids)
    else
                      []
    end
    photos_by_id = middle_photos.index_by(&:id)
    @middle_photos = payload[:middle_photo_ids].each_with_object({}) do |(session_id, photo_id), memo|
      photo = photos_by_id[photo_id]
      memo[session_id] = photo if photo
    end

    @face_counts = payload[:face_counts]
    @stats = payload[:stats]

    fresh_when(
      etag: [ @gallery_version, (@hide_heroes ? "hide" : "all") ],
      last_modified: GalleryCache.last_modified,
      public: false
    )
  end

  def show
    # Support both old burst_id URLs and new session ID URLs
    # Get the session ID from either :id or :session_id parameter
    session_param = params[:id] || params[:session_id]

    if session_param&.start_with?("burst_")
      @session = PhotoSession.includes(:photos, :sittings).find_by!(burst_id: session_param)
    else
      @session = PhotoSession.includes(:photos, :sittings).find(session_param)
    end

    # Handle rejected photo filtering
    @show_rejected = params[:show_rejected] == "true"

    if @show_rejected
      @photos = @session.photos.order(:position)
    else
      @photos = @session.photos.accepted.order(:position)
    end

    # Get rejected photo count for toggle button
    @rejected_count = @session.photos.rejected.count

    # Get hero photo directly from PhotoSession (not from unreliable Sitting model)
    @hero_photo = @session.hero_photo

    # Calculate the initial photo index
    # Priority order:
    # 1. Explicit navigation flow (arrow keys between sessions)
    # 2. Direct photo links (from URLs)
    # 3. Session entry from index (hero/middle photo)
    if params[:start] == "last"
      # Start at last photo when navigating backward from next session
      @initial_index = @photos.length - 1
    elsif params[:start] == "first"
      # Start at first photo when navigating forward from previous session
      @initial_index = 0
    elsif params[:photo_position]
      # Direct link to specific photo by position
      @initial_index = params[:photo_position].to_i - 1 # Convert 1-based to 0-based
    elsif params[:image]
      # Legacy image parameter support
      @initial_index = params[:image].to_i
    elsif @hero_photo && @photos.include?(@hero_photo)
      # Start at hero photo if one is selected (when coming from index)
      @initial_index = @photos.index(@hero_photo)
    else
      # Default to middle photo if no hero selected (when coming from index)
      @initial_index = @photos.length / 2
    end

    # Check if we should hide sessions with heroes (from session)
    @hide_heroes = current_user&.admin? && session[:hide_heroes] == true

    # Find adjacent sessions for navigation (filter by hero status if needed)
    sessions_scope = PhotoSession.visible
                                 .includes(:session_day)
                                 .order("session_days.date ASC, photo_sessions.started_at ASC")

    # Apply hero filter if requested
    if @hide_heroes
      sessions_scope = sessions_scope.where(hero_photo_id: nil)
    end

    all_sessions = sessions_scope.pluck(:id)
    current_index = all_sessions.find_index(@session.id)

    @prev_session_id = current_index && current_index > 0 ? all_sessions[current_index - 1] : nil
    @next_session_id = current_index && current_index < all_sessions.length - 1 ? all_sessions[current_index + 1] : nil
  end

  def update_hero
    # Support both burst_id and session ID
    if params[:id]&.start_with?("burst_")
      @session = PhotoSession.find_by!(burst_id: params[:id])
    else
      @session = PhotoSession.find(params[:id])
    end
    @photo = @session.photos.find(params[:photo_id])

    # Update hero photo directly on PhotoSession (not on unreliable Sitting model)
    @session.update!(hero_photo_id: @photo.id)

    # Touch the session to invalidate cache when hero photo changes
    # This ensures the gallery index page shows the new hero photo
    @session.touch

    # Queue background job to pre-generate portrait variants
    PortraitVariantJob.perform_later(@photo.id) if @photo.portrait_crop_data.present?

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to gallery_path(@session.burst_id) }
    end
  end

  def save_email
    # Support both burst_id and session ID
    if params[:id]&.start_with?("burst_")
      @session = PhotoSession.find_by!(burst_id: params[:id])
    else
      @session = PhotoSession.find(params[:id])
    end
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
    # Support both burst_id and session ID
    if params[:id]&.start_with?("burst_")
      @session = PhotoSession.find_by!(burst_id: params[:id])
    else
      @session = PhotoSession.find(params[:id])
    end
    @photo = @session.photos.find(params[:photo_id])

    @photo.update!(rejected: !@photo.rejected)

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to gallery_path(@session.burst_id, show_rejected: params[:show_rejected]) }
    end
  end

  def split_session
    # Support both burst_id and session ID
    if params[:id]&.start_with?("burst_")
      @session = PhotoSession.find_by!(burst_id: params[:id])
    else
      @session = PhotoSession.find(params[:id])
    end
    @photo = @session.photos.find(params[:photo_id])

    new_session = @session.split_at_photo(@photo.id)

    if new_session
      # Reload both sessions with all associations
      @session.reload
      new_session.reload

      # For Turbo Stream response, we need to recalculate global indices
      if request.format.turbo_stream? || (request.format.json? && params[:turbo])
        # Get the day for both sessions
        @day = @session.session_day

        # Get all sessions for this day to maintain order
        day_sessions = PhotoSession.visible
                                   .includes(:session_day, photos: { image_attachment: :blob }, sittings: {})
                                   .where(session_day: @day)
                                   .order(:started_at)

        # Recalculate global indices for all photos in this day
        @global_indices = {}
        global_index = 0

        # First count photos from sessions before this day
        PhotoSession.visible
                    .joins(:session_day)
                    .where("session_days.date < ?", @day.date)
                    .order("session_days.date ASC, photo_sessions.started_at ASC")
                    .each do |s|
          global_index += s.photos.count
        end

        # Then calculate indices for this day's sessions
        day_sessions.each do |s|
          s.photos.order(:position).each do |photo|
            @global_indices[photo.id] = global_index
            global_index += 1
          end
        end
      end

      respond_to do |format|
        format.turbo_stream {
          render turbo_stream: [
            turbo_stream.replace("session_#{@session.burst_id}",
                                partial: "admin/thumbnails/session",
                                locals: { session: @session, day: @day, global_indices: @global_indices }),
            turbo_stream.after("session_#{@session.burst_id}",
                              partial: "admin/thumbnails/session",
                              locals: { session: new_session, day: @day, global_indices: @global_indices }),
            turbo_stream.append("body",
                               "<script>document.dispatchEvent(new CustomEvent('sessions:updated', { detail: { sessionId: '#{@session.burst_id}', newSessionId: '#{new_session.burst_id}' } }))</script>".html_safe)
          ]
        }
        format.json {
          if params[:turbo]
            render json: {
              success: true,
              new_session_id: new_session.burst_id,
              turbo_streams: render_to_string(
                turbo_stream: [
                  turbo_stream.replace("session_#{@session.burst_id}",
                                      partial: "admin/thumbnails/session",
                                      locals: { session: @session, day: @day, global_indices: @global_indices }),
                  turbo_stream.after("session_#{@session.burst_id}",
                                    partial: "admin/thumbnails/session",
                                    locals: { session: new_session, day: @day, global_indices: @global_indices })
                ]
              )
            }
          else
            render json: { success: true, new_session_id: new_session.burst_id }
          end
        }
        format.html { redirect_to gallery_path(new_session.burst_id), notice: "Session split successfully" }
      end
    else
      respond_to do |format|
        format.turbo_stream {
          render turbo_stream: turbo_stream.append("body",
            "<script>alert('Failed to split session: #{@session.errors.full_messages.join(", ")}')</script>".html_safe)
        }
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
      format.turbo_stream {
        render turbo_stream: turbo_stream.append("body",
          "<script>alert('Photo not found')</script>".html_safe)
      }
      format.json { render json: { success: false, error: "Photo not found", errors: [ "Photo not found" ] }, status: :not_found }
      format.html { redirect_to gallery_path(@session.burst_id), alert: "Photo not found" }
    end
  end

  def download_photo
    # Support both burst_id and session ID
    if params[:id]&.start_with?("burst_")
      @session = PhotoSession.find_by!(burst_id: params[:id])
    else
      @session = PhotoSession.find(params[:id])
    end
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
    when ".jpg", ".jpeg"
                     "image/jpeg"
    when ".heic"
                     "image/heic"
    when ".png"
                     "image/png"
    else
                     "application/octet-stream"
    end

    # Send the original file with proper filename
    send_file file_path,
              filename: File.basename(file_path),
              type: content_type,
              disposition: "attachment"
  rescue ActiveRecord::RecordNotFound
    redirect_to gallery_path(@session.burst_id), alert: "Photo not found"
  end

  def prepare_download
    # Support both burst_id and session ID
    if params[:id]&.start_with?("burst_")
      @session = PhotoSession.find_by!(burst_id: params[:id])
    else
      @session = PhotoSession.find(params[:id])
    end

    # Eager load image attachments for thumbnails
    @photos = @session.photos.accepted.includes(image_attachment: :blob).order(:position)

    if @photos.empty?
      redirect_to gallery_path(@session.burst_id), alert: "No photos found in this session"
      return
    end

    # Calculate estimated file size (rough estimate from blob sizes)
    @estimated_size = @photos.sum { |p| p.image.attached? ? (p.image.blob.byte_size || 0) : 0 }
  rescue ActiveRecord::RecordNotFound
    redirect_to root_path, alert: "Session not found"
  end

  def download_all
    # Support both burst_id and session ID
    if params[:id]&.start_with?("burst_")
      @session = PhotoSession.find_by!(burst_id: params[:id])
    else
      @session = PhotoSession.find(params[:id])
    end

    # Eager load image attachments to avoid N+1 queries
    photos = @session.photos.accepted.includes(image_attachment: :blob).order(:position)

    if photos.empty?
      redirect_to gallery_path(@session.burst_id), alert: "No photos found in this session"
      return
    end

    Rails.logger.info "Starting download_all for session #{@session.burst_id} with #{photos.count} photos"

    require "tempfile"
    require "fileutils"
    require "zip"

    # Check if this is a Turbo Stream request (from prepare_download page)
    if request.format.turbo_stream?
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.action(:append, "body", partial: "gallery/download_stream",
                                                   locals: { session: @session, photos: photos })
        end
      end
      return
    end

    # Regular download (direct link or after preparation)
    temp_zip = nil

    begin
      # Create ZIP file using RubyZip to avoid shelling out
      temp_zip = Tempfile.new([ "session_photos", ".zip" ])
      copied_count = 0

      Zip::OutputStream.open(temp_zip.path) do |zos|
        photos.each do |photo|
          # Use Active Storage attachment instead of original_path
          # This works with both local disk and remote storage (MinIO/S3)
          unless photo.image.attached?
            Rails.logger.warn "Photo #{photo.id} has no attachment"
            next
          end

          begin
            # Get the blob and download it
            blob = photo.image.blob

            # Determine file extension from blob content_type or filename
            extension = case blob.content_type
                       when "image/jpeg"
                         ".jpg"
                       when "image/heic"
                         ".heic"
                       when "image/png"
                         ".png"
                       else
                         File.extname(blob.filename.to_s)
                       end

            filename = "#{photo.position.to_s.rjust(3, '0')}_#{blob.filename}"

            # Write blob data to ZIP
            zos.put_next_entry(filename)
            blob.download { |chunk| zos.write(chunk) }
            copied_count += 1

            Rails.logger.debug "Added photo #{photo.id} (#{blob.byte_size} bytes) to ZIP"
          rescue => e
            Rails.logger.error "Failed to add photo #{photo.id} to ZIP: #{e.message}"
            next
          end
        end
      end

      if copied_count == 0
        redirect_to gallery_path(@session.burst_id), alert: "No photo files could be found"
        return
      end

      # Verify zip has content
      if !File.exist?(temp_zip.path) || File.size(temp_zip.path) == 0
        Rails.logger.error "ZIP file was not created or is empty"
        redirect_to gallery_path(@session.burst_id), alert: "Failed to create download archive"
        return
      end

      Rails.logger.info "ZIP file created successfully with #{copied_count} photos, size: #{File.size(temp_zip.path)} bytes"

      # Get session info for filename
      session_number = @session.burst_id.match(/burst_(\d+)/)&.[](1) || @session.burst_id
      zip_filename = "Session_#{session_number}_Photos.zip"

      # Send the zip file
      send_file temp_zip.path,
                filename: zip_filename,
                type: "application/zip",
                disposition: "attachment"

      Rails.logger.info "ZIP file sent successfully"

    rescue => e
      Rails.logger.error "Error in download_all: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      redirect_to gallery_path(@session.burst_id), alert: "An error occurred while preparing the download"
    ensure
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
    # Support both burst_id and session ID
    if params[:id]&.start_with?("burst_")
      @session = PhotoSession.find_by!(burst_id: params[:id])
    else
      @session = PhotoSession.find(params[:id])
    end

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
    # Support both burst_id and session ID
    if params[:id]&.start_with?("burst_")
      @session = PhotoSession.find_by!(burst_id: params[:id])
    else
      @session = PhotoSession.find(params[:id])
    end

    # Create a simple test file to download
    require "tempfile"
    temp_file = Tempfile.new([ "test", ".txt" ])
    temp_file.write("Test download for session #{@session.burst_id}")
    temp_file.close

    send_file temp_file.path,
              filename: "test_session_#{@session.burst_id.split('_')[1]}.txt",
              type: "text/plain",
              disposition: "attachment"
  ensure
    temp_file&.unlink
  end

  def day_sessions
    day = params[:day]
    @sessions = PhotoSession.visible
                           .includes(:session_day, :photos, sittings: :hero_photo)
                           .joins(:session_day)
                           .where(session_days: { day_name: day })
                           .order(:started_at)

    render partial: "day_sessions", locals: { sessions: @sessions }
  end

  def toggle_hide_heroes
    if current_user&.admin?
      # Explicitly handle nil case and ensure boolean value
      current_state = session[:hide_heroes] == true
      session[:hide_heroes] = !current_state
      Rails.logger.info "Toggled hide_heroes from #{current_state} to #{session[:hide_heroes]}"
    end
    redirect_back(fallback_location: root_path)
  end

  private

  def check_preloader_shown
    # Skip check for admin users or if explicitly bypassed
    return if current_user&.admin?
    return if params[:skip_preloader] == "true"

    # Check if preloader has been shown
    unless cookies[:preloader_shown].present?
      redirect_to preloader_path
    end
  end
end
