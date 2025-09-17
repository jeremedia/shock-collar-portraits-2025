require "test_helper"

class Admin::InvitesControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  setup do
    @superadmin = User.create!(
      email: "superadmin@example.com",
      password: "password123",
      password_confirmation: "password123",
      admin: true,
      superadmin: true,
      invitation_limit: 10
    )
  end

  test "superadmin can resend admin invitation" do
    raw_token, enc = Devise.token_generator.generate(User, :invitation_token)
    invited_user = User.create!(
      email: "pending-admin@example.com",
      password: "password123",
      password_confirmation: "password123",
      admin: true,
      superadmin: false,
      invitation_token: enc,
      invitation_created_at: Time.current,
      invitation_sent_at: Time.current,
      invited_by: @superadmin
    )

    post user_session_path, params: { user: { email: @superadmin.email, password: "password123" } }
    assert_response :redirect

    assert_changes -> { invited_user.reload.invitation_token } do
      post resend_admin_invite_path(invited_user)
      assert_redirected_to admin_invites_path
      assert_equal "Invitation resent to #{invited_user.email}", flash[:notice]
    end
  end
end
