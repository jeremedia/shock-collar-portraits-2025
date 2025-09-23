#!/usr/bin/env ruby
# Non-interactive script to requeue failed invitation emails with delays

puts "Starting automatic requeue of failed invitations..."
puts "Time: #{Time.current}"

# Get all failed InvitationMailerJob executions
failed_invites = SolidQueue::FailedExecution.joins(:job)
  .where("solid_queue_jobs.class_name = ?", "InvitationMailerJob")
  .includes(:job)

puts "Found #{failed_invites.count} failed invitation jobs"

if failed_invites.count == 0
  puts "No failed invitation jobs to process"
  exit 0
end

# Smart delay configuration based on count
total_count = failed_invites.count
if total_count < 30
  # Very small batch - 20 seconds apart, done in 10 minutes
  seconds_between = 20
elsif total_count < 60
  # Small batch - 30 seconds apart, done in 30 minutes
  seconds_between = 30
elsif total_count < 120
  # Medium batch - 45 seconds apart, done in 90 minutes
  seconds_between = 45
elsif total_count < 250
  # Large batch - 60 seconds apart, done in 4 hours
  seconds_between = 60
else
  # Very large batch - 90 seconds apart, done in 6+ hours
  seconds_between = 90
end

# Extract emails from failed jobs
emails_to_retry = []
failed_invites.each do |failed|
  begin
    args = JSON.parse(failed.job.arguments)
    email = args.dig("arguments", 0)
    invited_by_id = args.dig("arguments", 1) || 1
    options = args.dig("arguments", 2) || {}

    if email.present?
      # Check if user still needs invitation
      user = User.find_by(email: email)
      if user.nil? || !user.invitation_accepted?
        emails_to_retry << {
          email: email,
          invited_by_id: invited_by_id,
          options: options
        }
      else
        puts "Skipping #{email} - already accepted invitation"
      end
    end
  rescue => e
    Rails.logger.error "Error parsing failed job #{failed.id}: #{e.message}"
  end
end

# Remove duplicates
emails_to_retry.uniq! { |item| item[:email] }

puts "\n#{emails_to_retry.count} unique emails need to be retried"
puts "Scheduling with #{seconds_between} seconds between each email"
puts "Estimated completion time: #{(emails_to_retry.count * seconds_between / 60.0).round(1)} minutes"

# Clear the failed executions
puts "\nClearing failed executions..."
failed_invites.destroy_all

# Requeue with delays
puts "Requeueing invitations..."
emails_to_retry.each_with_index do |item, index|
  delay = index * seconds_between

  InvitationMailerJob.set(wait: delay.seconds).perform_later(
    item[:email],
    item[:invited_by_id],
    item[:options]
  )

  # Log progress every 25 emails
  if (index + 1) % 25 == 0 || index == emails_to_retry.count - 1
    puts "  Queued #{index + 1}/#{emails_to_retry.count} emails (last: #{item[:email]})"
  end
end

# Save list for reference
output_file = Rails.root.join("tmp", "requeued_invitations_#{Time.current.strftime('%Y%m%d_%H%M%S')}.txt")
File.write(output_file, emails_to_retry.map { |i| "#{i[:email]} (scheduled)" }.join("\n"))

puts "\n✅ SUCCESS: Requeued #{emails_to_retry.count} invitations"
puts "First email sends immediately"
puts "Last email sends in #{(emails_to_retry.count * seconds_between / 60.0).round(1)} minutes"
puts "Email list saved to: #{output_file}"
puts "\nMonitor progress at: https://scp-2025.oknotok.com/admin/queue_status"

# Log summary to Rails logger
Rails.logger.info "Requeued #{emails_to_retry.count} failed invitations with #{seconds_between}s delays"