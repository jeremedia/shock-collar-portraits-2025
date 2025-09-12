class Sitting < ApplicationRecord
  belongs_to :photo_session
  belongs_to :hero_photo, class_name: 'Photo', optional: true
  has_many :photos, dependent: :destroy

  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
end
