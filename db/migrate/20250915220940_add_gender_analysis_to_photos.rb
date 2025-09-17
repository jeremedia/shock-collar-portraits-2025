class AddGenderAnalysisToPhotos < ActiveRecord::Migration[8.0]
  def change
    add_column :photos, :gender_analysis, :text
    add_column :photos, :gender_analyzed_at, :datetime

    # Add index for filtering by gender
    add_index :photos, :gender_analyzed_at
  end
end
