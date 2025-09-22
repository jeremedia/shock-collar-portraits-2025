namespace :devise do
  desc "Bulk send Devise invitations to all sitting emails (Gmail-safe)"
  task bulk_invite: :environment do
    # Gmail-safe configuration
    EMAILS_PER_MINUTE = 6  # Conservative: 1 every 10 seconds
    DAILY_LIMIT = 200      # Stay well under Gmail's 500 limit
    DELAY_SECONDS = 10     # 10 seconds between emails

    puts "\n==================================="
    puts "DEVISE INVITATION BULK SENDER"
    puts "==================================="
    puts "This will create user accounts for all portrait participants"
    puts "Gmail-Safe Settings:"
    puts "  • Rate: #{EMAILS_PER_MINUTE} emails/minute"
    puts "  • Delay: #{DELAY_SECONDS} seconds between emails"
    puts "  • Daily limit: #{DAILY_LIMIT} emails"
    puts "===================================\n\n"

    # Get all unique emails from sittings
    sitting_emails = Sitting.where.not(email: [ nil, "" ])
                            .distinct
                            .pluck(:email, :name)
                            .map { |email, name| { email: email.downcase.strip, name: name } }

    # Remove emails that already have user accounts
    existing_emails = User.pluck(:email).map(&:downcase)
    new_emails = sitting_emails.reject { |s| existing_emails.include?(s[:email].downcase) }

    puts "📊 Email Statistics:"
    puts "  • Total sitting emails: #{sitting_emails.count}"
    puts "  • Already have accounts: #{sitting_emails.count - new_emails.count}"
    puts "  • Need invitations: #{new_emails.count}"

    if new_emails.empty?
      puts "\n✅ All emails already have accounts!"
      return
    end

    puts "\nReady to send #{new_emails.count} invitations."
    print "Continue? (yes/test/no): "
    response = STDIN.gets.chomp.downcase

    case response
    when "test"
      puts "\nTEST MODE - First 5 recipients:"
      new_emails.first(5).each_with_index do |sitting, i|
        puts "  #{i+1}. #{sitting[:email]} (#{sitting[:name] || 'no name'})"
      end
      puts "\nTest complete. Run with 'yes' to send invitations."
      return
    when "yes"
      puts "\nStarting invitation send...\n"
    else
      puts "Cancelled."
      return
    end

    # Track results
    sent = 0
    failed = 0
    errors = []

    # Ask if resuming
    print "Start from email # (1-#{new_emails.count}) or Enter to start from beginning: "
    start_from = STDIN.gets.chomp
    start_index = start_from.empty? ? 0 : [ start_from.to_i - 1, 0 ].max

    # Get the superadmin to be the inviter
    inviter = User.find_by(superadmin: true) || User.find_by(admin: true)

    unless inviter
      puts "❌ ERROR: No admin user found to send invitations from!"
      puts "Please create an admin account first."
      return
    end

    puts "\nSending invitations as: #{inviter.email}\n\n"

    # Process emails with rate limiting
    new_emails.each_with_index do |sitting_data, index|
      # Skip if before start index
      next if index < start_index

      # Check daily limit
      if sent >= DAILY_LIMIT
        puts "\n⚠️  Daily limit reached (#{DAILY_LIMIT} invitations)"
        puts "Resume tomorrow from email ##{index + 1}"
        break
      end

      begin
        email = sitting_data[:email]
        name = sitting_data[:name]

        # Create the Devise invitation
        user = User.invite!(
          {
            email: email,
            name: name,
            admin: false  # Regular users, not admins
          },
          inviter  # Who is sending the invitation
        )

        if user.persisted?
          sent += 1
          puts "[#{index + 1}/#{new_emails.count}] ✅ INVITED: #{email} (#{name || 'no name'})"
        else
          failed += 1
          error_msg = user.errors.full_messages.join(", ")
          errors << { email: email, error: error_msg }
          puts "[#{index + 1}/#{new_emails.count}] ❌ FAILED: #{email} - #{error_msg}"
        end

        # Rate limiting - CRITICAL for Gmail
        if index < new_emails.count - 1  # Don't delay after last email
          print "   ⏱️  Waiting #{DELAY_SECONDS} seconds..."
          sleep(DELAY_SECONDS)
          print "\r                                    \r"  # Clear the waiting message
        end

      rescue => e
        failed += 1
        errors << { email: sitting_data[:email], error: e.message }
        puts "[#{index + 1}/#{new_emails.count}] ❌ ERROR: #{sitting_data[:email]}"
        puts "   Error: #{e.message}"
      end

      # Progress update every 10 emails
      if (sent + failed) % 10 == 0
        puts "\n--- Progress: Sent: #{sent}, Failed: #{failed} ---\n"
      end
    end

    # Final report
    puts "\n\n==================================="
    puts "INVITATION SEND COMPLETE"
    puts "==================================="
    puts "✅ Sent: #{sent} invitations"
    puts "❌ Failed: #{failed}"
    puts "==================================="

    if errors.any?
      puts "\nFailed emails:"
      errors.each do |err|
        puts "  • #{err[:email]}: #{err[:error]}"
      end
    end

    if sent < new_emails.count
      remaining = new_emails.count - sent - failed
      puts "\n#{remaining} invitations remaining. Run task again to continue."
    end
  end

  desc "Check invitation status for all sitting emails"
  task check_status: :environment do
    puts "\n==================================="
    puts "INVITATION STATUS REPORT"
    puts "==================================="

    # Get all sitting emails
    sitting_emails = Sitting.where.not(email: [ nil, "" ])
                            .distinct
                            .pluck(:email)
                            .map(&:downcase)

    # Categorize users
    users = User.where(email: sitting_emails)

    accepted = users.invitation_accepted.count
    pending = users.invitation_not_accepted.count
    no_account = sitting_emails.count - users.count

    puts "📊 Status Summary:"
    puts "  • Total sitting emails: #{sitting_emails.count}"
    puts "  • ✅ Accounts created (accepted): #{accepted}"
    puts "  • ⏳ Invitations sent (pending): #{pending}"
    puts "  • ❌ No invitation yet: #{no_account}"

    # Show sample of pending
    if pending > 0
      puts "\n⏳ Sample of pending invitations (up to 5):"
      users.invitation_not_accepted.limit(5).each do |user|
        days_ago = ((Time.current - user.invitation_sent_at) / 1.day).round
        puts "  • #{user.email} (sent #{days_ago} days ago)"
      end
    end

    # Show sample of those needing invites
    if no_account > 0
      puts "\n❌ Sample of emails needing invitations (up to 5):"
      need_invite = sitting_emails - users.pluck(:email).map(&:downcase)
      need_invite.first(5).each do |email|
        puts "  • #{email}"
      end
    end

    puts "\n==================================="
    puts "Run 'rails devise:bulk_invite' to send invitations"
    puts "==================================="
  end

  desc "Send test Devise invitation"
  task test_invite: :environment do
    print "Enter test email address: "
    test_email = STDIN.gets.chomp

    inviter = User.find_by(superadmin: true) || User.find_by(admin: true)

    unless inviter
      puts "❌ No admin user found!"
      return
    end

    puts "Sending test invitation to #{test_email}..."

    user = User.invite!(
      { email: test_email, admin: false },
      inviter
    )

    if user.persisted?
      puts "✅ Invitation sent! Check #{test_email}"
    else
      puts "❌ Failed: #{user.errors.full_messages.join(', ')}"
    end
  end
end
