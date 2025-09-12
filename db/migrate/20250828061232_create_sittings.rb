class CreateSittings < ActiveRecord::Migration[8.0]
  def change
    create_table :sittings do |t|
      t.references :photo_session, null: false, foreign_key: true
      t.string :name
      t.string :email
      t.integer :position
      t.integer :hero_photo_id
      t.integer :shock_intensity
      t.text :notes

      t.timestamps
    end
  end
end
