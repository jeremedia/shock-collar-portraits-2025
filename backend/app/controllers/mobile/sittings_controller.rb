class Mobile::SittingsController < ApplicationController
  skip_before_action :verify_authenticity_token
  
  def new
    @sitting = Sitting.new
    @session_number = params[:session] || next_session_number
    @last_sitting = Sitting.last
  end
  
  def create
    session_number = params[:sitting][:session_number].to_i
    photo_session = PhotoSession.find_by(session_number: session_number)
    
    if photo_session.nil?
      # Session doesn't exist yet - that's ok, just note it
      flash[:alert] = "Session ##{session_number} not found in system"
      redirect_to new_mobile_sitting_path(session: session_number)
      return
    end
    
    @sitting = photo_session.sittings.build(sitting_params)
    @sitting.position = photo_session.sittings.count + 1
    
    if @sitting.save
      flash[:success] = "✓ Saved #{@sitting.name || 'entry'} for Session ##{session_number}"
      redirect_to new_mobile_sitting_path(session: session_number + 1)
    else
      flash[:error] = "Error: #{@sitting.errors.full_messages.join(', ')}"
      redirect_to new_mobile_sitting_path(session: session_number)
    end
  end
  
  private
  
  def sitting_params
    params.require(:sitting).permit(:name, :email, :notes)
  end
  
  def next_session_number
    last = Sitting.joins(:photo_session).maximum('photo_sessions.session_number') || 0
    last + 1
  end
end