class StatsWarmCacheJob < ApplicationJob
  queue_as :default

  def perform(dates: nil)
    version = StatsCache.version
    # Prime all caches
    StatsCache.summary(version: version, force: true)
    StatsCache.daily_details(version: version, force: true)
    StatsCache.daily_timelines(version: version, force: true, dates: normalized_dates(dates))
    StatsCache.photo_distribution(version: version, force: true)
    StatsCache.top_sessions(version: version, force: true)
    StatsCache.face_stats(version: version, force: true)
    StatsCache.session_durations(version: version, force: true)
    StatsCache.stats_json(version: version, force: true)
  end

  private

  def normalized_dates(dates)
    return nil unless dates
    dates.map { |d| d.is_a?(Date) ? d : Date.parse(d.to_s) }
  end
end
