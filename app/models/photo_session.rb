class PhotoSession < ApplicationRecord
  belongs_to :session_day
  has_many :sittings, dependent: :destroy
  has_many :photos, dependent: :destroy

  scope :with_sittings, -> { joins(:sittings).distinct }
  scope :without_sittings, -> { left_joins(:sittings).where(sittings: { id: nil }) }
  scope :visible, -> { where(hidden: false) }
  scope :hidden_sessions, -> { where(hidden: true) }

  validates :session_number, presence: true
  validates :burst_id, presence: true, uniqueness: true
  
  # Merge another session's photos into this session
  # Photos are automatically reordered chronologically by their actual taken time
  # This prevents interleaving when merging sessions taken at different times
  def merge_with(other_session)
    return false if other_session.id == self.id
    
    transaction do
      # Get the max position for continuing numbering
      max_position = photos.maximum(:position) || 0
      
      # CRITICAL: Use update_all to avoid association caching issues
      # This directly updates the database without loading models
      photos_moved = other_session.photos.update_all(
        photo_session_id: self.id,
        updated_at: Time.current
      )
      
      # Reorder all photos chronologically by their actual taken time
      # This prevents interleaving when merging sessions that were taken at different times
      all_photos = photos.reload
      
      # Sort by photo_taken_at (which uses EXIF or calculated time)
      sorted_photos = all_photos.sort_by { |p| [p.photo_taken_at, p.filename] }
      
      # Update positions based on chronological order
      sorted_photos.each_with_index do |photo, index|
        photo.update_columns(position: index)
      end
      
      Rails.logger.info "Reordered #{sorted_photos.length} photos chronologically after merge"
      
      # Update our photo count
      self.update!(photo_count: all_photos.count)
      
      # Update end time to the later of the two
      if other_session.ended_at && (!ended_at || other_session.ended_at > ended_at)
        self.update!(ended_at: other_session.ended_at)
      end
      
      # Merge sittings if any
      other_session.sittings.update_all(photo_session_id: self.id)
      
      # CRITICAL: Verify photos were moved before destroying
      other_session.reload
      if other_session.photos.count > 0
        raise ActiveRecord::Rollback, "Photos were not successfully moved"
      end
      
      # Now safe to destroy the empty session
      other_session.destroy!
      
      photos_moved
    end
  rescue => e
    Rails.logger.error "Failed to merge sessions: #{e.message}"
    false
  end
  
  # Split a session at a specific photo, creating a new session with all photos from that point onward
  # CRITICAL: The new session's started_at MUST use the actual photo taken time (from EXIF or calculated)
  # This ensures split sessions appear in correct chronological order, not at end of day
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
      
      # Create new session with split suffix
      new_burst_id = "#{burst_id}-split-2"
      
      # Ensure unique burst_id
      counter = 2
      while PhotoSession.exists?(burst_id: new_burst_id)
        counter += 1
        new_burst_id = "#{burst_id}-split-#{counter}"
      end
      
      # Create new session with proper timestamp
      # IMPORTANT: Use photo.photo_taken_at which extracts EXIF time (converted to UTC)
      # or falls back to calculated time based on burst timestamp + position
      new_session = PhotoSession.create!(
        burst_id: new_burst_id,
        session_number: session_number,
        session_day: session_day,
        started_at: photo.photo_taken_at,  # Uses actual photo time, not database created_at!
        ended_at: ended_at,
        photo_count: photos_to_move.count,
        source: source,
        hidden: hidden
      )
      
      # Move photos to new session
      photos_to_move.each_with_index do |p, index|
        p.update!(
          photo_session: new_session,
          position: index
        )
      end
      
      # Update new session's ended_at based on last photo's actual taken time
      # This ensures the session time range accurately reflects when photos were taken
      last_moved_photo = photos_to_move.last
      if last_moved_photo
        new_session.update!(ended_at: last_moved_photo.photo_taken_at)
      end
      
      # Update original session's photo count and end time
      # The ended_at must use actual photo time to maintain chronological accuracy
      remaining_photos = photos.reload
      if remaining_photos.any?
        last_photo = remaining_photos.order(:position).last
        update!(
          photo_count: remaining_photos.count,
          ended_at: last_photo.photo_taken_at  # Use actual photo time, not database time
        )
      else
        update!(photo_count: 0)
      end
      
      # Move any sittings to the appropriate session based on hero photo
      sittings.each do |sitting|
        if sitting.hero_photo && sitting.hero_photo.photo_session_id == new_session.id
          sitting.update!(photo_session: new_session)
        end
      end
      
      new_session
    end
  end
end