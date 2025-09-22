namespace :vips do
  desc "Debug libvips loader and Active Storage variant processing for a blob key"
  task :debug_loader, [ :key ] => :environment do |_t, args|
    key = args[:key]
    abort "Usage: bin/rails vips:debug_loader[<blob_key>]" unless key

    puts "===> Looking up blob by key: #{key}"
    blob = ActiveStorage::Blob.find_by!(key: key)
    puts "Blob ##{blob.id} | filename=#{blob.filename} | content_type=#{blob.content_type} | byte_size=#{blob.byte_size}"

    # Try to find the owning Photo, if any, so we can run named variants too.
    photo = Photo.joins(image_attachment: :blob).where(active_storage_blobs: { id: blob.id }).first
    puts "Owning Photo id: #{photo&.id || 'none'}"

    require "vips"
    puts "libvips=#{Vips.version_string} concurrency=#{Vips.concurrency}"

    # Download the original to a tempfile and try various libvips load paths.
    blob.open do |file|
      path = file.path
      puts "Temp file path: #{path}"

      # 1) Direct loader discovery (this is where your crash happens)
      begin
        loader = Vips.vips_foreign_find_load(path)
        puts "vips_foreign_find_load => #{loader.inspect}"
      rescue => e
        puts "vips_foreign_find_load raised: #{e.class}: #{e.message}"
        puts e.backtrace.first(5)
      end

      # 2) Try general new_from_file (lets libvips pick the loader)
      begin
        img = Vips::Image.new_from_file(path)
        puts "new_from_file OK: #{img.width}x#{img.height} bands=#{img.bands}"
      rescue => e
        puts "new_from_file raised: #{e.class}: #{e.message}"
        puts e.backtrace.first(5)
      end

      # 3) Try explicit loaders based on content type
      loader_methods = {
        "image/jpeg" => :jpegload,
        "image/jpg"  => :jpegload,
        "image/png"  => :pngload,
        "image/webp" => :webpload,
        "image/tiff" => :tiffload,
        "image/heic" => :heifload,
        "image/heif" => :heifload,
        "image/avif" => :heifload
      }
      meth = loader_methods[blob.content_type]
      if meth && Vips::Image.respond_to?(meth)
        begin
          img = Vips::Image.public_send(meth, path)
          puts "#{meth} OK: #{img.width}x#{img.height}"
        rescue => e
          puts "#{meth} raised: #{e.class}: #{e.message}"
        end
      else
        puts "No specific loader method mapped for content_type=#{blob.content_type}"
      end
    end

    # 4) Try Active Storage variant processing similar to app usage
    begin
      variation = { resize_to_limit: [ 1600, 1600 ], format: :webp, saver: { quality: 90 } }
      puts "Processing ActiveStorage variant: #{variation.inspect}"
      variant = blob.variant(variation)
      variant.processed
      url = Rails.application.routes.url_helpers.rails_representation_url(variant, only_path: true)
      puts "Variant processed OK. URL: #{url}"
    rescue => e
      puts "ActiveStorage variant error: #{e.class}: #{e.message}"
      puts e.backtrace.first(10)
    end

    # 5) If we found a Photo, also try named variants through attachment
    if photo&.image&.attached?
      begin
        puts "Processing photo.image.variant(:large)"
        v = photo.image.variant(:large)
        v.processed
        url = Rails.application.routes.url_helpers.rails_representation_url(v, only_path: true)
        puts "Named variant :large processed OK. URL: #{url}"
      rescue => e
        puts "Named variant :large error: #{e.class}: #{e.message}"
        puts e.backtrace.first(10)
      end
    end

    puts "Done. Note: if the process segfaults, re-run with VIPS_CONCURRENCY=1 and try again."
  end
end
