class AddQualityToPhotoSessions < ActiveRecord::Migration[8.0]
  def change
    add_column :photo_sessions, :quality, :string, default: "ok"

    # Set existing sessions to "ok"
    reversible do |dir|
      dir.up do
        PhotoSession.update_all(quality: "ok")
      end
    end
  end
end
