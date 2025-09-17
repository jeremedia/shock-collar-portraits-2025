class ImageAttachmentService
  require 'shellwords'
  
  class << self
    def attach_image(photo)
      return false unless photo.original_path.present?
      return false unless File.exist?(photo.original_path)
      return true if photo.image.attached?
      
      file_path = photo.original_path
      
      # Handle HEIC files by converting to JPEG
      if heic_file?(file_path)
        attach_heic_image(photo, file_path)
      else
        attach_regular_image(photo, file_path)
      end
      
      true
    rescue => e
      Rails.logger.error "ImageAttachmentService: Failed to attach image for Photo ##{photo.id}: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      false
    end
    
    def attach_all_missing
      photos_without_attachment = Photo.where.not(id: Photo.joins(:image_attachment))
                                       .where.not(original_path: [nil, ''])
      
      Rails.logger.info "Found #{photos_without_attachment.count} photos without attachments"
      
      photos_without_attachment.find_each do |photo|
        ImageAttachmentJob.perform_later(photo.id)
      end
      
      photos_without_attachment.count
    end
    
    private
    
    def heic_file?(path)
      path.downcase.ends_with?('.heic', '.heif')
    end
    
    def attach_heic_image(photo, file_path)
      # Create a temporary JPEG file
      temp_path = Rails.root.join('tmp', "temp_photo_#{photo.id}_#{SecureRandom.hex(4)}.jpg")

      begin
        converted = false

        # 1) Prefer macOS `sips` for robust HEIC -> JPEG with orientation handling
        if command_available?("sips")
          cmd = [
            "sips",
            "-s", "format", "jpeg",
            "-s", "formatOptions", "best",
            Shellwords.escape(file_path),
            "--out",
            Shellwords.escape(temp_path.to_s)
          ].join(' ')
          Rails.logger.info "Converting HEIC via sips: #{cmd}"
          converted = system(cmd)
        end

        # 2) Fallback: Swift CoreImage/ImageIO helper (maintained in repo)
        if !converted && command_available?("swift") && File.exist?(Rails.root.join('bin/convert_heic.swift'))
          cmd = [
            "swift",
            Rails.root.join('bin/convert_heic.swift').to_s,
            file_path,
            temp_path.to_s
          ]
          Rails.logger.info "Converting HEIC via Swift helper: #{cmd.join(' ')}"
          converted = system(*cmd)
        end

        unless converted && File.exist?(temp_path) && File.size?(temp_path)
          raise "HEIC conversion failed (sips/swift not available or conversion error)"
        end

        # Attach the converted image
        photo.image.attach(
          io: File.open(temp_path),
          filename: photo.filename.sub(/\.hei[cf]$/i, '.jpg'),
          content_type: 'image/jpeg'
        )

        Rails.logger.info "Attached HEIC image as JPEG for Photo ##{photo.id}"
      ensure
        # Clean up temporary file
        File.delete(temp_path) if File.exist?(temp_path)
      end
    end
    
    def attach_regular_image(photo, file_path)
      # Determine content type
      content_type = case File.extname(file_path).downcase
                     when '.jpg', '.jpeg'
                       'image/jpeg'
                     when '.png'
                       'image/png'
                     when '.gif'
                       'image/gif'
                     when '.webp'
                       'image/webp'
                     else
                       Marcel::MimeType.for(File.open(file_path))
                     end
      
      # Attach the image directly
      photo.image.attach(
        io: File.open(file_path),
        filename: photo.filename,
        content_type: content_type
      )
      
      Rails.logger.info "Attached image for Photo ##{photo.id}"
    end

    def command_available?(name)
      exts = ENV['PATHEXT'] ? ENV['PATHEXT'].split(';') : ['']
      ENV['PATH'].split(File::PATH_SEPARATOR).any? do |path|
        exts.any? do |ext|
          File.executable?(File.join(path, "#{name}#{ext}"))
        end
      end
    end
  end
end
