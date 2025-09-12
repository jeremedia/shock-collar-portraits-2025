namespace :s3 do
  desc "Create S3 bucket if it doesn't exist"
  task create_bucket: :environment do
    require 'aws-sdk-s3'
    
    bucket_name = Rails.application.credentials.dig(:aws, :bucket) || 'shock-collar-portraits-2025'
    region = Rails.application.credentials.dig(:aws, :region) || 'us-west-2'
    
    s3_client = Aws::S3::Client.new(
      access_key_id: Rails.application.credentials.dig(:aws, :access_key_id),
      secret_access_key: Rails.application.credentials.dig(:aws, :secret_access_key),
      region: region
    )
    
    begin
      # Check if bucket exists
      s3_client.head_bucket(bucket: bucket_name)
      puts "✅ Bucket '#{bucket_name}' already exists"
    rescue Aws::S3::Errors::NotFound
      # Create the bucket
      puts "Creating bucket '#{bucket_name}' in region '#{region}'..."
      
      create_params = { bucket: bucket_name }
      # us-east-1 doesn't need location constraint
      if region != 'us-east-1'
        create_params[:create_bucket_configuration] = {
          location_constraint: region
        }
      end
      
      s3_client.create_bucket(create_params)
      
      # Enable versioning for backup
      s3_client.put_bucket_versioning(
        bucket: bucket_name,
        versioning_configuration: {
          status: 'Enabled'
        }
      )
      
      # Configure CORS for web access
      s3_client.put_bucket_cors(
        bucket: bucket_name,
        cors_configuration: {
          cors_rules: [
            {
              allowed_headers: ['*'],
              allowed_methods: ['GET', 'PUT', 'POST', 'DELETE', 'HEAD'],
              allowed_origins: [
                'http://localhost:5173',
                'http://localhost:5174', 
                'http://localhost:4000',
                'http://100.97.169.52:5173',
                'http://100.97.169.52:4000',
                'http://scp-25-dev.oknotok.com',
                'http://scp-25-dev.oknotok.com:4000',
                'https://scp-25.oknotok.com',
                'https://scp-25-dev.oknotok.com'
              ],
              expose_headers: ['ETag'],
              max_age_seconds: 3600
            }
          ]
        }
      )
      
      puts "✅ Bucket '#{bucket_name}' created successfully!"
      puts "   - Versioning: Enabled"
      puts "   - CORS: Configured"
      puts "   - Region: #{region}"
      
    rescue Aws::S3::Errors::BucketAlreadyExists, Aws::S3::Errors::BucketAlreadyOwnedByYou
      puts "✅ Bucket '#{bucket_name}' already exists and is owned by you"
    rescue => e
      puts "❌ Error creating bucket: #{e.message}"
      puts "   #{e.class}"
    end
  end
  
  desc "Update CORS policy for existing S3 bucket"
  task update_cors: :environment do
    require 'aws-sdk-s3'
    
    bucket_name = Rails.application.credentials.dig(:aws, :bucket) || 'shock-collar-portraits-2025'
    region = Rails.application.credentials.dig(:aws, :region) || 'us-west-2'
    
    s3_client = Aws::S3::Client.new(
      access_key_id: Rails.application.credentials.dig(:aws, :access_key_id),
      secret_access_key: Rails.application.credentials.dig(:aws, :secret_access_key),
      region: region
    )
    
    begin
      puts "Updating CORS policy for bucket '#{bucket_name}'..."
      
      # Configure CORS for web access
      s3_client.put_bucket_cors(
        bucket: bucket_name,
        cors_configuration: {
          cors_rules: [
            {
              allowed_headers: ['*'],
              allowed_methods: ['GET', 'PUT', 'POST', 'DELETE', 'HEAD'],
              allowed_origins: [
                'http://localhost:5173',
                'http://localhost:5174', 
                'http://localhost:4000',
                'http://100.97.169.52:5173',
                'http://100.97.169.52:4000',
                'http://scp-25-dev.oknotok.com',
                'http://scp-25-dev.oknotok.com:4000',
                'https://scp-25.oknotok.com',
                'https://scp-25-dev.oknotok.com'
              ],
              expose_headers: ['ETag'],
              max_age_seconds: 3600
            }
          ]
        }
      )
      
      puts "✅ CORS policy updated successfully!"
      
    rescue => e
      puts "❌ Error updating CORS: #{e.message}"
      puts "   #{e.class}"
    end
  end
end