class CreatePhotos < ActiveRecord::Migration[8.0]
  def change
    create_table :photos do |t|
      t.references :photo_session, null: false, foreign_key: true
      t.references :sitting, null: false, foreign_key: true
      t.string :filename
      t.string :original_path
      t.integer :position
      t.boolean :rejected
      t.text :metadata
      t.text :exif_data

      t.timestamps
    end
  end
end
