# Configure CORS headers for Active Storage
# NOTE: When using S3 with direct access, CORS should be configured on the S3 bucket
# itself to avoid duplicate headers. This initializer is commented out to prevent
# conflicts with S3's CORS configuration.

# Rails.application.config.after_initialize do
#   # Only add CORS headers if NOT using S3 direct uploads
#   # S3 handles its own CORS headers and adding them here causes duplicates
#
#   ActiveStorage::Blobs::ProxyController.class_eval do
#     before_action :set_cors_headers
#
#     private
#
#     def set_cors_headers
#       headers['Access-Control-Allow-Origin'] = '*'
#       headers['Access-Control-Allow-Methods'] = 'GET, HEAD, OPTIONS'
#       headers['Access-Control-Allow-Headers'] = 'Origin, Content-Type, Accept'
#       headers['Access-Control-Max-Age'] = '3600'
#       # Allow the response to be cached
#       headers['Cache-Control'] = 'public, max-age=3600, immutable'
#     end
#   end
#
#   ActiveStorage::Representations::ProxyController.class_eval do
#     before_action :set_cors_headers
#
#     private
#
#     def set_cors_headers
#       headers['Access-Control-Allow-Origin'] = '*'
#       headers['Access-Control-Allow-Methods'] = 'GET, HEAD, OPTIONS'
#       headers['Access-Control-Allow-Headers'] = 'Origin, Content-Type, Accept'
#       headers['Access-Control-Max-Age'] = '3600'
#       headers['Cache-Control'] = 'public, max-age=3600, immutable'
#     end
#   end if defined?(ActiveStorage::Representations::ProxyController)
# end