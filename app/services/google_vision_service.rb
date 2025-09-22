require "google/cloud/vision"

class GoogleVisionService
  def self.analyze_face(photo)
    return nil unless photo.has_faces? && photo.image.attached?

    # Initialize the client (uses GOOGLE_APPLICATION_CREDENTIALS env var)
    client = Google::Cloud::Vision.image_annotator

    # Get the face crop URL or use the full image
    image_url = if photo.respond_to?(:face_crop_url) && photo.face_crop_url
                  photo.face_crop_url(size: 400)
    else
                  # Fall back to using the medium variant
                  Rails.application.routes.url_helpers.rails_blob_url(
                    photo.image.variant(:medium),
                    host: Rails.application.config.action_mailer.default_url_options[:host]
                  )
    end

    # Prepare the image for analysis
    image = { source: { image_uri: image_url } }

    # Configure face detection features
    features = [
      { type: :FACE_DETECTION, max_results: 1 }
    ]

    # Perform the analysis
    response = client.annotate_image(
      image: image,
      features: features
    )

    # Extract face annotations
    face = response.face_annotations.first
    return nil unless face

    # Map Google Vision likelihood to gender prediction
    # Note: Google Vision doesn't directly provide gender, but we can infer from attributes
    # We'll use facial features and expressions as indicators
    attributes = {
      joy: likelihood_to_score(face.joy_likelihood),
      sorrow: likelihood_to_score(face.sorrow_likelihood),
      anger: likelihood_to_score(face.anger_likelihood),
      surprise: likelihood_to_score(face.surprise_likelihood),
      headwear: likelihood_to_score(face.headwear_likelihood),
      # Face landmarks for additional analysis if needed
      roll_angle: face.roll_angle,
      pan_angle: face.pan_angle,
      tilt_angle: face.tilt_angle,
      detection_confidence: face.detection_confidence,
      landmarking_confidence: face.landmarking_confidence
    }

    # Since Google Vision doesn't provide gender directly,
    # we would need to use a different API or ML model for gender detection
    # For now, return the facial attributes
    {
      attributes: attributes,
      confidence: face.detection_confidence,
      note: "Google Vision API doesn't provide gender classification directly. Consider using AWS Rekognition or Azure Face API for gender detection."
    }
  rescue => e
    Rails.logger.error "GoogleVisionService error for photo #{photo.id}: #{e.message}"
    nil
  end

  private

  def self.likelihood_to_score(likelihood)
    case likelihood
    when :VERY_LIKELY
      1.0
    when :LIKELY
      0.75
    when :POSSIBLE
      0.5
    when :UNLIKELY
      0.25
    when :VERY_UNLIKELY
      0.0
    else
      nil
    end
  end
end
