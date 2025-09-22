module Admin::VisitsHelper
  def humanize_event(event)
    case event.name
    when "heroes#show"
      photo_id = extract_event_photo_id(event.properties)
      if photo_id
        photo = Photo.find_by(id: photo_id)
        if photo
          "viewed hero photo ##{photo.position} in session #{photo.photo_session&.session_number || '?'}"
        else
          "viewed a hero photo"
        end
      else
        "viewed hero content"
      end
    when "gallery#show"
      "viewed gallery session"
    when "heroes#index"
      "browsed hero gallery"
    when "gallery#index"
      "browsed photo gallery"
    when "$click"
      "clicked " + (event.properties["text"] || "something")
    when "Ran action"
      event.properties["action"] || "performed action"
    else
      event.name.downcase.gsub("#", " ").gsub("_", " ")
    end
  end

  def extract_event_photo_id(properties)
    return nil unless properties
    data = properties.is_a?(String) ? JSON.parse(properties) : properties

    # Check for Rails controller params (most common)
    if data["id"]
      return data["id"].to_i
    end

    # Check for direct photo_id
    return data["photo_id"].to_i if data["photo_id"]

    # Extract from URL patterns like /heroes/123 or /gallery/123
    url = data["url"] || data["path"] || ""
    if match = url.match(/\/(?:heroes|gallery)\/(\d+)/)
      return match[1].to_i
    end

    nil
  rescue
    nil
  end
end
