class AddDefaultToRejectedInPhotos < ActiveRecord::Migration[8.0]
  def change
    change_column_default :photos, :rejected, from: nil, to: false
  end
end
