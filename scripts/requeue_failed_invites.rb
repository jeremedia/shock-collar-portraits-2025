#!/usr/bin/env ruby
# Script to requeue failed invitation emails with delays to avoid rate limiting

puts "Analyzing failed invitation jobs..."

# Get all failed InvitationMailerJob executions
failed_invites = SolidQueue::FailedExecution.joins(:job)
  .where("solid_queue_jobs.class_name = ?", "InvitationMailerJob")
  .includes(:job)

puts "Found #{failed_invites.count} failed invitation jobs"

if failed_invites.count == 0
  puts "No failed invitation jobs to process"
  exit 0
end

# Configuration
DELAY_BETWEEN_EMAILS = 45 # seconds between emails (45 seconds = safe, finishes in ~3 hours)
BATCH_SIZE = 3 # send this many, then wait
BATCH_DELAY = 120 # seconds between batches (2 minutes)

# Calculate which delay strategy to use based on count
total_count = failed_invites.count
if total_count < 50
  # Small batch - can go faster
  delay_seconds = 30
  batch_size = 5
  batch_delay = 60
elsif total_count < 150
  # Medium batch - moderate pacing
  delay_seconds = 45
  batch_size = 3
  batch_delay = 90
else
  # Large batch - conservative pacing
  delay_seconds = 60
  batch_size = 2
  batch_delay = 120
end

total_time_minutes = (total_count * delay_seconds) / 60.0
puts "\nUsing strategy:"
puts "  - #{delay_seconds} seconds between emails"
puts "  - Batches of #{batch_size} emails"
puts "  - #{batch_delay} seconds between batches"
puts "  - Estimated completion: #{total_time_minutes.round(1)} minutes"

print "\nExtract email addresses from failed jobs? (y/n): "
response = gets.chomp.downcase
exit unless response == 'y'

# Extract unique email addresses from failed jobs
emails_to_retry = []
failed_invites.each do |failed|
  begin
    # Parse the job arguments to get the email
    args = JSON.parse(failed.job.arguments)
    email = args.dig("arguments", 0) # First argument is the email
    invited_by_id = args.dig("arguments", 1) # Second is invited_by_id
    options = args.dig("arguments", 2) || {} # Third is options hash

    if email.present?
      emails_to_retry << {
        email: email,
        invited_by_id: invited_by_id || 1, # Default to user 1 if missing
        options: options
      }
    end
  rescue => e
    puts "Error parsing failed job #{failed.id}: #{e.message}"
  end
end

# Remove duplicates (keep the last occurrence)
emails_to_retry.uniq! { |item| item[:email] }

puts "\nFound #{emails_to_retry.count} unique emails to retry"

# Show sample
puts "\nSample emails to retry:"
emails_to_retry.first(5).each do |item|
  puts "  - #{item[:email]}"
end

print "\nProceed with requeueing? (y/n): "
response = gets.chomp.downcase
exit unless response == 'y'

# Clear the failed executions first
print "\nClear failed executions? (y/n): "
if gets.chomp.downcase == 'y'
  failed_invites.destroy_all
  puts "Cleared #{failed_invites.count} failed executions"
end

# Requeue with delays
puts "\nRequeueing invitations with delays..."
delay = 0
emails_to_retry.each_with_index do |item, index|
  # Calculate delay for this email
  batch_number = index / batch_size
  position_in_batch = index % batch_size

  # Add batch delays
  delay = (batch_number * batch_delay) + (position_in_batch * delay_seconds)

  # Schedule the job
  InvitationMailerJob.set(wait: delay.seconds).perform_later(
    item[:email],
    item[:invited_by_id],
    item[:options]
  )

  # Show progress
  if (index + 1) % 10 == 0
    puts "  Queued #{index + 1}/#{emails_to_retry.count} (#{item[:email]}) - scheduled for #{(delay / 60.0).round(1)} minutes from now"
  end
end

puts "\n✅ Successfully requeued #{emails_to_retry.count} invitations"
puts "First email will send immediately"
puts "Last email will send in approximately #{(delay / 60.0).round(1)} minutes"
puts "\nMonitor progress at: /admin/queue_status"

# Also create a simple text list of emails that failed
File.write("tmp/failed_invitation_emails.txt", emails_to_retry.map { |i| i[:email] }.join("\n"))
puts "\nEmail list saved to: tmp/failed_invitation_emails.txt"