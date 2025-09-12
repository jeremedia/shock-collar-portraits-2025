class Api::SittingsController < ApplicationController
  skip_before_action :verify_authenticity_token
  
  def create
    session = PhotoSession.find_by(session_number: params[:session_number])
    
    if session
      sitting = session.sittings.build(sitting_params)
      sitting.position = session.sittings.count + 1
      
      if sitting.save
        render json: { success: true, sitting: sitting_json(sitting) }
      else
        render json: { error: sitting.errors.full_messages }, status: 422
      end
    else
      render json: { error: 'Session not found' }, status: 404
    end
  end
  
  def show
    sitting = Sitting.find(params[:id])
    render json: sitting_json(sitting)
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Sitting not found' }, status: 404
  end
  
  def update
    sitting = Sitting.find(params[:id])
    
    if sitting.update(sitting_params)
      render json: { success: true, sitting: sitting_json(sitting) }
    else
      render json: { error: sitting.errors.full_messages }, status: 422
    end
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Sitting not found' }, status: 404
  end
  
  private
  
  def sitting_params
    params.require(:sitting).permit(:name, :email, :notes, :shock_intensity)
  end
  
  def sitting_json(sitting)
    {
      id: sitting.id,
      session_id: sitting.photo_session.burst_id,
      session_number: sitting.photo_session.session_number,
      name: sitting.name,
      email: sitting.email,
      notes: sitting.notes,
      position: sitting.position,
      shock_intensity: sitting.shock_intensity,
      hero_photo_id: sitting.hero_photo_id,
      created_at: sitting.created_at
    }
  end
end