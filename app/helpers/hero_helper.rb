module HeroHelper
  def hero_thumbnail_sources(photo)
    return { default: nil, thumb: nil, face: nil, portrait: nil } unless photo&.image&.attached?

    thumb_url = safe_variant_url(photo) { photo.image.variant(:thumb).url }
    face_url = safe_variant_url(photo) { photo.face_crop_url(size: 320) }
    portrait_url = safe_variant_url(photo) { photo.portrait_crop_url(width: 360, height: 640) }

    face_url ||= thumb_url

    default_url = face_url || thumb_url || safe_variant_url(photo) { photo.image.url }

    {
      default: default_url,
      thumb: thumb_url,
      face: face_url,
      portrait: portrait_url
    }
  end

  private

  def safe_variant_url(photo)
    yield
  rescue => e
    Rails.logger.debug { "Hero thumbnail variant missing for photo ##{photo&.id}: #{e.message}" }
    nil
  end
end
