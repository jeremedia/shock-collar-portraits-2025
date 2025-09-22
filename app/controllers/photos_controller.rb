class PhotosController < ApplicationController
  def serve
    path = params[:path]

    # Try to find photo by path or filename
    photo = Photo.find_by(filename: File.basename(path)) ||
            Photo.find_by("original_path LIKE ?", "%#{path}%")

    if photo && photo.image.attached?
      # Serve from Active Storage
      variant = params[:variant]&.to_sym

      if variant && [ :thumb, :medium, :large, :gallery ].include?(variant)
        redirect_to rails_blob_url(photo.image.variant(variant), disposition: "inline"), allow_other_host: true
      else
        redirect_to rails_blob_url(photo.image, disposition: "inline"), allow_other_host: true
      end
    else
      # Photo not found in database or doesn't have attachment
      render plain: "Photo not found", status: 404
    end
  end
end
