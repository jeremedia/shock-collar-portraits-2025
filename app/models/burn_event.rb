class BurnEvent < ApplicationRecord
  has_many :session_days, dependent: :destroy
  has_many :photo_sessions, through: :session_days

  validates :theme, presence: true
  validates :year, presence: true, numericality: { greater_than: 1900, less_than_or_equal_to: 2100 }
end
