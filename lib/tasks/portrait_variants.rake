namespace :portraits do
  desc "Pre-generate portrait variants for all hero photos"
  task pregenerate_heroes: :environment do
    hero_photo_ids = PhotoSession.where.not(hero_photo_id: nil).pluck(:hero_photo_id)
    total = hero_photo_ids.count

    puts "Found #{total} hero photos to process..."

    hero_photo_ids.each_with_index do |photo_id, index|
      PortraitVariantJob.perform_later(photo_id)

      if (index + 1) % 10 == 0
        puts "Queued #{index + 1} / #{total} photos..."
      end
    end

    puts "✅ Queued all #{total} hero photos for portrait variant generation!"
    puts "Check job queue status with: bin/rails jobs:queue:status"
  end

  desc "Pre-generate portrait variants for photos with portrait crops"
  task pregenerate_all: :environment do
    photos = Photo.where.not(portrait_crop_data: nil)
    total = photos.count

    puts "Found #{total} photos with portrait crops..."

    photos.find_each.with_index do |photo, index|
      PortraitVariantJob.perform_later(photo.id)

      if (index + 1) % 50 == 0
        puts "Queued #{index + 1} / #{total} photos..."
      end
    end

    puts "✅ Queued all #{total} photos for portrait variant generation!"
    puts "Check job queue status with: bin/rails jobs:queue:status"
  end

  desc "Synchronously process portrait variants for testing"
  task test_one: :environment do
    photo = PhotoSession.where.not(hero_photo_id: nil).first&.hero_photo

    if photo
      puts "Processing portrait variants for Photo ##{photo.id}..."
      start = Time.current

      photo.ensure_portrait_processed!(width: 1080, height: 1920)
      photo.ensure_portrait_processed!(width: 720, height: 1280)

      elapsed = Time.current - start
      puts "✅ Done in #{elapsed.round(2)} seconds"
    else
      puts "No hero photos found"
    end
  end
end
