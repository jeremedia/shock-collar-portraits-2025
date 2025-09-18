class AddPortraitCropDataToPhotos < ActiveRecord::Migration[7.1]
  def change
    add_column :photos, :portrait_crop_data, :jsonb
    add_index :photos, :portrait_crop_data
  end
end
