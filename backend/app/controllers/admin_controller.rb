class AdminController < ApplicationController
  before_action :authenticate_admin!
  
  def index
    # Redirect to the proper admin dashboard
    redirect_to admin_dashboard_path
  end
  
  def face_detection
    # Face detection specific admin page
    @stats = calculate_face_detection_stats
    @queue_stats = calculate_queue_stats
    @recent_face_jobs = recent_face_detection_jobs(20)
    @failed_face_jobs = failed_face_detection_jobs(10)
  end
  
  def queue_status
    @queue_stats = get_detailed_queue_statistics
    @processing_rate = get_processing_rate
    @estimated_completion = calculate_estimated_completion
    
    respond_to do |format|
      format.html
      format.json { render json: { 
        queues: @queue_stats, 
        rate: @processing_rate,
        completion: @estimated_completion
      }}
    end
  end
  
  def enqueue_all
    photos_count = Photo.without_face_detection.count
    
    if photos_count > 0
      # Enqueue in batches to avoid overwhelming the system
      Photo.without_face_detection.find_in_batches(batch_size: 100) do |batch|
        batch.each do |photo|
          FaceDetectionJob.perform_later(photo.id)
        end
      end
      
      flash[:success] = "Enqueued #{photos_count} face detection jobs successfully!"
    else
      flash[:info] = "All photos already have face detection data."
    end
    
    redirect_to admin_face_detection_path
  end
  
  def enqueue_session
    session = PhotoSession.find(params[:session_id])
    photos_without_faces = session.photos.without_face_detection
    count = photos_without_faces.count
    
    if count > 0
      photos_without_faces.each do |photo|
        FaceDetectionJob.perform_later(photo.id)
      end
      flash[:success] = "Enqueued #{count} face detection jobs for session #{session.burst_id}"
    else
      flash[:info] = "All photos in this session already have face detection data."
    end
    
    redirect_to admin_face_detection_path
  end
  
  def retry_failed
    failed_count = 0
    
    if defined?(SolidQueue::FailedExecution)
      failed_jobs = SolidQueue::FailedExecution.joins(:job)
                                               .where(solid_queue_jobs: { class_name: 'FaceDetectionJob' })
      
      failed_jobs.find_each do |failed_execution|
        job = failed_execution.job
        if job.arguments.present?
          photo_id = job.arguments.first
          FaceDetectionJob.perform_later(photo_id)
          failed_count += 1
        end
      end
    end
    
    if failed_count > 0
      flash[:success] = "Re-enqueued #{failed_count} failed face detection jobs!"
    else
      flash[:info] = "No failed face detection jobs to retry."
    end
    
    redirect_to admin_face_detection_path
  end
  
  def clear_completed_jobs
    if defined?(SolidQueue::Job)
      completed_count = SolidQueue::Job.where.not(finished_at: nil).count
      SolidQueue::Job.where.not(finished_at: nil).delete_all
      
      flash[:success] = "Cleared #{completed_count} completed jobs from the queue."
    else
      flash[:error] = "Unable to clear jobs - Solid Queue not available."
    end
    
    redirect_to admin_face_detection_path
  end
  
  def pause_queue
    # Implementation depends on your queue management needs
    flash[:info] = "Queue pause functionality not implemented yet."
    redirect_to admin_face_detection_path
  end
  
  private
  
  def authenticate_admin!
    # Simple authentication - you might want something more robust
    unless Rails.env.development?
      # In production, you'd want proper authentication
      # authenticate_user!
      # redirect_to root_path unless current_user&.admin?
    end
  end
  
  def calculate_stats
    {
      total_photos: Photo.count,
      total_sessions: PhotoSession.count,
      photos_with_faces: Photo.where.not(face_data: nil).count,
      photos_without_faces: Photo.where(face_data: nil).count
    }
  end
  
  def calculate_face_detection_stats
    total_photos = Photo.count
    photos_with_data = Photo.where.not(face_data: nil).count
    photos_without_data = Photo.where(face_data: nil).count
    
    # Count photos with actual detected faces
    photos_with_faces = Photo.where.not(face_data: nil)
                             .select { |p| p.face_data['faces'].present? && p.face_data['faces'].any? }
                             .count
    
    {
      total_photos: total_photos,
      processed_photos: photos_with_data,
      unprocessed_photos: photos_without_data,
      photos_with_faces: photos_with_faces,
      photos_without_faces: photos_with_data - photos_with_faces,
      processing_percentage: total_photos > 0 ? (photos_with_data.to_f / total_photos * 100).round(2) : 0
    }
  end
  
  def calculate_queue_stats
    return {} unless defined?(SolidQueue::Job)
    
    total_jobs = SolidQueue::Job.count
    finished_jobs = SolidQueue::Job.where.not(finished_at: nil).count
    pending_jobs = SolidQueue::Job.where(finished_at: nil).count
    
    face_detection_jobs = SolidQueue::Job.where(class_name: 'FaceDetectionJob').count
    pending_face_jobs = SolidQueue::Job.where(class_name: 'FaceDetectionJob', finished_at: nil).count
    
    failed_jobs = 0
    failed_face_jobs = 0
    
    if defined?(SolidQueue::FailedExecution)
      failed_jobs = SolidQueue::FailedExecution.count
      failed_face_jobs = SolidQueue::FailedExecution.joins(:job)
                                                    .where(solid_queue_jobs: { class_name: 'FaceDetectionJob' })
                                                    .count
    end
    
    {
      total_jobs: total_jobs,
      finished_jobs: finished_jobs,
      pending_jobs: pending_jobs,
      failed_jobs: failed_jobs,
      face_detection_jobs: face_detection_jobs,
      pending_face_jobs: pending_face_jobs,
      failed_face_jobs: failed_face_jobs
    }
  end
  
  def recent_jobs(limit = 10)
    return [] unless defined?(SolidQueue::Job)
    
    SolidQueue::Job.order(created_at: :desc).limit(limit)
  end
  
  def failed_jobs(limit = 5)
    return [] unless defined?(SolidQueue::FailedExecution)
    
    SolidQueue::FailedExecution.includes(:job)
                                .order(created_at: :desc)
                                .limit(limit)
  end
  
  def recent_face_detection_jobs(limit = 20)
    return [] unless defined?(SolidQueue::Job)
    
    SolidQueue::Job.where(class_name: 'FaceDetectionJob')
                   .order(created_at: :desc)
                   .limit(limit)
  end
  
  def failed_face_detection_jobs(limit = 10)
    return [] unless defined?(SolidQueue::FailedExecution)
    
    SolidQueue::FailedExecution.joins(:job)
                                .where(solid_queue_jobs: { class_name: 'FaceDetectionJob' })
                                .includes(:job)
                                .order(created_at: :desc)
                                .limit(limit)
  end
  
  def get_detailed_queue_statistics
    # Get pending jobs by queue
    pending = SolidQueue::Job.where(finished_at: nil).group(:queue_name).count
    
    # Get completed jobs in last hour for rate calculation
    completed_last_hour = SolidQueue::Job
      .where('finished_at > ?', 1.hour.ago)
      .where.not(finished_at: nil)
      .group(:queue_name)
      .count
    
    # Get total jobs ever created by queue (for progress calculation)
    total_jobs = SolidQueue::Job.group(:queue_name).count
    
    # Calculate statistics for each queue
    queues = {}
    all_queues = (pending.keys + completed_last_hour.keys + total_jobs.keys).uniq
    
    all_queues.each do |queue_name|
      pending_count = pending[queue_name] || 0
      completed_count = total_jobs[queue_name] || 0
      completed_recent = completed_last_hour[queue_name] || 0
      
      # Calculate progress percentage
      total_ever = pending_count + completed_count
      progress = total_ever > 0 ? ((completed_count.to_f / total_ever) * 100).round(1) : 0
      
      queues[queue_name] = {
        pending: pending_count,
        completed: completed_count,
        completed_last_hour: completed_recent,
        total: total_ever,
        progress: progress,
        rate_per_hour: completed_recent,
        rate_per_minute: (completed_recent / 60.0).round(2)
      }
    end
    
    queues
  end

  def get_processing_rate
    # Jobs completed in last 5 minutes for current rate
    recent_jobs = SolidQueue::Job
      .where('finished_at > ?', 5.minutes.ago)
      .where.not(finished_at: nil)
      .count
    
    (recent_jobs / 5.0).round(2) # jobs per minute
  end

  def calculate_estimated_completion
    total_pending = SolidQueue::Job.where(finished_at: nil).count
    return nil if total_pending == 0
    
    current_rate = get_processing_rate
    return nil if current_rate == 0
    
    minutes_remaining = (total_pending / current_rate).round
    Time.current + minutes_remaining.minutes
  end
end