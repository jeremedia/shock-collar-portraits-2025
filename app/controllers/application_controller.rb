class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Include URL helpers for Active Storage
  include Rails.application.routes.url_helpers

  # Track visits with Ahoy
  after_action :track_action

  # Require authentication for all actions by default,
  # but allow Devise controllers (sign in, sign up, etc.)
  before_action :authenticate_user!, unless: :devise_controller?
  
  # Permit additional parameters for devise
  before_action :configure_permitted_parameters, if: :devise_controller?
  
  protected

  # Override Devise's default redirect after sign in
  def after_sign_in_path_for(resource)
    if resource.admin? || resource.superadmin?
      # Admins go to admin dashboard or stored location
      stored_location_for(resource) || admin_dashboard_path
    else
      # Non-admins go to root (heroes page) or stored location
      stored_location_for(resource) || root_path
    end
  end

  def configure_permitted_parameters
    invite_keys = [:name]
    invite_keys << :admin if current_user&.superadmin?

    devise_parameter_sanitizer.permit(:invite, keys: invite_keys)
    devise_parameter_sanitizer.permit(:accept_invitation, keys: [:name])
    devise_parameter_sanitizer.permit(:account_update, keys: [:name])
  end
  
  def require_admin!
    unless current_user&.admin? || current_user&.superadmin?
      flash[:alert] = "You must be an admin to access this page"
      redirect_to root_path
    end
  end
  
  def require_superadmin!
    unless current_user&.superadmin?
      flash[:alert] = "Only superadmins can access this page"
      redirect_to root_path
    end
  end

  private

  def track_action
    ahoy.track "#{controller_name}##{action_name}", request.path_parameters
  end
end
