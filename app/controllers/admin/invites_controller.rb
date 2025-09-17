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

    # Send invitation
    user = User.invite!(
      {
        email: email,
        admin: is_admin,
        name: params[:name]
      },
      current_user
    )

    if user.persisted?
      if is_admin
        flash[:notice] = "Admin invitation sent to #{email}"
      else
        flash[:notice] = "Invitation sent to #{email}"
      end
      redirect_to admin_invites_path
    else
      flash[:alert] = "Failed to send invitation: #{user.errors.full_messages.join(', ')}"
      redirect_to new_admin_invite_path
    end
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
      user.invite!(current_user)
      flash[:notice] = "Invitation resent to #{user.email}"
    end

    redirect_to admin_invites_path
  end
  
  private
  
  def require_superadmin!
    unless current_user.superadmin?
      flash[:alert] = "Only superadmins can manage admin invitations"
      redirect_to root_path
    end
  end
end
