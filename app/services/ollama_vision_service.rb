require "net/http"
require "json"
require "base64"
require "vips"

class OllamaVisionService
  OLLAMA_API_URL = ENV.fetch("OLLAMA_API_URL", "http://localhost:11434")
  MODEL_NAME = ENV.fetch("OLLAMA_MODEL", "llava:7b") # Use llava for vision, gemma doesn't support images

  class << self
    def analyze_gender(photo)
      return nil unless photo.has_faces? && photo.image.attached?

      # Get the face crop as base64
      face_image_base64 = get_face_crop_base64(photo)
      return nil unless face_image_base64

      # Send to Ollama for analysis
      response = query_ollama(face_image_base64)

      # Parse the response
      parse_gender_response(response, photo.id)
    rescue => e
      Rails.logger.error "OllamaVisionService error for photo #{photo.id}: #{e.message}"
      nil
    end

    private

    def get_face_crop_base64(photo)
      # Get face crop parameters
      crop_params = ::FaceDetectionService.face_crop_params(photo)
      return nil unless crop_params

      # Generate face crop variant
      variant = photo.image.variant(
        extract_area: [
          crop_params[:left],
          crop_params[:top],
          crop_params[:width],
          crop_params[:height]
        ],
        resize_to_limit: [ 400, 400 ],
        format: :jpg,
        saver: { quality: 85 }
      )

      # Process and download the variant
      processed = variant.processed

      # Download to temp file and encode as base64
      processed.download do |file|
        Base64.strict_encode64(file.read)
      end
    end

    def query_ollama(image_base64)
      uri = URI.parse("#{OLLAMA_API_URL}/api/generate")

      prompt = <<~PROMPT
        Analyze this portrait photo and determine the gender presentation of the person.
        Respond with ONLY a JSON object in this exact format:
        {
          "gender": "male" or "female" or "non-binary",
          "confidence": 0.0 to 1.0,
          "reasoning": "brief explanation"
        }

        Be respectful and base your assessment only on visual presentation.
        If uncertain, use "non-binary" with lower confidence.
      PROMPT

      request_body = {
        model: MODEL_NAME,
        prompt: prompt,
        images: [ image_base64 ],
        stream: false,
        options: {
          temperature: 0.1  # Low temperature for consistent results
        }
      }

      http = Net::HTTP.new(uri.host, uri.port)
      http.read_timeout = 30  # 30 second timeout

      request = Net::HTTP::Post.new(uri.path)
      request.content_type = "application/json"
      request.body = request_body.to_json

      response = http.request(request)

      if response.code == "200"
        JSON.parse(response.body)["response"]
      else
        Rails.logger.error "Ollama API error: #{response.code} - #{response.body}"
        nil
      end
    end

    def parse_gender_response(response_text, photo_id)
      return nil unless response_text

      # Extract JSON from the response
      json_match = response_text.match(/\{.*\}/m)
      return nil unless json_match

      begin
        result = JSON.parse(json_match[0])

        {
          gender: result["gender"],
          confidence: result["confidence"].to_f,
          reasoning: result["reasoning"],
          model: MODEL_NAME,
          analyzed_at: Time.current
        }
      rescue JSON::ParserError => e
        Rails.logger.error "Failed to parse Ollama response for photo #{photo_id}: #{e.message}"
        Rails.logger.debug "Raw response: #{response_text}"
        nil
      end
    end
  end
end
