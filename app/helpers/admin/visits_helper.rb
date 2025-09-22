module Admin::VisitsHelper
  def humanize_event(event)
    case event.name
    when "Viewed photo", "Photo view", "$view"
      photo_id = extract_event_photo_id(event.properties)
      if photo_id
        photo = Photo.find_by(id: photo_id)
        if photo
          "viewed photo ##{photo.position} in session #{photo.photo_session&.session_number || '?'}"
        else
          "viewed a photo"
        end
      else
        "viewed content"
      end
    when "$click"
      "clicked " + (event.properties["text"] || "something")
    when "Ran action"
      event.properties["action"] || "performed action"
    else
      event.name.downcase.gsub('_', ' ')
    end
  end

  def extract_event_photo_id(properties)
    return nil unless properties
    data = properties.is_a?(String) ? JSON.parse(properties) : properties
    data["photo_id"] || data["id"]
  rescue
    nil
  end
end