class AddGenderAnalysisToPhotoSessions < ActiveRecord::Migration[8.0]
  def change
    add_column :photo_sessions, :gender_analysis, :text
    add_column :photo_sessions, :gender_analyzed_at, :datetime

    # Add index for filtering
    add_index :photo_sessions, :gender_analyzed_at

    # Remove from photos table since we're moving to session level
    remove_column :photos, :gender_analysis, :text if column_exists?(:photos, :gender_analysis)
    remove_column :photos, :gender_analyzed_at, :datetime if column_exists?(:photos, :gender_analyzed_at)
  end
end
