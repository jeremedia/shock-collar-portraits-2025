#!/usr/bin/env ruby

require_relative 'config/environment'

photos = Photo.where("filename LIKE ?", "%.HEIC").where(id: [ 3511, 3512, 3513, 3514, 3515, 3516, 3517, 3518, 3519 ])

puts "Updating #{photos.count} Photo records from HEIC to JPG:"
puts "=" * 60

photos.each do |photo|
  old_filename = photo.filename
  new_filename = old_filename.sub(".HEIC", ".jpg")

  puts "\nPhoto ##{photo.id}: #{old_filename} → #{new_filename}"

  # Update Photo record
  photo.update!(filename: new_filename)

  # Update Active Storage blob if attached
  if photo.image.attached?
    blob = photo.image.blob

    # Get the JPG file size
    day = photo.photo_session.started_at.strftime("%A").downcase
    folder_name = File.basename(new_filename, ".*")
    jpg_path = Rails.root.join("session_originals", day, folder_name, new_filename)

    if File.exist?(jpg_path)
      jpg_size = File.size(jpg_path)

      # Update blob to reflect JPG file
      blob.update!(
        filename: new_filename,
        content_type: "image/jpeg",
        byte_size: jpg_size
      )

      puts "  ✅ Updated blob ##{blob.id}"
      puts "  New size: #{jpg_size} bytes (#{(jpg_size/1024.0/1024.0).round(2)} MB)"
    else
      puts "  ⚠️  JPG file not found at #{jpg_path}"
    end
  end
end

puts "\n" + "=" * 60
puts "Verification:"
puts "Photos with .HEIC: #{Photo.where("filename LIKE ?", "%.HEIC").count}"
puts "Photos with .jpg: #{Photo.where("filename LIKE ?", "%.jpg").count}"
puts "Total photos: #{Photo.count}"

puts "\nChecking blob consistency:"
heic_blobs = ActiveStorage::Blob.where(content_type: "image/heic").count
jpeg_blobs = ActiveStorage::Blob.where(content_type: [ "image/jpeg" ]).where("byte_size > ?", 1_000_000).count
puts "HEIC blobs: #{heic_blobs}"
puts "JPEG blobs (>1MB): #{jpeg_blobs}"
