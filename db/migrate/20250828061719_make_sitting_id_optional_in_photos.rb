class MakeSittingIdOptionalInPhotos < ActiveRecord::Migration[8.0]
  def change
    change_column_null :photos, :sitting_id, true
  end
end
