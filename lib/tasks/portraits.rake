namespace :portraits do
  desc "Send portrait ready emails to sittings (Gmail-safe rate limiting)"
  task send_invites: :environment do
    # Configuration for Gmail-safe sending
    EMAILS_PER_MINUTE = 6  # Conservative: 1 every 10 seconds
    DAILY_LIMIT = 200      # Stay well under Gmail's 500 limit
    DELAY_SECONDS = 10     # 10 seconds between emails

    puts "\n==================================="
    puts "PORTRAIT INVITATION EMAIL SENDER"
    puts "==================================="
    puts "Gmail-Safe Settings:"
    puts "  • Rate: #{EMAILS_PER_MINUTE} emails/minute"
    puts "  • Delay: #{DELAY_SECONDS} seconds between emails"
    puts "  • Daily limit: #{DAILY_LIMIT} emails"
    puts "===================================\n\n"

    # Get all sittings with emails (no need to join photo_session anymore)
    sittings = Sitting.where.not(email: [nil, ''])
                      .distinct

    total = sittings.count
    puts "Found #{total} sittings with email addresses\n\n"

    # Check if we should continue
    print "Send emails to all #{total} people? (yes/test/no): "
    response = STDIN.gets.chomp.downcase

    case response
    when 'test'
      puts "\nTEST MODE - Showing first 5 recipients:\n"
      sittings.limit(5).each_with_index do |sitting, i|
        puts "  #{i+1}. #{sitting.email} (#{sitting.name || 'no name'})"
      end
      puts "\nTest complete. Run again with 'yes' to send emails."
      return
    when 'yes'
      puts "\nStarting email send...\n"
    else
      puts "Cancelled."
      return
    end

    # Track results
    sent = 0
    failed = 0
    skipped = 0
    errors = []

    # Add ability to resume from a specific email
    print "Start from email # (1-#{total}) or press Enter to start from beginning: "
    start_from = STDIN.gets.chomp
    start_index = start_from.empty? ? 0 : [start_from.to_i - 1, 0].max

    # Process in batches with rate limiting
    sittings.each_with_index do |sitting, index|
      # Skip if before start index
      next if index < start_index

      # Check daily limit
      if sent >= DAILY_LIMIT
        puts "\n⚠️  Daily limit reached (#{DAILY_LIMIT} emails)"
        puts "Resume tomorrow from email ##{index + 1}"
        break
      end

      begin
        # Send the email
        PortraitMailer.portrait_ready(sitting).deliver_now
        sent += 1

        puts "[#{index + 1}/#{total}] ✅ SENT: #{sitting.email} (#{sitting.name || 'no name'})"

        # Rate limiting - CRITICAL for Gmail
        if index < sittings.count - 1  # Don't delay after last email
          print "   ⏱️  Waiting #{DELAY_SECONDS} seconds..."
          sleep(DELAY_SECONDS)
          print "\r                                    \r"  # Clear the waiting message
        end

      rescue => e
        failed += 1
        errors << { email: sitting.email, error: e.message }
        puts "[#{index + 1}/#{total}] ❌ FAILED: #{sitting.email}"
        puts "   Error: #{e.message}"
      end

      # Progress update every 10 emails
      if (sent + failed + skipped) % 10 == 0
        puts "\n--- Progress: Sent: #{sent}, Failed: #{failed}, Skipped: #{skipped} ---\n"
      end
    end

    # Final report
    puts "\n\n==================================="
    puts "EMAIL SEND COMPLETE"
    puts "==================================="
    puts "✅ Sent: #{sent}"
    puts "❌ Failed: #{failed}"
    puts "⏭️  Skipped: #{skipped}"
    puts "==================================="

    if errors.any?
      puts "\nFailed emails:"
      errors.each do |err|
        puts "  • #{err[:email]}: #{err[:error]}"
      end
    end

    if sent < total
      remaining = total - sent - failed - skipped
      puts "\n#{remaining} emails remaining. Run task again to continue."
    end
  end

  desc "Test email setup by sending one portrait email"
  task test_email: :environment do
    print "Enter email address to test: "
    test_email = STDIN.gets.chomp

    # Find or create a test sitting
    sitting = Sitting.joins(:photo_session).first
    if sitting
      # Temporarily override email for test
      original_email = sitting.email
      sitting.email = test_email

      puts "Sending test email to #{test_email}..."
      PortraitMailer.portrait_ready(sitting).deliver_now
      puts "✅ Test email sent! Check #{test_email}"

      # Restore original
      sitting.email = original_email
    else
      puts "❌ No sittings found in database"
    end
  end

  desc "Show email statistics"
  task email_stats: :environment do
    total = Sitting.where.not(email: [nil, '']).distinct.count(:email)

    puts "\n==================================="
    puts "EMAIL STATISTICS"
    puts "==================================="
    puts "Total unique emails: #{total}"

    # Domain breakdown
    emails = Sitting.where.not(email: [nil, '']).distinct.pluck(:email)
    domains = emails.map { |e| e.split('@').last.downcase rescue nil }.compact.tally

    puts "\nTop email domains:"
    domains.sort_by { |k,v| -v }.first(10).each do |domain, count|
      percentage = (count * 100.0 / total).round(1)
      puts "  #{domain}: #{count} (#{percentage}%)"
    end

    puts "\nEstimated send time:"
    puts "  At 6 emails/minute: #{(total / 6.0).round} minutes"
    puts "  At 10 sec/email: #{(total * 10 / 60.0).round} minutes"
    puts "  Days needed at 200/day: #{(total / 200.0).ceil} days"
    puts "==================================="
  end
end