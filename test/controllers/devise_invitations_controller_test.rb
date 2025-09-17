require "test_helper"

class DeviseInvitationsControllerTest < ActionDispatch::IntegrationTest
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

    @admin = User.create!(
      email: "admin@example.com",
      password: "password123",
      password_confirmation: "password123",
      admin: true,
      superadmin: false,
      invitation_limit: 10
    )
  end

  test "superadmin can mark invite as admin" do
    post user_session_path, params: { user: { email: @superadmin.email, password: "password123" } }
    assert_response :redirect

    post user_invitation_path, params: { user: { email: "new-admin@example.com", admin: "1" } }

    invited = User.find_by(email: "new-admin@example.com")
    assert invited.present?, "expected invited user to be created"
    assert invited.admin?, "expected invited user to have admin flag"
    assert invited.invitation_token.present?, "expected invitation token to be set"
  end

  test "non superadmin invite ignores admin flag" do
    post user_session_path, params: { user: { email: @admin.email, password: "password123" } }
    assert_response :redirect

    post user_invitation_path, params: { user: { email: "regular@example.com", admin: "1" } }

    invited = User.find_by(email: "regular@example.com")
    assert invited.present?, "expected invited user to be created"
    refute invited.admin?, "expected invited user to remain non-admin"
  end

  test "admin invite acceptance redirects to help page" do
    invited = User.invite!({ email: "new-admin@example.com", admin: true }, @superadmin) do |user|
      user.skip_invitation = true
    end
    invited.update!(invitation_sent_at: Time.current)
    token = invited.raw_invitation_token

    put user_invitation_path, params: {
      user: {
        invitation_token: token,
        password: "password123",
        password_confirmation: "password123"
      }
    }

    assert_redirected_to admin_help_path
    follow_redirect!
    assert_includes @response.body, "Review Sessions & Select Heroes"
  end

  test "standard invite acceptance redirects to root" do
    invited = User.invite!({ email: "regular-user@example.com" }, @superadmin) do |user|
      user.skip_invitation = true
    end
    invited.update!(invitation_sent_at: Time.current)
    token = invited.raw_invitation_token

    put user_invitation_path, params: {
      user: {
        invitation_token: token,
        password: "password123",
        password_confirmation: "password123"
      }
    }

    assert_redirected_to root_path
  end
end
