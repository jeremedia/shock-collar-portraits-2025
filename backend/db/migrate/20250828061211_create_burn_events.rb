class CreateBurnEvents < ActiveRecord::Migration[8.0]
  def change
    create_table :burn_events do |t|
      t.string :theme
      t.integer :year
      t.string :location

      t.timestamps
    end
  end
end
