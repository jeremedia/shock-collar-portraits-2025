class Users::InvitationsController < Devise::InvitationsController
  protected

  def after_accept_path_for(resource)
    if resource.admin? || resource.superadmin?
      admin_help_path
    else
      super
    end
  end
end
