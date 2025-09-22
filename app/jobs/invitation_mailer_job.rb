class InvitationMailerJob < ApplicationJob
  queue_as :default

  def perform(email, invited_by_id, options = {})
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
