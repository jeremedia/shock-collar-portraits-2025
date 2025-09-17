require 'digest'

class GalleryCache
  DEFAULT_TTL = 12.hours
  ORDERED_DAY_NAMES = %w[monday tuesday wednesday thursday friday].freeze

  class << self
    def version
      timestamps = [
        Photo.maximum(:updated_at),
        PhotoSession.maximum(:updated_at),
        SessionDay.maximum(:updated_at)
      ].compact

      return 'v0' if timestamps.empty?

      Digest::MD5.hexdigest(timestamps.map { |timestamp| timestamp.to_i }.join(':'))
    end

    def last_modified
      [
        Photo.maximum(:updated_at),
        PhotoSession.maximum(:updated_at),
        SessionDay.maximum(:updated_at)
      ].compact.max
    end

    def index_payload(version:, hide_heroes:, force: false)
      fetch('index_payload', version:, hide_heroes:, force:) do
        sessions_scope = PhotoSession.visible
                                     .joins(:session_day)
                                     .includes(:session_day)
                                     .order('session_days.date ASC, photo_sessions.started_at ASC')
        sessions_scope = sessions_scope.where(hero_photo_id: nil) if hide_heroes

        sessions = sessions_scope.to_a
        session_ids = sessions.map(&:id)

        raw_sessions_by_day = sessions.group_by { |session| session.session_day.day_name }
        ordered_day_names = ORDERED_DAY_NAMES + (raw_sessions_by_day.keys - ORDERED_DAY_NAMES)
        session_ids_by_day = ordered_day_names.each_with_object({}) do |day_name, memo|
          memo[day_name] = (raw_sessions_by_day[day_name] || []).map(&:id)
        end

        face_counts = if session_ids.empty?
                        {}
                      else
                        Photo.where(photo_session_id: session_ids)
                             .where.not(face_data: nil)
                             .group(:photo_session_id)
                             .count
                      end

        sessions_without_heroes = sessions.select { |session| session.hero_photo_id.nil? }
        middle_photo_ids = build_middle_photo_ids(sessions_without_heroes)

        stats = build_stats(sessions, raw_sessions_by_day)

        {
          session_ids_by_day: session_ids_by_day,
          session_ids: session_ids,
          face_counts: face_counts,
          middle_photo_ids: middle_photo_ids,
          stats: stats
        }
      end
    end

    private

    def fetch(name, version:, hide_heroes:, force:, expires_in: DEFAULT_TTL)
      key = cache_key(name, version, hide_heroes)
      Rails.cache.delete(key) if force
      Rails.cache.fetch(key, expires_in:, race_condition_ttl: 5) { yield }
    end

    def cache_key(name, version, hide_heroes)
      hero_segment = hide_heroes ? 'hide' : 'all'
      "gallery:v#{version}:#{name}:#{hero_segment}"
    end

    def build_middle_photo_ids(sessions_without_heroes)
      return {} if sessions_without_heroes.empty?

      session_ids = sessions_without_heroes.map(&:id)
      photos_by_session = Photo.where(photo_session_id: session_ids)
                               .select(:id, :photo_session_id, :position)
                               .order(:photo_session_id, :position)
                               .group_by(&:photo_session_id)

      sessions_without_heroes.each_with_object({}) do |session, memo|
        photos = photos_by_session[session.id] || []
        next if photos.empty?

        middle_position = session.photo_count.to_i / 2
        middle_photo = photos.find { |photo| photo.position == middle_position }
        middle_photo ||= photos.first

        memo[session.id] = middle_photo.id if middle_photo
      end
    end

    def build_stats(sessions, raw_sessions_by_day)
      {
        total_sessions: sessions.size,
        total_photos: sessions.sum { |session| session.photo_count.to_i },
        by_day: raw_sessions_by_day.transform_values(&:size)
      }
    end
  end
end
