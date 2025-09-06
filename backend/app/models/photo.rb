class Photo < ApplicationRecord
  belongs_to :photo_session
  belongs_to :sitting, optional: true
  has_one_attached :image do |attachable|
    attachable.variant :thumb, resize_to_limit: [300, 300], format: :webp, saver: { quality: 80 }
    attachable.variant :medium, resize_to_limit: [800, 800], format: :webp, saver: { quality: 85 }
    attachable.variant :large, resize_to_limit: [1600, 1600], format: :webp, saver: { quality: 90 }
    attachable.variant :gallery, resize_to_limit: [1200, 1200], format: :jpeg, saver: { quality: 85 }
  end

  scope :not_rejected, -> { where(rejected: false) }
  scope :heroes, -> { joins("INNER JOIN sittings ON sittings.hero_photo_id = photos.id") }

  # Rails 8 uses coder instead of second argument for serialize
  serialize :metadata, coder: JSON
  serialize :exif_data, coder: JSON

  validates :filename, presence: true
  
  def image_url(variant = nil)
    return nil unless image.attached?
    
    if variant
      # Rails 8 syntax - directly access named variant
      image.variant(variant).url
    else
      image.url
    end
  end
end
