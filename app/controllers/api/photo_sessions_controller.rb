class Api::PhotoSessionsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin
  before_action :set_photo_session

  # PATCH /api/photo_sessions/:id/tags
  def update_tags
    tag = params[:tag]
    context = params[:context] || "tags"
    # IMPORTANT: params[:action] is the Rails controller action, not our parameter
    # We need to use a different parameter name
    tag_action = params[:tag_action]

    unless tag.present?
      return render json: { error: "Tag is required" }, status: 422
    end

    # Map context to the correct tagging method
    tag_list_method = case context
    when "appearance" then :appearance_tag_list
    when "expression" then :expression_tag_list
    when "accessory" then :accessory_tag_list
    else :tag_list
    end

    # Get current tags for the context
    current_tags = @photo_session.send(tag_list_method)

    # Add or remove the tag
    if tag_action == "remove"
      # For acts-as-taggable-on, we need to reassign the entire list
      new_tags = current_tags.to_a.reject { |t| t == tag }
      @photo_session.send("#{tag_list_method}=", new_tags)
    else
      current_tags.add(tag)
    end

    # Save the changes
    @photo_session.save!

    render json: {
      status: "success",
      gender: @photo_session.detected_gender || "not-set",
      quality: @photo_session.quality || "ok",
      all_tags: @photo_session.tag_list,
      appearance_tags: @photo_session.appearance_tag_list,
      expression_tags: @photo_session.expression_tag_list,
      accessory_tags: @photo_session.accessory_tag_list
    }
  rescue => e
    Rails.logger.error "Failed to update tags: #{e.message}"
    render json: { error: e.message }, status: 500
  end

  # PATCH /api/photo_sessions/:id/gender
  def update_gender
    gender = params[:gender]

    unless %w[male female non-binary not-set].include?(gender)
      return render json: { error: "Invalid gender value" }, status: 422
    end

    # Update gender_analysis JSON field with human-set values
    if gender == "not-set"
      # Clear the gender analysis when set to "not-set"
      @photo_session.update!(
        gender_analysis: nil,
        gender_analyzed_at: nil
      )
    else
      # Create human-set gender analysis JSON matching Ollama structure
      gender_analysis_data = {
        gender: gender,
        confidence: 1.0,  # 100% confidence for human-set
        reasoning: "Human-set",
        model: "human",
        analyzed_at: Time.current
      }

      @photo_session.update!(
        gender_analysis: gender_analysis_data.to_json,
        gender_analyzed_at: Time.current
      )
    end

    render json: {
      status: "success",
      gender: @photo_session.detected_gender || "not-set",
      quality: @photo_session.quality || "ok",
      all_tags: @photo_session.tag_list,
      appearance_tags: @photo_session.appearance_tag_list,
      expression_tags: @photo_session.expression_tag_list,
      accessory_tags: @photo_session.accessory_tag_list
    }
  rescue => e
    Rails.logger.error "Failed to update gender: #{e.message}"
    render json: { error: e.message }, status: 500
  end

  # PATCH /api/photo_sessions/:id/quality
  def update_quality
    quality = params[:quality]

    unless %w[ok not-ok awesome].include?(quality)
      return render json: { error: "Invalid quality value" }, status: 422
    end

    @photo_session.update!(quality: quality)

    render json: {
      status: "success",
      gender: @photo_session.detected_gender || "not-set",
      quality: @photo_session.quality || "ok",
      all_tags: @photo_session.tag_list,
      appearance_tags: @photo_session.appearance_tag_list,
      expression_tags: @photo_session.expression_tag_list,
      accessory_tags: @photo_session.accessory_tag_list
    }
  rescue => e
    Rails.logger.error "Failed to update quality: #{e.message}"
    render json: { error: e.message }, status: 500
  end

  # DELETE /api/photo_sessions/:id/tags/clear
  def clear_tags
    # Clear all tag contexts
    @photo_session.tag_list.clear
    @photo_session.appearance_tag_list.clear
    @photo_session.expression_tag_list.clear
    @photo_session.accessory_tag_list.clear
    @photo_session.save!

    render json: {
      status: "success",
      gender: @photo_session.detected_gender || "not-set",
      quality: @photo_session.quality || "ok",
      all_tags: [],
      appearance_tags: [],
      expression_tags: [],
      accessory_tags: []
    }
  rescue => e
    Rails.logger.error "Failed to clear tags: #{e.message}"
    render json: { error: e.message }, status: 500
  end

  private

  def set_photo_session
    @photo_session = PhotoSession.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: "PhotoSession not found" }, status: 404
  end

  def require_admin
    unless current_user&.admin?
      render json: { error: "Admin access required" }, status: 403
    end
  end
end
