class SessionDay < ApplicationRecord
  belongs_to :burn_event
  has_many :photo_sessions, dependent: :destroy

  validates :day_name, presence: true
end
