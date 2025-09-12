class StatsController < ApplicationController
  skip_before_action :authenticate_user!
  
  def index
    @total_sessions = PhotoSession.visible.count
    @total_photos = Photo.count
    @total_faces_detected = Photo.where.not(face_data: nil).count
    @total_heroes = Sitting.where.not(hero_photo_id: nil).count
    @total_rejected = Photo.where(rejected: true).count
    @total_sittings = Sitting.count
    
    # Average photos per session
    @avg_photos_per_session = @total_sessions > 0 ? (@total_photos.to_f / @total_sessions.to_f) : 0
    
    # Hero selection rate
    @hero_rate = @total_photos > 0 ? (@total_heroes.to_f / @total_photos.to_f * 100).round(1) : 0
    @rejection_rate = @total_photos > 0 ? (@total_rejected.to_f / @total_photos.to_f * 100).round(1) : 0
    
    # Camera breakdown
    @canon_sessions = PhotoSession.visible.where("burst_id LIKE 'burst_%'").count
    @iphone_sessions = PhotoSession.visible.where("burst_id LIKE 'iphone_%'").count
    
    # Storage stats (if using Active Storage)
    @total_storage_gb = calculate_storage_usage
    
    # Sessions by day (excluding Saturday which only has 1 session)
    @sessions_by_day = PhotoSession.visible
      .reject { |s| s.started_at.wday == 6 } # Exclude Saturday
      .group_by { |s| s.started_at.to_date }
      .transform_values(&:count)
      .sort
    
    # Daily breakdown with details
    @daily_details = PhotoSession.visible
      .group_by { |s| s.started_at.to_date }
      .transform_values do |sessions|
        total_photos = sessions.sum { |s| s.photos.count }
        {
          count: sessions.count,
          photos: total_photos,
          avg_photos: sessions.count > 0 ? (total_photos.to_f / sessions.count).round(1) : 0
        }
      end
      .sort
      .to_h
    
    # Daily session timelines for each day (Monday-Friday)
    @daily_session_timelines = {}
    
    # Group sessions by day
    sessions_by_day = PhotoSession.visible.group_by { |s| s.started_at.to_date }
    
    # Process each day (Monday Aug 25 - Friday Aug 29)
    dates = ['2025-08-25', '2025-08-26', '2025-08-27', '2025-08-28', '2025-08-29'].map { |d| Date.parse(d) }
    
    dates.each do |date|
      day_sessions = sessions_by_day[date] || []
      
      sessions_data = day_sessions.map do |session|
        # Convert UTC to PDT (UTC-7)
        pdt_time = session.started_at - 7.hours
        {
          time: pdt_time.strftime("%H:%M"),
          hour: pdt_time.hour,
          minute: pdt_time.min,
          photo_count: session.photos.count,
          burst_id: session.burst_id
        }
      end.sort_by { |s| [s[:hour], s[:minute]] }
      
      # Calculate average for the day
      total_photos = sessions_data.sum { |s| s[:photo_count] }
      avg_photos = sessions_data.any? ? (total_photos.to_f / sessions_data.count).round(1) : 0
      
      @daily_session_timelines[date.strftime("%Y-%m-%d")] = {
        sessions: sessions_data,
        average: avg_photos,
        day_name: date.strftime("%A, %B %d")
      }
    end
    
    # Time distribution (UTC hours for reference)
    @sessions_by_hour = PhotoSession.visible
      .group_by { |s| s.started_at.hour }
      .transform_values(&:count)
      .sort
    
    # Photos per session distribution
    @photo_distribution = PhotoSession.visible
      .joins(:photos)
      .group(:id)
      .count
      .values
      .group_by { |count| 
        case count
        when 1..10 then "1-10"
        when 11..20 then "11-20"
        when 21..30 then "21-30"
        when 31..40 then "31-40"
        when 41..50 then "41-50"
        else "50+"
        end
      }
      .transform_values(&:count)
    
    # Top sessions by photo count
    @top_sessions = PhotoSession.visible
      .left_joins(:photos)
      .group('photo_sessions.id, photo_sessions.burst_id, photo_sessions.started_at')
      .order('COUNT(photos.id) DESC')
      .limit(10)
      .pluck('photo_sessions.burst_id', 'photo_sessions.started_at', 'COUNT(photos.id)')
      .map { |burst_id, started_at, count| 
        {
          burst_id: burst_id,
          started_at: started_at,
          count: count
        }
      }
    
    # Face detection stats
    @face_stats = {
      no_faces: Photo.where(face_data: nil).count,
      one_face: Photo.where.not(face_data: nil).select { |p| 
        begin
          data = JSON.parse(p.face_data) rescue nil
          data && data['face_count'] == 1
        rescue
          false
        end
      }.count,
      two_faces: Photo.where.not(face_data: nil).select { |p| 
        begin
          data = JSON.parse(p.face_data) rescue nil
          data && data['face_count'] == 2
        rescue
          false
        end
      }.count,
      three_plus: Photo.where.not(face_data: nil).select { |p| 
        begin
          data = JSON.parse(p.face_data) rescue nil
          data && data['face_count'] && data['face_count'] >= 3
        rescue
          false
        end
      }.count
    }
    
    # Daily activity heatmap data
    @daily_heatmap = PhotoSession.visible
      .group_by { |s| [s.started_at.to_date, s.started_at.hour] }
      .transform_values(&:count)
    
    # Session duration analysis (time between first and last photo)
    @session_durations = PhotoSession.visible.map do |session|
      if session.ended_at && session.started_at
        duration = (session.ended_at - session.started_at) / 60.0 # in minutes
        {
          burst_id: session.burst_id,
          duration: duration.round(1)
        }
      end
    end.compact.select { |s| s[:duration] > 0 && s[:duration] < 60 } # filter reasonable durations
    
    # Average session duration
    @avg_duration = @session_durations.any? ? 
      (@session_durations.sum { |s| s[:duration] } / @session_durations.size).round(1) : 0
  end
  
  private
  
  def calculate_storage_usage
    # Estimate based on photo count and average file size
    # Rough estimate: 20MB per Canon photo, 3MB per iPhone photo
    canon_photos = Photo.joins(:photo_session)
      .where("photo_sessions.burst_id LIKE 'burst_%'").count
    iphone_photos = Photo.joins(:photo_session)
      .where("photo_sessions.burst_id LIKE 'iphone_%'").count
    
    ((canon_photos * 20 + iphone_photos * 3) / 1024.0).round(1) # Convert to GB
  end
end