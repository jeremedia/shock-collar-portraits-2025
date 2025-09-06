class PhotoSession < ApplicationRecord
  belongs_to :session_day
  has_many :sittings, dependent: :destroy
  has_many :photos, dependent: :destroy

  scope :with_sittings, -> { joins(:sittings).distinct }
  scope :without_sittings, -> { left_joins(:sittings).where(sittings: { id: nil }) }

  validates :session_number, presence: true
  validates :burst_id, presence: true, uniqueness: true
end
