class StatsController < ApplicationController
  skip_before_action :authenticate_user!
  
  def index
    force = params[:refresh] == '1'
    @stats_version = StatsCache.version

    # Summary counters (+ derived rates)
    summary = StatsCache.summary(version: @stats_version, force: force)
    @total_sessions      = summary[:total_sessions]
    @total_photos        = summary[:total_photos]
    @total_faces_detected = summary[:faces_detected]
    @total_heroes        = summary[:total_heroes]
    @total_rejected      = summary[:total_rejected]
    @total_sittings      = summary[:total_sittings]
    @hero_rate           = summary[:hero_rate]
    @rejection_rate      = summary[:rejection_rate]
    @canon_sessions      = summary[:canon_sessions]
    @iphone_sessions     = summary[:iphone_sessions]
    @total_storage_gb    = summary[:total_storage_gb]
    @avg_photos_per_session = @total_sessions.positive? ? (@total_photos.to_f / @total_sessions.to_f).round(1) : 0

    # Grouped details used by charts
    @daily_details           = StatsCache.daily_details(version: @stats_version, force: force)
    @daily_session_timelines = StatsCache.daily_timelines(version: @stats_version, force: force)
    @photo_distribution      = StatsCache.photo_distribution(version: @stats_version, force: force)
    @top_sessions            = StatsCache.top_sessions(version: @stats_version, force: force)

    durations = StatsCache.session_durations(version: @stats_version, force: force)
    @session_durations = durations[:list]
    @avg_duration      = durations[:avg]

    # Prebuilt JSON for front-end stats (avoids per-request serialization)
    @stats_json = StatsCache.stats_json(version: @stats_version, force: force)

    # HTTP caching for the page shell
    fresh_when(etag: @stats_version, last_modified: [Photo.maximum(:updated_at), PhotoSession.maximum(:updated_at), Sitting.maximum(:updated_at)].compact.max, public: false)
  end
  
  private
  # All heavy computations are cached via StatsCache
end
