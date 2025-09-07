class AddHiddenToPhotoSessions < ActiveRecord::Migration[8.0]
  def change
    add_column :photo_sessions, :hidden, :boolean, default: false, null: false
  end
end
