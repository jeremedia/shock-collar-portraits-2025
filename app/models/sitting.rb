# WARNING: UNRELIABLE MODEL - DO NOT USE FOR SESSION DATA
# Sittings were a failed attempt during Burning Man to connect people to their sessions.
# Due to the chaos of the event, NO sitting is correctly connected to a session.
# This model is only kept for email storage purposes.
# Hero photo selection has been moved to PhotoSession.hero_photo_id
class Sitting < ApplicationRecord
  belongs_to :photo_session
  belongs_to :hero_photo, class_name: 'Photo', optional: true  # DEPRECATED - use PhotoSession.hero_photo_id
  has_many :photos, dependent: :destroy

  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
end
