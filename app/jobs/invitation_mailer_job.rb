class InvitationMailerJob < ApplicationJob
  queue_as :default

  # Add rate limiting to prevent Gmail authentication lockout
  # Gmail limits: ~20 emails/minute, 500/day for regular accounts
  def perform(email, invited_by_id, options = {})
    # Add a 5-second delay between emails to stay under rate limits
    # This gives us ~12 emails/minute, well under Gmail's limit
    sleep(5) if Rails.env.production?
    invited_by = User.find(invited_by_id)

    # Check if user already exists
    user = User.find_by(email: email)

    if user
      # Re-invite existing user if not accepted
      unless user.invitation_accepted?
        user.invite!(invited_by)
        Rails.logger.info "[InvitationMailerJob] Re-invited existing user: #{email}"
      else
        Rails.logger.info "[InvitationMailerJob] User already accepted: #{email}"
      end
    else
      # Create and invite new user
      user = User.invite!(
        {
          email: email,
          admin: options[:admin] || false,
          name: options[:name]
        },
        invited_by
      )

      if user.persisted?
        Rails.logger.info "[InvitationMailerJob] Invited new user: #{email}"
      else
        Rails.logger.error "[InvitationMailerJob] Failed to invite: #{email} - #{user.errors.full_messages.join(', ')}"
      end
    end

    user
  end
end
