class Admin::VisitsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin!

  def index
    @current_time = Time.current

    # Current visitors (active in last 5 minutes)
    @active_visitors = Ahoy::Visit.includes(:user, :events)
      .where("started_at > ?", 5.minutes.ago)
      .order(started_at: :desc)

    # Recent activity feed (last 100 events)
    @recent_events = Ahoy::Event.includes(:visit, :user)
      .where("time > ?", 24.hours.ago)
      .order(time: :desc)
      .limit(100)

    # Most viewed photos today
    @popular_photos_today = get_popular_photos(since: 24.hours.ago, limit: 10)

    # Most viewed photos all time
    @popular_photos_all_time = get_popular_photos(limit: 10)

    # Most active visitors
    @top_visitors = User.joins(:visits)
      .select("users.*, COUNT(DISTINCT ahoy_visits.id) as visit_count, MAX(ahoy_visits.started_at) as last_seen")
      .group("users.id")
      .order("visit_count DESC")
      .limit(20)

    # Geographic distribution
    @visitor_locations = Ahoy::Visit
      .where.not(city: [nil, ""])
      .group(:city, :region, :country)
      .count
      .sort_by { |_, count| -count }
      .first(20)

    # Device breakdown
    @devices = Ahoy::Visit.group(:device_type).count
    @browsers = Ahoy::Visit.group(:browser).count
    @operating_systems = Ahoy::Visit.group(:os).count

    # Activity heatmap data (by hour and day of week)
    @activity_heatmap = build_activity_heatmap

    # Return visitor stats
    @visitor_stats = calculate_visitor_stats

    # Session depth analysis
    @session_depths = analyze_session_depths

    # Photo journey paths
    @common_paths = analyze_common_paths

    # Engagement metrics
    @engagement = calculate_engagement_metrics

    # Real-time ticker of events
    @live_events = Ahoy::Event
      .includes(:visit, :user)
      .where("time > ?", 1.hour.ago)
      .order(time: :desc)
      .limit(50)
  end

  def visitor_detail
    @visitor = User.find(params[:id])
    @visits = @visitor.visits.includes(:events).order(started_at: :desc)

    # Get all photos this visitor has viewed
    photo_views = Ahoy::Event.joins(:visit)
      .where(visits: { user_id: @visitor.id })
      .where(name: ["Viewed photo", "Photo view", "$view"])
      .where("properties LIKE ?", "%photo_id%")

    photo_ids = photo_views.map { |e| extract_photo_id(e.properties) }.compact.uniq
    @viewed_photos = Photo.where(id: photo_ids).includes(:sitting, :photo_session)

    # Calculate visitor statistics
    @visitor_stats = {
      total_visits: @visits.count,
      total_photos_viewed: photo_ids.count,
      favorite_session: calculate_favorite_session(@visitor),
      total_time_spent: calculate_total_time(@visits),
      average_session_duration: calculate_average_duration(@visits),
      first_visit: @visits.minimum(:started_at),
      last_visit: @visits.maximum(:started_at),
      devices_used: @visits.pluck(:device_type).uniq.compact,
      locations: @visits.map { |v| [v.city, v.region, v.country].compact.join(", ") }.uniq
    }

    render partial: "visitor_detail", locals: { visitor: @visitor, stats: @visitor_stats }
  end

  private

  def get_popular_photos(since: nil, limit: 10)
    query = Ahoy::Event.where(name: ["Viewed photo", "Photo view", "$view"])
    query = query.where("time > ?", since) if since

    photo_counts = {}
    query.find_each do |event|
      photo_id = extract_photo_id(event.properties)
      next unless photo_id
      photo_counts[photo_id] ||= 0
      photo_counts[photo_id] += 1
    end

    photo_ids = photo_counts.sort_by { |_, count| -count }.first(limit).map(&:first)
    photos = Photo.where(id: photo_ids).includes(:sitting, :photo_session).index_by(&:id)

    photo_ids.map { |id| [photos[id], photo_counts[id]] if photos[id] }.compact
  end

  def extract_photo_id(properties)
    return nil unless properties
    data = properties.is_a?(String) ? JSON.parse(properties) : properties
    data["photo_id"] || data["id"]
  rescue
    nil
  end

  def build_activity_heatmap
    # Build a 7x24 grid of activity (days x hours)
    heatmap = Array.new(7) { Array.new(24, 0) }

    Ahoy::Event.where("time > ?", 7.days.ago).find_each do |event|
      day = event.time.wday
      hour = event.time.hour
      heatmap[day][hour] += 1
    end

    heatmap
  end

  def calculate_visitor_stats
    total_visitors = User.joins(:visits).distinct.count
    returning_visitors = User.joins(:visits)
      .group("users.id")
      .having("COUNT(DISTINCT ahoy_visits.id) > 1")
      .count.keys.count

    {
      total: total_visitors,
      returning: returning_visitors,
      new: total_visitors - returning_visitors,
      return_rate: total_visitors > 0 ? (returning_visitors * 100.0 / total_visitors).round(1) : 0
    }
  end

  def analyze_session_depths
    depths = {}

    Ahoy::Visit.includes(:events).find_each do |visit|
      photo_events = visit.events.where(name: ["Viewed photo", "Photo view", "$view"]).count
      bucket = case photo_events
        when 0 then "0 photos"
        when 1 then "1 photo"
        when 2..5 then "2-5 photos"
        when 6..10 then "6-10 photos"
        when 11..20 then "11-20 photos"
        when 21..50 then "21-50 photos"
        else "50+ photos"
      end
      depths[bucket] ||= 0
      depths[bucket] += 1
    end

    depths
  end

  def analyze_common_paths
    paths = []

    # Sample recent visits with enough events
    recent_visits = Ahoy::Visit.includes(:events)
      .where("started_at > ?", 7.days.ago)
      .select { |v| v.events.count > 3 }
      .first(50)

    recent_visits.each do |visit|
      photo_events = visit.events
        .where(name: ["Viewed photo", "Photo view", "$view"])
        .order(:time)
        .limit(5)

      if photo_events.count >= 3
        path = photo_events.map { |e| extract_photo_id(e.properties) }.compact
        paths << path if path.length >= 3
      end
    end

    # Find common sequences
    path_counts = {}
    paths.each do |path|
      key = path.join(" → ")
      path_counts[key] ||= 0
      path_counts[key] += 1
    end

    path_counts.sort_by { |_, count| -count }.first(5)
  end

  def calculate_engagement_metrics
    total_events = Ahoy::Event.count
    total_visits = Ahoy::Visit.count

    {
      avg_events_per_visit: total_visits > 0 ? (total_events.to_f / total_visits).round(1) : 0,
      bounce_rate: calculate_bounce_rate,
      avg_time_on_site: calculate_avg_time_on_site,
      pages_per_session: calculate_pages_per_session
    }
  end

  def calculate_bounce_rate
    total = Ahoy::Visit.count
    bounced = Ahoy::Visit.joins(:events)
      .group("ahoy_visits.id")
      .having("COUNT(ahoy_events.id) <= 1")
      .count.keys.count

    total > 0 ? (bounced * 100.0 / total).round(1) : 0
  end

  def calculate_avg_time_on_site
    durations = []

    Ahoy::Visit.includes(:events).find_each do |visit|
      if visit.events.any?
        duration = visit.events.maximum(:time) - visit.started_at
        durations << duration if duration > 0 && duration < 1.day
      end
    end

    return 0 if durations.empty?
    (durations.sum / durations.count).round
  end

  def calculate_pages_per_session
    counts = Ahoy::Visit.joins(:events)
      .where(events: { name: ["Viewed photo", "Photo view", "$view"] })
      .group("ahoy_visits.id")
      .count.values

    return 0 if counts.empty?
    (counts.sum.to_f / counts.count).round(1)
  end

  def calculate_favorite_session(user)
    session_views = {}

    user.events.where(name: ["Viewed photo", "Photo view", "$view"]).find_each do |event|
      photo_id = extract_photo_id(event.properties)
      next unless photo_id

      photo = Photo.find_by(id: photo_id)
      next unless photo && photo.photo_session

      session_views[photo.photo_session_id] ||= 0
      session_views[photo.photo_session_id] += 1
    end

    return nil if session_views.empty?

    session_id = session_views.max_by { |_, count| count }.first
    PhotoSession.find_by(id: session_id)
  end

  def calculate_total_time(visits)
    total = 0
    visits.each do |visit|
      if visit.events.any?
        duration = visit.events.maximum(:time) - visit.started_at
        total += duration if duration > 0 && duration < 1.day
      end
    end
    total
  end

  def calculate_average_duration(visits)
    return 0 if visits.empty?
    calculate_total_time(visits) / visits.count
  end

  def require_admin!
    unless current_user.admin?
      flash[:alert] = "Admin access required"
      redirect_to root_path
    end
  end
end