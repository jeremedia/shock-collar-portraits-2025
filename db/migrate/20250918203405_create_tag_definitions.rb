class CreateTagDefinitions < ActiveRecord::Migration[8.0]
  def change
    create_table :tag_definitions do |t|
      t.string :name, null: false
      t.string :category, null: false
      t.string :display_name
      t.string :emoji
      t.integer :display_order, default: 0, null: false
      t.boolean :active, default: true, null: false
      t.string :color
      t.text :description

      t.timestamps
    end

    add_index :tag_definitions, :name, unique: true
    add_index :tag_definitions, :category
    add_index :tag_definitions, [:category, :display_order]
    add_index :tag_definitions, :active
  end
end
