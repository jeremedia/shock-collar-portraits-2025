class PhotosController < ApplicationController
  def serve
    path = params[:path]
    # Add .JPG extension if not present (for compatibility)
    path += '.JPG' unless path.match?(/\.(jpg|jpeg|png|heic|webp)$/i)
    
    full_path = Rails.root.join('..', path)
    
    if File.exist?(full_path)
      send_file full_path, disposition: 'inline', type: 'image/jpeg'
    else
      render plain: 'Photo not found', status: 404
    end
  end
end