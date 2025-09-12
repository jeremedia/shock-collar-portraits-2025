# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

# Create default admin user
admin_email = 'j@zinod.com'
admin_password = 'cheese28'

admin = User.find_or_initialize_by(email: admin_email)
admin.password = admin_password
admin.password_confirmation = admin_password
admin.admin = true
admin.name = 'Jeremy'
admin.skip_invitation = true # Skip invitation process for admin
admin.save!

puts "Default admin user created/updated:"
puts "  Email: #{admin_email}"
puts "  Password: [hidden]"
puts "  Admin: true"
