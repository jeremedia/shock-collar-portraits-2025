module HeroHelper
  def hero_thumbnail_sources(photo)
    HeroThumbnailService.sources(photo)
  end
end
