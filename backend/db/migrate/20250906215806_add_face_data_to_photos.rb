class AddFaceDataToPhotos < ActiveRecord::Migration[8.0]
  def change
    add_column :photos, :face_data, :jsonb, default: nil
    add_index :photos, :face_data, using: :gin
    add_column :photos, :face_detected_at, :datetime
  end
end
