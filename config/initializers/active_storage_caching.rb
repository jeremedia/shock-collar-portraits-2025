# Configure Active Storage to use proper cache headers for proxy responses
# This enables service worker caching of images

Rails.application.config.after_initialize do
  # Configure cache headers for Active Storage proxy controllers

  # For blob proxy controller
  if defined?(ActiveStorage::Blobs::ProxyController)
    ActiveStorage::Blobs::ProxyController.class_eval do
      before_action :set_cache_headers

      private

      def set_cache_headers
        expires_in 7.days, public: true
        response.headers["Vary"] = "Accept"
      end
    end
  end

  # For representations proxy controller
  if defined?(ActiveStorage::Representations::ProxyController)
    ActiveStorage::Representations::ProxyController.class_eval do
      before_action :set_cache_headers

      private

      def set_cache_headers
        expires_in 7.days, public: true
        response.headers["Vary"] = "Accept"
      end
    end
  end

  # For representations redirect controller (used by rails_representation_url)
  if defined?(ActiveStorage::Representations::RedirectController)
    ActiveStorage::Representations::RedirectController.class_eval do
      before_action :set_cache_headers

      private

      def set_cache_headers
        expires_in 7.days, public: true
        response.headers["Vary"] = "Accept"
      end
    end
  end
end
