# Configure CORS headers for Active Storage to enable proper caching
Rails.application.config.after_initialize do
  # Add CORS headers to Active Storage responses
  ActiveStorage::Blobs::ProxyController.class_eval do
    before_action :set_cors_headers
    
    private
    
    def set_cors_headers
      headers['Access-Control-Allow-Origin'] = '*'
      headers['Access-Control-Allow-Methods'] = 'GET, HEAD, OPTIONS'
      headers['Access-Control-Allow-Headers'] = 'Origin, Content-Type, Accept'
      headers['Access-Control-Max-Age'] = '3600'
      # Allow the response to be cached
      headers['Cache-Control'] = 'public, max-age=3600, immutable'
    end
  end
  
  ActiveStorage::Representations::ProxyController.class_eval do
    before_action :set_cors_headers
    
    private
    
    def set_cors_headers
      headers['Access-Control-Allow-Origin'] = '*'
      headers['Access-Control-Allow-Methods'] = 'GET, HEAD, OPTIONS'
      headers['Access-Control-Allow-Headers'] = 'Origin, Content-Type, Accept'
      headers['Access-Control-Max-Age'] = '3600'
      headers['Cache-Control'] = 'public, max-age=3600, immutable'
    end
  end if defined?(ActiveStorage::Representations::ProxyController)
end