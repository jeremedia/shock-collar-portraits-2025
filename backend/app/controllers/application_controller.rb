class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern
  
  # Include URL helpers for Active Storage
  include Rails.application.routes.url_helpers
  
  # Require authentication for all actions by default
  before_action :authenticate_user!
  
  # Permit additional parameters for devise
  before_action :configure_permitted_parameters, if: :devise_controller?
  
  protected
  
  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:invite, keys: [:name])
    devise_parameter_sanitizer.permit(:accept_invitation, keys: [:name])
    devise_parameter_sanitizer.permit(:account_update, keys: [:name])
  end
end
