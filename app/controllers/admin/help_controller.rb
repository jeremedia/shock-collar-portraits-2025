class Admin::HelpController < ApplicationController
  before_action :require_admin!

  def show
  end
end
