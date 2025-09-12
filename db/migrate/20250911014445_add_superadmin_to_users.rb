class AddSuperadminToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :superadmin, :boolean, default: false, null: false
    
    # Set j@zinod.com as superadmin
    reversible do |dir|
      dir.up do
        execute "UPDATE users SET superadmin = true WHERE email = 'j@zinod.com'"
      end
    end
  end
end
