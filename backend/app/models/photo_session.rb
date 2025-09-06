class PhotoSession < ApplicationRecord
  belongs_to :session_day
  has_many :sittings, dependent: :destroy
  has_many :photos, dependent: :destroy

  scope :with_sittings, -> { joins(:sittings).distinct }
  scope :without_sittings, -> { left_joins(:sittings).where(sittings: { id: nil }) }

  validates :session_number, presence: true
  validates :burst_id, presence: true, uniqueness: true
  
  def split_at_photo(photo_id)
    photo = photos.find(photo_id)
    
    # Don't allow splitting at the first photo
    if photo.position == 1
      errors.add(:base, "Cannot split at the first photo")
      return nil
    end
    
    transaction do
      # Get all photos from the split point onward
      photos_to_move = photos.where("position >= ?", photo.position).order(:position)
      
      if photos_to_move.empty?
        errors.add(:base, "No photos to move")
        return nil
      end
      
      # Generate unique burst_id for new session
      new_burst_id = generate_split_burst_id
      
      # Create new session with same day, incremented session number
      new_session = PhotoSession.create!(
        session_day: session_day,
        session_number: session_number + 1,
        started_at: photos_to_move.first.created_at,
        ended_at: photos_to_move.last.created_at,
        burst_id: new_burst_id,
        source: source,
        photo_count: photos_to_move.count
      )
      
      # Move photos to new session and renumber positions
      photos_to_move.each_with_index do |photo, index|
        photo.update!(
          photo_session: new_session,
          position: index + 1
        )
      end
      
      # Update original session's photo count
      update!(photo_count: photos.reload.count)
      
      # Handle any sittings that might be affected
      # If the hero photo moved to the new session, clear it
      sittings.each do |sitting|
        if sitting.hero_photo && sitting.hero_photo.photo_session_id == new_session.id
          sitting.update!(hero_photo_id: nil)
        end
      end
      
      new_session
    end
  rescue ActiveRecord::RecordInvalid => e
    errors.add(:base, "Failed to split session: #{e.message}")
    nil
  end
  
  private
  
  def generate_split_burst_id
    base_id = burst_id.sub(/-split-\d+$/, '')
    counter = 2
    
    loop do
      new_id = "#{base_id}-split-#{counter}"
      return new_id unless PhotoSession.exists?(burst_id: new_id)
      counter += 1
    end
  end
end
