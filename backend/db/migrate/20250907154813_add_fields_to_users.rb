class AddFieldsToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :admin, :boolean, default: false
    add_column :users, :name, :string
    add_index :users, :admin
  end
end
