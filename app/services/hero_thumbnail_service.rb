class HeroThumbnailService
  CACHE_VERSION = "v1".freeze

  class << self
    def sources(photo)
      return default_hash unless photo&.image&.attached?

      key = cache_key(photo)

      cached = Rails.cache.read(key)
      if cached.present?
        return cached if cacheable?(cached)

        Rails.cache.delete(key)
      end

      fresh = build_sources(photo)

      Rails.cache.write(key, fresh) if cacheable?(fresh)

      fresh
    end

    private

    def cache_key(photo)
      [ "hero_thumbnail", CACHE_VERSION, photo.id, photo.updated_at.to_i, photo.image.blob&.checksum ]
    end

    def cacheable?(sources)
      sources[:thumb].present?
    end

    def build_sources(photo)
      thumb = fetch_variant(photo, :thumb)
      face_raw = safe_call { photo.face_crop_url(size: 320) }
      face = face_raw || thumb

      portrait_raw = safe_call { photo.portrait_crop_url(width: 360, height: 640) }
      portrait = portrait_raw || face

      default_url = face || thumb || safe_call { photo.image.url }

      {
        default: default_url,
        thumb: thumb,
        face: face,
        portrait: portrait,
        available: {
          face: face_raw.present?,
          portrait: portrait_raw.present?
        }
      }
    end

    def fetch_variant(photo, name)
      safe_call do
        variant = photo.image.variant(name)
        variant.respond_to?(:processed) ? variant.processed.url : variant.url
      end
    end

    def safe_call
      yield
    rescue => e
      Rails.logger.debug { "Hero thumbnail service failure: #{e.class} - #{e.message}" }
      nil
    end

    def default_hash
      {
        default: nil,
        thumb: nil,
        face: nil,
        portrait: nil,
        available: { face: false, portrait: false }
      }
    end
  end
end
