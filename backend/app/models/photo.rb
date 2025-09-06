class Photo < ApplicationRecord
  belongs_to :photo_session
  belongs_to :sitting, optional: true
  has_one_attached :image

  scope :not_rejected, -> { where(rejected: false) }
  scope :heroes, -> { joins("INNER JOIN sittings ON sittings.hero_photo_id = photos.id") }

  # Rails 8 uses coder instead of second argument for serialize
  serialize :metadata, coder: JSON
  serialize :exif_data, coder: JSON

  validates :filename, presence: true
end
