namespace :oknotok do
  desc "Send test invitations to OKNOTOK team members with production URL"
  task team_invite: :environment do
    # OKNOTOK team emails
    team_emails = [
      'lightningcarpentry@gmail.com',
      'abby.hinote@gmail.com',
      'ejnote@gmail.com',
      'mack@mackreed.co',
      'mzanti123@gmail.com',
      'mo@oknotok.com',
      'paychyi@gmail.com',
      'susannahtace@yahoo.com'
    ]

    # Temporarily set production URL for these invitations
    original_host = Rails.application.config.action_mailer.default_url_options[:host]
    Rails.application.config.action_mailer.default_url_options[:host] = 'scp-2025.oknotok.com'
    Rails.application.config.action_mailer.default_url_options[:protocol] = 'https'

    puts "\n==================================="
    puts "OKNOTOK TEAM TEST INVITATIONS"
    puts "==================================="
    puts "Sending to #{team_emails.count} team members"
    puts "Using production URL: https://scp-2025.oknotok.com"
    puts "===================================\n\n"

    # Get the superadmin to be the inviter
    inviter = User.find_by(superadmin: true) || User.find_by(admin: true)

    unless inviter
      puts "❌ ERROR: No admin user found to send invitations from!"
      Rails.application.config.action_mailer.default_url_options[:host] = original_host
      return
    end

    puts "Sending invitations as: #{inviter.email}\n\n"

    sent = 0
    already_exists = 0
    failed = 0

    team_emails.each do |email|
      # Check if user already exists
      existing_user = User.find_by(email: email.downcase)

      if existing_user
        if existing_user.invitation_accepted_at || existing_user.encrypted_password.present?
          puts "⏭️  SKIPPED: #{email} (already has account)"
          already_exists += 1
        else
          # Resend invitation
          puts "📤 RESENDING: #{email} (pending invitation)"
          existing_user.invite!(inviter)
          sent += 1
        end
      else
        # Find name from Sitting if exists
        sitting = Sitting.find_by(email: email.downcase)
        name = sitting&.name

        begin
          # Create new invitation
          user = User.invite!(
            {
              email: email,
              name: name,
              admin: false  # Regular users for testing
            },
            inviter
          )

          if user.persisted?
            sent += 1
            puts "✅ INVITED: #{email} (#{name || 'no name'})"
          else
            failed += 1
            puts "❌ FAILED: #{email} - #{user.errors.full_messages.join(', ')}"
          end
        rescue => e
          failed += 1
          puts "❌ ERROR: #{email} - #{e.message}"
        end
      end

      # Small delay to avoid rate limiting
      sleep(1)
    end

    # Restore original host
    Rails.application.config.action_mailer.default_url_options[:host] = original_host

    puts "\n==================================="
    puts "TEAM INVITATIONS COMPLETE"
    puts "==================================="
    puts "✅ Sent/Resent: #{sent}"
    puts "⏭️  Already have accounts: #{already_exists}"
    puts "❌ Failed: #{failed}"
    puts "==================================="
    puts "\nTeam members should check their email for invitations."
    puts "URLs will direct to: https://scp-2025.oknotok.com"
  end

  desc "Check OKNOTOK team member account status"
  task team_status: :environment do
    team_emails = [
      'lightningcarpentry@gmail.com',
      'abby.hinote@gmail.com',
      'ejnote@gmail.com',
      'mack@mackreed.co',
      'mzanti123@gmail.com',
      'mo@oknotok.com',
      'paychyi@gmail.com',
      'susannahtace@yahoo.com'
    ]

    puts "\n==================================="
    puts "OKNOTOK TEAM STATUS"
    puts "==================================="

    team_emails.each do |email|
      user = User.find_by(email: email.downcase)
      sitting = Sitting.find_by(email: email.downcase)

      status = if user
        if user.invitation_accepted_at || user.encrypted_password.present?
          "✅ Active account"
        else
          "⏳ Invitation pending (sent #{time_ago_in_words(user.invitation_sent_at)} ago)"
        end
      else
        "❌ No account"
      end

      name = user&.name || sitting&.name || "no name"
      puts "#{email} (#{name}): #{status}"
    end

    puts "==================================="
  end
end