class CreateSessionDays < ActiveRecord::Migration[8.0]
  def change
    create_table :session_days do |t|
      t.references :burn_event, null: false, foreign_key: true
      t.string :day_name
      t.date :date

      t.timestamps
    end
  end
end
