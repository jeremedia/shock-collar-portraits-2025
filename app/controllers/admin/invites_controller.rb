class Admin::InvitesController < ApplicationController
  before_action :authenticate_user!
  before_action :require_superadmin!

  def index
    @admins = User.where(admin: true).order(:email)
    @pending_admin_invites = User.invitation_not_accepted.where(admin: true).order(invitation_sent_at: :desc)
    @pending_user_invites = User.invitation_not_accepted.where(admin: false).order(invitation_sent_at: :desc)
    @accepted_users = User.invitation_accepted.where(admin: false).order(:email)
  end

  def new
    @user = User.new
  end

  def create
    email = params[:email]&.strip&.downcase
    is_admin = params[:admin] == "1"

    if email.blank?
      flash[:alert] = "Email address is required"
      redirect_to new_admin_invite_path
      return
    end

    # Check if user already exists
    existing_user = User.find_by(email: email)

    if existing_user
      if is_admin
        if existing_user.admin?
          flash[:alert] = "#{email} is already an admin"
        else
          # Upgrade existing user to admin
          existing_user.update!(admin: true)
          flash[:notice] = "#{email} has been upgraded to admin status"
        end
      else
        if existing_user.admin?
          flash[:notice] = "#{email} already has an account (with admin access)"
        else
          flash[:notice] = "#{email} already has an account"
        end
      end
      redirect_to admin_invites_path
      return
    end

    # Queue invitation job
    InvitationMailerJob.perform_later(
      email,
      current_user.id,
      admin: is_admin,
      name: params[:name]
    )

    if is_admin
      flash[:notice] = "Admin invitation queued for #{email}"
    else
      flash[:notice] = "Invitation queued for #{email}"
    end
    redirect_to admin_invites_path
  end

  def destroy
    user = User.find(params[:id])

    if user.superadmin?
      flash[:alert] = "Cannot revoke superadmin privileges"
    elsif user == current_user
      flash[:alert] = "Cannot revoke your own admin privileges"
    elsif user.admin?
      user.update!(admin: false)
      flash[:notice] = "Admin privileges revoked for #{user.email}"
    end

    redirect_to admin_invites_path
  end

  def resend
    user = User.find(params[:id])

    if user.invitation_accepted?
      flash[:alert] = "User has already accepted their invitation"
    else
      InvitationMailerJob.perform_later(
        user.email,
        current_user.id,
        admin: user.admin?,
        name: user.name
      )
      flash[:notice] = "Invitation queued for #{user.email}"
    end

    redirect_to admin_invites_path
  end

  def sitters
    # Get all unique emails from sittings
    @sitter_emails = Sitting.select(:email)
                            .distinct
                            .order(:email)
                            .pluck(:email)

    # Get all existing users to check their invitation status
    @users_by_email = User.all.index_by(&:email)

    # Get failed invitation jobs for error visibility
    @failed_invitations_by_email = {}
    if defined?(SolidQueue::FailedExecution)
      SolidQueue::FailedExecution.joins(:job)
                                 .where(solid_queue_jobs: { class_name: "InvitationMailerJob" })
                                 .includes(:job)
                                 .each do |failed|
        begin
          email = JSON.parse(failed.job.arguments).dig("arguments", 0)
          if email
            @failed_invitations_by_email[email] ||= []
            @failed_invitations_by_email[email] << {
              error_message: failed.error&.dig("message"),
              error_class: failed.error&.dig("exception_class"),
              failed_at: failed.created_at
            }
          end
        rescue => e
          Rails.logger.error "Error parsing failed invitation job: #{e.message}"
        end
      end
    end

    # Build data structure for the view
    @sitters_data = @sitter_emails.map do |email|
      user = @users_by_email[email]
      failed_attempts = @failed_invitations_by_email[email] || []

      {
        email: email,
        user: user,
        invited: user.present?,
        accepted: user&.invitation_accepted? || false,
        invitation_sent_at: user&.invitation_sent_at,
        sessions_count: Sitting.where(email: email).count,
        failed_attempts: failed_attempts,
        has_errors: failed_attempts.any?
      }
    end

    # Calculate stats
    @total_emails = @sitter_emails.count
    @invited_count = @sitters_data.count { |s| s[:invited] }
    @accepted_count = @sitters_data.count { |s| s[:accepted] }
    @pending_count = @sitters_data.count { |s| s[:invited] && !s[:accepted] }
  end

  def invite_sitter
    # Handle bulk operations
    if params[:bulk_action].present?
      case params[:bulk_action]
      when "not_invited"
        # Get all emails that haven't been invited
        emails = Sitting.select(:email).distinct.pluck(:email)
        existing_emails = User.pluck(:email)
        emails_to_invite = emails - existing_emails

        emails_to_invite.each do |email|
          InvitationMailerJob.perform_later(
            email,
            current_user.id,
            admin: false
          )
        end

        flash[:notice] = "Queued invitations for #{emails_to_invite.count} sitters"

      when "pending"
        # Resend to all pending invitations with delays to avoid rate limiting
        pending_users = User.invitation_not_accepted.where(email: Sitting.select(:email).distinct.pluck(:email))

        if pending_users.count == 0
          flash[:alert] = "No pending invitations to resend"
        else
          # Calculate delay strategy based on count
          total_count = pending_users.count
          if total_count < 30
            seconds_between = 30 # Small batch - 30 seconds apart
          elsif total_count < 60
            seconds_between = 45 # Medium batch - 45 seconds apart
          elsif total_count < 150
            seconds_between = 60 # Large batch - 60 seconds apart
          else
            seconds_between = 90 # Very large batch - 90 seconds apart
          end

          # Schedule jobs with delays
          pending_users.each_with_index do |user, index|
            delay = index * seconds_between

            InvitationMailerJob.set(wait: delay.seconds).perform_later(
              user.email,
              current_user.id,
              admin: false,
              name: user.name
            )
          end

          # Calculate completion time
          completion_minutes = (total_count * seconds_between / 60.0).round(1)

          flash[:notice] = "✅ Scheduled #{pending_users.count} invitation resends with #{seconds_between}s delays. " \
                          "Completion time: ~#{completion_minutes} minutes. " \
                          "<a href='#{admin_queue_status_path}' target='_blank' class='underline'>Monitor progress</a>".html_safe

          # Log the bulk operation
          Rails.logger.info "[BULK RESEND] Scheduled #{total_count} invitation resends by #{current_user.email} " \
                           "with #{seconds_between}s delays (completion: #{completion_minutes} min)"
        end
      end
    else
      # Handle individual invitation
      email = params[:email]&.strip&.downcase

      if email.blank?
        flash[:alert] = "Email address is required"
        redirect_to sitters_admin_invites_path
        return
      end

      # Queue invitation job
      InvitationMailerJob.perform_later(
        email,
        current_user.id,
        admin: false
      )

      flash[:notice] = "Invitation queued for #{email}"
    end

    redirect_to sitters_admin_invites_path
  end

  private

  def require_superadmin!
    unless current_user.superadmin?
      flash[:alert] = "Only superadmins can manage admin invitations"
      redirect_to root_path
    end
  end
end
