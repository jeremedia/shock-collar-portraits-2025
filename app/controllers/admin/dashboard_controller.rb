require 'csv'

class Admin::DashboardController < ApplicationController
  def index
    @stats = {
      total_sessions: PhotoSession.count,
      total_photos: Photo.count,
      total_sittings: Sitting.count,
      sessions_with_sittings: PhotoSession.with_sittings.count,
      sessions_without_sittings: PhotoSession.without_sittings.count
    }
    
    @days = SessionDay.includes(:photo_sessions).order(:date)
    @recent_sittings = Sitting.includes(:photo_session).order(created_at: :desc).limit(10)
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