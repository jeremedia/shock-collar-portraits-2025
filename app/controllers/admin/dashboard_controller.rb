require 'csv'

class Admin::DashboardController < ApplicationController
  before_action :require_admin!
  def index
    @stats = {
      total_sessions: PhotoSession.count,
      total_photos: Photo.count,
      total_sittings: Sitting.count,
      sessions_with_sittings: PhotoSession.with_sittings.count,
      sessions_without_sittings: PhotoSession.without_sittings.count
    }
    @stats_version = StatsCache.version
    @stats_last_updated = [Photo.maximum(:updated_at), PhotoSession.maximum(:updated_at), Sitting.maximum(:updated_at)].compact.max

    # Visitor stats
    @visitor_stats = {
      total_visits: Ahoy::Visit.count,
      total_unique_visitors: Ahoy::Visit.distinct.count(:visitor_token),
      visits_today: Ahoy::Visit.where("started_at >= ?", Time.current.beginning_of_day).count,
      visits_this_week: Ahoy::Visit.where("started_at >= ?", 1.week.ago).count,
      logged_in_visitors: Ahoy::Visit.where.not(user_id: nil).distinct.count(:user_id),
      recent_visits: Ahoy::Visit.includes(:user).order(started_at: :desc).limit(10)
    }

    # Most viewed pages
    @popular_pages = Ahoy::Event.where(name: "gallery#show")
                                .group(:properties)
                                .order(count_all: :desc)
                                .limit(5)
                                .count

    @days = SessionDay.includes(:photo_sessions).order(:date)
    @recent_sittings = Sitting.includes(:photo_session).order(created_at: :desc).limit(10)
  end

  # POST /admin/warm_stats_cache
  def warm_stats_cache
    StatsWarmCacheJob.perform_later
    flash[:notice] = "Stats cache warm job enqueued"
    redirect_to admin_dashboard_path
  end
  
  def sessions
    @sessions = PhotoSession.includes(:session_day, :sittings)
                           .order('session_days.date ASC, photo_sessions.started_at ASC')
  end
  
  def sittings
    @sittings = Sitting.includes(:photo_session, :hero_photo)
                       .order(created_at: :desc)
  end
  
  def export_emails
    @sittings = Sitting.includes(:photo_session).order(:id)
    
    respond_to do |format|
      format.csv do
        csv_data = CSV.generate(headers: true) do |csv|
          csv << ['Session Number', 'Name', 'Email', 'Notes', 'Day', 'Created At']
          @sittings.each do |sitting|
            csv << [
              sitting.photo_session.session_number,
              sitting.name,
              sitting.email,
              sitting.notes,
              sitting.photo_session.session_day.day_name,
              sitting.created_at.strftime('%Y-%m-%d %H:%M')
            ]
          end
        end
        
        send_data csv_data, filename: "oknotok_emails_#{Date.today}.csv"
      end
    end
  end
end
