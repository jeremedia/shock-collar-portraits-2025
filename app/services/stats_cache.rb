require "digest"

class StatsCache
  DEFAULT_TTL = 12.hours

  class << self
    def version
      # Compose a version from the most recently updated core records
      times = [ Photo.maximum(:updated_at), PhotoSession.maximum(:updated_at), Sitting.maximum(:updated_at) ].compact
      return "v0" if times.empty?
      Digest::MD5.hexdigest(times.map { |t| t.to_i }.join(":"))
    end

    def summary(version:, force: false)
      fetch("summary", version:, force:) do
        total_sessions = PhotoSession.visible.count
        total_photos   = Photo.count
        total_sittings = Sitting.count
        total_heroes   = Sitting.where.not(hero_photo_id: nil).count
        total_rejected = Photo.where(rejected: true).count
        faces_detected = Photo.where.not(face_data: nil).count
        hero_rate      = total_photos.positive? ? ((total_heroes.to_f / total_photos) * 100).round(1) : 0
        rejection_rate = total_photos.positive? ? ((total_rejected.to_f / total_photos) * 100).round(1) : 0
        canon_sessions = PhotoSession.visible.where("burst_id LIKE 'burst_%'").count
        iphone_sessions = PhotoSession.visible.where("burst_id LIKE 'iphone_%'").count

        # Hero gender distribution
        hero_genders = hero_gender_distribution

        { total_sessions:, total_photos:, total_sittings:, total_heroes:, total_rejected:,
          faces_detected:, hero_rate:, rejection_rate:, canon_sessions:, iphone_sessions:,
          total_storage_gb: estimate_storage_gb, hero_genders: }
      end
    end

    def daily_details(version:, force: false)
      fetch("daily_details", version:, force:) do
        tz = ActiveSupport::TimeZone["Pacific Time (US & Canada)"]
        PhotoSession.visible
          .includes(:photos)
          .group_by { |s| s.started_at.in_time_zone(tz).to_date }
          .transform_values do |sessions|
            total_photos = sessions.sum { |s| s.photos.count }
            {
              count: sessions.size,
              photos: total_photos,
              avg_photos: sessions.size.positive? ? (total_photos.to_f / sessions.size).round(1) : 0
            }
          end
          .sort
          .to_h
      end
    end

    def daily_timelines(version:, force: false, dates: nil)
      dates ||= %w[2025-08-25 2025-08-26 2025-08-27 2025-08-28 2025-08-29].map { |d| Date.parse(d) }
      tz = ActiveSupport::TimeZone["Pacific Time (US & Canada)"]

      fetch("daily_timelines", version:, force:) do
        sessions_by_day = PhotoSession.visible.includes(:photos).group_by { |s| s.started_at.in_time_zone(tz).to_date }

        timelines = {}
        dates.each do |date|
          day_sessions = sessions_by_day[date] || []
          sessions_data = day_sessions.map do |session|
            first_photo_utc = session.photos.map(&:photo_taken_at).compact.min
            pdt_time = (first_photo_utc || session.started_at).in_time_zone(tz)
            {
              time: pdt_time.strftime("%H:%M"),
              hour: pdt_time.hour,
              minute: pdt_time.min,
              photo_count: session.photos.count,
              burst_id: session.burst_id
            }
          end.sort_by { |s| [ s[:hour], s[:minute] ] }

          total_photos = sessions_data.sum { |s| s[:photo_count] }
          avg_photos = sessions_data.any? ? (total_photos.to_f / sessions_data.size).round(1) : 0

          timelines[date.strftime("%Y-%m-%d")] = {
            sessions: sessions_data,
            average: avg_photos,
            total_sessions: sessions_data.size,
            total_photos: total_photos,
            day_name: date.strftime("%A, %B %d")
          }
        end
        timelines
      end
    end

    def photo_distribution(version:, force: false)
      fetch("photo_distribution", version:, force:) do
        PhotoSession.visible
          .joins(:photos)
          .group(:id)
          .count
          .values
          .group_by do |count|
            case count
            when 1..10 then "1-10"
            when 11..20 then "11-20"
            when 21..30 then "21-30"
            when 31..40 then "31-40"
            when 41..50 then "41-50"
            else "50+"
            end
          end
          .transform_values(&:count)
      end
    end

    def top_sessions(version:, force: false, limit: 10)
      fetch("top_sessions", version:, force:) do
        PhotoSession.visible
          .left_joins(:photos)
          .group("photo_sessions.id, photo_sessions.burst_id, photo_sessions.started_at")
          .order("COUNT(photos.id) DESC")
          .limit(limit)
          .pluck("photo_sessions.id", "photo_sessions.burst_id", "photo_sessions.started_at", "COUNT(photos.id)")
          .map { |id, burst_id, started_at, count| { id:, burst_id:, started_at:, count: count.to_i } }
      end
    end

    def face_stats(version:, force: false)
      fetch("face_stats", version:, force:) do
        # Keep Ruby parsing but cache result; heavy work done once per version
        no_faces   = Photo.where(face_data: nil).count
        with_faces = Photo.where.not(face_data: nil)
        one = two = three_plus = 0
        with_faces.find_each(batch_size: 1000) do |p|
          begin
            data = p.face_data.is_a?(String) ? JSON.parse(p.face_data) : p.face_data
            count = data && data["face_count"]
            case count
            when 1 then one += 1
            when 2 then two += 1
            else three_plus += 1 if count && count >= 3
            end
          rescue
          end
        end
        { no_faces:, one_face: one, two_faces: two, three_plus: three_plus }
      end
    end

    def session_durations(version:, force: false)
      fetch("session_durations", version:, force:) do
        list = PhotoSession.visible.map do |session|
          if session.ended_at && session.started_at
            duration = (session.ended_at - session.started_at) / 60.0
            { burst_id: session.burst_id, duration: duration.round(1) }
          end
        end.compact.select { |s| s[:duration] > 0 && s[:duration] < 60 }
        avg = list.any? ? (list.sum { |s| s[:duration] } / list.size).round(1) : 0
        { list:, avg: avg }
      end
    end

    def stats_json(version:, force: false)
      fetch("json", version:, force:) do
        details   = daily_details(version: version, force: false)
        timelines = daily_timelines(version: version, force: false)
        dist      = photo_distribution(version: version, force: false)
        summary   = summary(version: version, force: false)

        data = {
          dailyDetails: details,
          dailySessionTimelines: timelines,
          canonSessions: summary[:canon_sessions],
          iphoneSessions: summary[:iphone_sessions],
          photoDistribution: dist,
          heroGenders: summary[:hero_genders]
        }
        JSON.generate(data)
      end
    end

    private

    def fetch(name, version:, force:, expires_in: DEFAULT_TTL, &block)
      key = cache_key(name, version)
      if force
        Rails.cache.delete(key)
      end
      Rails.cache.fetch(key, expires_in:, race_condition_ttl: 5, &block)
    end

    def cache_key(name, version)
      "stats:v#{version}:#{name}"
    end

    def estimate_storage_gb
      canon_photos = Photo.joins(:photo_session).where("photo_sessions.burst_id LIKE 'burst_%'").count
      iphone_photos = Photo.joins(:photo_session).where("photo_sessions.burst_id LIKE 'iphone_%'").count
      ((canon_photos * 20 + iphone_photos * 3) / 1024.0).round(1)
    end

    def hero_gender_distribution
      # Get all sittings with hero photos and check gender of their sessions
      gender_counts = { male: 0, female: 0, unknown: 0 }

      Sitting.where.not(hero_photo_id: nil).includes(photos: :photo_session).find_each do |sitting|
        # Get the photo session that contains the hero photo
        hero_photo = Photo.find_by(id: sitting.hero_photo_id)
        next unless hero_photo

        session = hero_photo.photo_session
        next unless session

        # Check if the session has gender analysis
        if session.respond_to?(:detected_gender) && session.detected_gender.present?
          gender = session.detected_gender.to_sym
          gender_counts[gender] += 1 if [ :male, :female ].include?(gender)
        else
          gender_counts[:unknown] += 1
        end
      end

      gender_counts
    end
  end
end
