class AddHeroPhotoToPhotoSessions < ActiveRecord::Migration[8.0]
  def change
    add_column :photo_sessions, :hero_photo_id, :integer
    add_index :photo_sessions, :hero_photo_id
    add_foreign_key :photo_sessions, :photos, column: :hero_photo_id

    # Migrate existing hero selections from Sitting to PhotoSession
    # Note: Sittings are unreliable - they were a failed attempt to connect
    # people to sessions during the burn. This migration preserves any
    # hero selections that were made but moves them to the proper place.
    reversible do |dir|
      dir.up do
        execute <<~SQL
          UPDATE photo_sessions
          SET hero_photo_id = (
            SELECT hero_photo_id
            FROM sittings
            WHERE sittings.photo_session_id = photo_sessions.id
              AND sittings.hero_photo_id IS NOT NULL
            LIMIT 1
          )
          WHERE EXISTS (
            SELECT 1
            FROM sittings
            WHERE sittings.photo_session_id = photo_sessions.id
              AND sittings.hero_photo_id IS NOT NULL
          )
        SQL
      end
    end
  end
end
