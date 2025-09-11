namespace :emails do
  desc "Import emails from CSV and create placeholder sessions for unmatched emails"
  task import_csv: :environment do
    require 'csv'
    
    csv_path = '/Users/jeremy/Desktop/OK-SHOCK-25/Shock Collar Portraits 2025 Emails/shock_collar_emails.csv'
    
    unless File.exist?(csv_path)
      puts "CSV file not found at: #{csv_path}"
      exit 1
    end
    
    # Create or find placeholder sessions for each day
    placeholder_sessions = {}
    
    # Map day names to dates (August 25-29, 2025)
    day_to_date = {
      'Monday'    => Date.parse('2025-08-25'),
      'Tuesday'   => Date.parse('2025-08-26'),
      'Wednesday' => Date.parse('2025-08-27'),
      'Thursday'  => Date.parse('2025-08-28'),
      'Friday'    => Date.parse('2025-08-29')
    }
    
    puts "Creating placeholder sessions for unmatched emails..."
    
    day_to_date.each do |day_name, date|
      # Find or create session day
      session_day = SessionDay.find_or_create_by!(date: date) do |sd|
        sd.burn_event_id = BurnEvent.first_or_create!(
          name: 'Burning Man 2025',
          year: 2025
        ).id
        sd.day_name = day_name
      end
      
      # Create placeholder session for this day
      burst_id = "placeholder_#{day_name.downcase}_emails"
      
      placeholder_session = PhotoSession.find_or_create_by!(burst_id: burst_id) do |ps|
        ps.session_day = session_day
        ps.session_number = 999000 + date.wday  # High number to avoid conflicts
        ps.started_at = date.to_time + 15.hours + 7.hours  # 3pm PST in UTC
        ps.ended_at = date.to_time + 17.hours + 7.hours    # 5pm PST in UTC
        ps.photo_count = 0
        ps.source = 'email_collection'
        ps.hidden = true  # Hide these placeholder sessions from gallery
      end
      
      placeholder_sessions[day_name] = placeholder_session
      puts "  Created/found placeholder session for #{day_name}: #{burst_id}"
    end
    
    # Import emails from CSV
    imported_count = 0
    duplicate_count = 0
    error_count = 0
    
    puts "\nImporting emails from CSV..."
    
    CSV.foreach(csv_path, headers: true) do |row|
      email = row['email']&.strip&.downcase
      day = row['day']&.strip
      
      next unless email.present? && day.present?
      
      # Check if email already exists in sittings
      if Sitting.exists?(email: email)
        duplicate_count += 1
        puts "  Skipping duplicate: #{email}"
        next
      end
      
      # Get the placeholder session for this day
      session = placeholder_sessions[day]
      
      unless session
        puts "  ERROR: No placeholder session for day '#{day}' (email: #{email})"
        error_count += 1
        next
      end
      
      # Create sitting with email
      sitting = session.sittings.build(
        email: email,
        name: nil,  # No name data in CSV
        notes: "Imported from CSV collection on #{day}",
        position: session.sittings.count + 1
      )
      
      if sitting.save
        imported_count += 1
        print "."  # Progress indicator
      else
        error_count += 1
        puts "\n  ERROR saving #{email}: #{sitting.errors.full_messages.join(', ')}"
      end
    end
    
    puts "\n\nImport complete!"
    puts "  Imported: #{imported_count}"
    puts "  Duplicates skipped: #{duplicate_count}"
    puts "  Errors: #{error_count}"
    
    # Show total email counts
    total_sittings = Sitting.count
    unique_emails = Sitting.pluck(:email).compact.uniq.count
    
    puts "\nTotal sittings in database: #{total_sittings}"
    puts "Unique email addresses: #{unique_emails}"
  end
  
  desc "Create bulk invitations for all collected emails"
  task bulk_invite: :environment do
    # Get all unique emails from sittings
    all_emails = Sitting.pluck(:email).compact.map(&:downcase).uniq
    
    # Remove emails that already have user accounts
    existing_users = User.pluck(:email).map(&:downcase)
    emails_to_invite = all_emails - existing_users
    
    puts "Found #{all_emails.count} total unique emails"
    puts "#{existing_users.count} already have accounts"
    puts "#{emails_to_invite.count} need invitations"
    
    if emails_to_invite.empty?
      puts "No new invitations needed!"
      return
    end
    
    print "\nDo you want to send invitations to #{emails_to_invite.count} emails? (yes/no): "
    response = STDIN.gets.chomp.downcase
    
    unless response == 'yes' || response == 'y'
      puts "Aborted."
      return
    end
    
    # Get admin user to send invitations from
    admin = User.find_by(email: 'j@zinod.com')
    unless admin
      puts "Admin user not found! Please ensure j@zinod.com exists."
      return
    end
    
    invited_count = 0
    error_count = 0
    
    puts "\nSending invitations..."
    
    emails_to_invite.each do |email|
      begin
        # Create user invitation
        user = User.invite!(
          { email: email },
          admin  # Invited by admin
        )
        
        if user.persisted?
          invited_count += 1
          print "."  # Progress indicator
        else
          error_count += 1
          puts "\n  ERROR inviting #{email}: #{user.errors.full_messages.join(', ')}"
        end
      rescue => e
        error_count += 1
        puts "\n  ERROR inviting #{email}: #{e.message}"
      end
    end
    
    puts "\n\nInvitations sent!"
    puts "  Successfully invited: #{invited_count}"
    puts "  Errors: #{error_count}"
    
    # Show invitation stats
    total_users = User.count
    pending_invitations = User.invitation_not_accepted.count
    
    puts "\nTotal users: #{total_users}"
    puts "Pending invitations: #{pending_invitations}"
  end
  
  desc "List all collected emails with their source"
  task list: :environment do
    puts "\nAll collected emails:\n"
    puts "=" * 60
    
    # Group sittings by email
    sittings_by_email = Sitting.includes(:photo_session).group_by(&:email)
    
    sittings_by_email.sort_by { |email, _| email || '' }.each do |email, sittings|
      sitting = sittings.first
      session = sitting.photo_session
      
      # Check if user exists
      user_status = User.exists?(email: email) ? ' [HAS ACCOUNT]' : ''
      
      # Determine source
      source = if session.burst_id.start_with?('placeholder_')
                 "CSV import (#{session.burst_id.split('_')[1].capitalize})"
               else
                 "Session #{session.session_number} (#{session.burst_id})"
               end
      
      puts "#{email}#{user_status}"
      puts "  Source: #{source}"
      puts "  Created: #{sitting.created_at.strftime('%Y-%m-%d %H:%M')}"
      puts ""
    end
    
    puts "=" * 60
    puts "Total unique emails: #{sittings_by_email.count}"
    puts "With accounts: #{sittings_by_email.count { |email, _| User.exists?(email: email) }}"
  end
end