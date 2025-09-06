class CreatePhotoSessions < ActiveRecord::Migration[8.0]
  def change
    create_table :photo_sessions do |t|
      t.references :session_day, null: false, foreign_key: true
      t.integer :session_number
      t.datetime :started_at
      t.datetime :ended_at
      t.string :burst_id
      t.string :source
      t.integer :photo_count

      t.timestamps
    end
  end
end
