namespace :s3 do
  desc "Configure CORS for S3 bucket"
  task configure_cors: :environment do
    require "aws-sdk-s3"

    bucket_name = "shock-collar-portraits-2025"

    cors_configuration = {
      cors_rules: [
        {
          allowed_headers: [ "*" ],
          allowed_methods: [ "GET", "HEAD" ],
          allowed_origins: [
            "https://scp-dev.zice.app",
            "https://scp-25.oknotok.com",
            "https://scp-25-dev.oknotok.com",
            "http://localhost:3225",
            "http://localhost:3000",
            "http://localhost:4000"
          ],
          expose_headers: [
            "ETag",
            "Content-Length",
            "Content-Type",
            "Cache-Control"
          ],
          max_age_seconds: 3600
        }
      ]
    }

    s3_client = Aws::S3::Client.new(
      region: Rails.application.credentials.aws[:region] || "us-west-2",
      access_key_id: Rails.application.credentials.aws[:access_key_id],
      secret_access_key: Rails.application.credentials.aws[:secret_access_key]
    )

    begin
      s3_client.put_bucket_cors(
        bucket: bucket_name,
        cors_configuration: cors_configuration
      )

      puts "✅ CORS configuration applied successfully to bucket: #{bucket_name}"
      puts "Allowed origins:"
      cors_configuration[:cors_rules][0][:allowed_origins].each do |origin|
        puts "  - #{origin}"
      end
    rescue Aws::S3::Errors::ServiceError => e
      puts "❌ Error configuring CORS: #{e.message}"
      exit 1
    end
  end

  desc "Check current CORS configuration"
  task check_cors: :environment do
    require "aws-sdk-s3"

    bucket_name = "shock-collar-portraits-2025"

    s3_client = Aws::S3::Client.new(
      region: Rails.application.credentials.aws[:region] || "us-west-2",
      access_key_id: Rails.application.credentials.aws[:access_key_id],
      secret_access_key: Rails.application.credentials.aws[:secret_access_key]
    )

    begin
      resp = s3_client.get_bucket_cors(bucket: bucket_name)

      puts "Current CORS configuration for bucket: #{bucket_name}"
      resp.cors_rules.each_with_index do |rule, index|
        puts "\nRule #{index + 1}:"
        puts "  Allowed origins: #{rule.allowed_origins.join(', ')}"
        puts "  Allowed methods: #{rule.allowed_methods.join(', ')}"
        puts "  Allowed headers: #{rule.allowed_headers.join(', ')}"
        puts "  Expose headers: #{rule.expose_headers.join(', ')}" if rule.expose_headers
        puts "  Max age: #{rule.max_age_seconds} seconds" if rule.max_age_seconds
      end
    rescue Aws::S3::Errors::NoSuchCORSConfiguration
      puts "No CORS configuration found for bucket: #{bucket_name}"
    rescue Aws::S3::Errors::ServiceError => e
      puts "Error checking CORS: #{e.message}"
      exit 1
    end
  end
end
