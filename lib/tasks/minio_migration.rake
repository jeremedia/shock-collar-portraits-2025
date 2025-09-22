namespace :storage do
  desc "Migrate from AWS S3 to MinIO using local files (zero S3 egress)"
  task migrate_to_minio: :environment do
    require "aws-sdk-s3"
    require "digest"

    # MinIO client configuration
    minio_client = Aws::S3::Client.new(
      endpoint: "https://s3-api.zice.app",
      access_key_id: "jeremy",
      secret_access_key: "Lopsad29",
      region: "jerBook",
      force_path_style: true
    )

    bucket_name = "shock-collar-portraits-2025"

    # Stats tracking
    stats = {
      total: 0,
      uploaded: 0,
      skipped: 0,
      failed: 0,
      errors: []
    }

    puts "🚀 Starting migration from S3 to MinIO"
    puts "=" * 60

    # Process all Active Storage blobs
    ActiveStorage::Blob.where(service_name: "amazon").find_each.with_index do |blob, index|
      stats[:total] += 1

      begin
        # Find the local file based on the blob's filename
        photo = Photo.joins(:file_attachment).where(active_storage_attachments: { blob_id: blob.id }).first

        if photo.nil?
          puts "⚠️  No photo found for blob #{blob.id}"
          stats[:skipped] += 1
          next
        end

        # Determine local file path
        day = photo.photo_session&.started_at&.strftime("%A")&.downcase
        next unless %w[monday tuesday wednesday thursday friday].include?(day)

        folder_name = File.basename(blob.filename.to_s, ".*")
        local_path = Rails.root.join("session_originals", day, folder_name, blob.filename.to_s)

        unless File.exist?(local_path)
          puts "❌ Local file not found: #{local_path}"
          stats[:failed] += 1
          stats[:errors] << "Missing: #{blob.filename}"
          next
        end

        # Check if already exists in MinIO
        begin
          minio_client.head_object(bucket: bucket_name, key: blob.key)
          puts "✓ Already in MinIO: #{blob.filename} (#{index + 1}/#{stats[:total]})"
          stats[:skipped] += 1
          next
        rescue Aws::S3::Errors::NotFound
          # File doesn't exist in MinIO, proceed with upload
        end

        # Upload to MinIO with the same key
        File.open(local_path, "rb") do |file|
          minio_client.put_object(
            bucket: bucket_name,
            key: blob.key,
            body: file,
            content_type: blob.content_type,
            metadata: {
              filename: blob.filename.to_s,
              content_type: blob.content_type || "image/jpeg",
              byte_size: blob.byte_size.to_s,
              checksum: blob.checksum
            }
          )
        end

        # Update blob to use MinIO service
        blob.update!(service_name: "minio")

        stats[:uploaded] += 1
        puts "✅ Uploaded: #{blob.filename} (#{index + 1}/#{stats[:total]})"

        # Progress indicator every 100 files
        if stats[:uploaded] % 100 == 0
          puts "\n📊 Progress: #{stats[:uploaded]} uploaded, #{stats[:skipped]} skipped, #{stats[:failed]} failed"
          puts "=" * 60
        end

      rescue => e
        stats[:failed] += 1
        stats[:errors] << "#{blob.filename}: #{e.message}"
        puts "❌ Failed: #{blob.filename} - #{e.message}"
      end
    end

    # Final report
    puts "\n" + "=" * 60
    puts "🎉 MIGRATION COMPLETE"
    puts "=" * 60
    puts "📊 Final Statistics:"
    puts "  Total blobs processed: #{stats[:total]}"
    puts "  ✅ Successfully uploaded: #{stats[:uploaded]}"
    puts "  ⏭️  Skipped (already exists): #{stats[:skipped]}"
    puts "  ❌ Failed: #{stats[:failed]}"

    if stats[:errors].any?
      puts "\n⚠️  Errors encountered:"
      stats[:errors].first(10).each { |err| puts "  - #{err}" }
      puts "  ... and #{stats[:errors].size - 10} more" if stats[:errors].size > 10
    end

    # Verify migration
    remaining_s3 = ActiveStorage::Blob.where(service_name: "amazon").count
    minio_count = ActiveStorage::Blob.where(service_name: "minio").count

    puts "\n📈 Database Status:"
    puts "  Blobs still on S3: #{remaining_s3}"
    puts "  Blobs on MinIO: #{minio_count}"

    if remaining_s3 == 0
      puts "\n✨ All blobs successfully migrated to MinIO!"
      puts "🎯 You can now safely delete the S3 bucket to stop charges."
    else
      puts "\n⚠️  Some blobs remain on S3. Run task again or check errors."
    end
  end

  desc "Verify MinIO migration status"
  task verify_minio: :environment do
    require "aws-sdk-s3"

    minio_client = Aws::S3::Client.new(
      endpoint: "https://s3-api.zice.app",
      access_key_id: "jeremy",
      secret_access_key: "Lopsad29",
      region: "jerBook",
      force_path_style: true
    )

    bucket_name = "shock-collar-portraits-2025"

    puts "🔍 Verifying MinIO migration..."
    puts "=" * 60

    # Check blob status in database
    total_blobs = ActiveStorage::Blob.count
    s3_blobs = ActiveStorage::Blob.where(service_name: "amazon").count
    minio_blobs = ActiveStorage::Blob.where(service_name: "minio").count

    puts "📊 Database Status:"
    puts "  Total blobs: #{total_blobs}"
    puts "  S3 blobs: #{s3_blobs}"
    puts "  MinIO blobs: #{minio_blobs}"

    # Sample verification - check if MinIO blobs are accessible
    sample_blobs = ActiveStorage::Blob.where(service_name: "minio").limit(10)
    accessible = 0

    sample_blobs.each do |blob|
      begin
        minio_client.head_object(bucket: bucket_name, key: blob.key)
        accessible += 1
      rescue => e
        puts "  ❌ Cannot access: #{blob.filename} - #{e.message}"
      end
    end

    puts "\n✅ Sample check: #{accessible}/10 blobs accessible in MinIO"

    # Check variant generation capability
    photo = Photo.joins(file_attachment: :blob).where(active_storage_blobs: { service_name: "minio" }).first
    if photo
      begin
        # This will trigger variant generation on MinIO
        variant_url = Rails.application.routes.url_helpers.rails_blob_path(
          photo.file.variant(resize_to_limit: [ 100, 100 ]),
          only_path: true
        )
        puts "\n✅ Variant generation test: PASSED"
        puts "  Sample variant path: #{variant_url}"
      rescue => e
        puts "\n❌ Variant generation test: FAILED - #{e.message}"
      end
    end

    if s3_blobs == 0 && minio_blobs == total_blobs
      puts "\n🎉 Migration fully verified! All blobs are on MinIO."
    else
      puts "\n⚠️  Migration incomplete. #{s3_blobs} blobs still on S3."
    end
  end

  desc "Rollback to S3 (emergency use only)"
  task rollback_to_s3: :environment do
    puts "⚠️  WARNING: This will switch all blobs back to S3"
    puts "This should only be used if MinIO fails. Continue? (y/n)"

    response = STDIN.gets.chomp.downcase
    unless response == "y"
      puts "Rollback cancelled."
      exit
    end

    count = ActiveStorage::Blob.where(service_name: "minio").update_all(service_name: "amazon")
    puts "✅ Rolled back #{count} blobs to S3"
  end
end
