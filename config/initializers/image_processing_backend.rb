# Log the chosen image processing backend at boot and basic libvips info when available.

Rails.application.config.to_prepare do
  processor = Rails.application.config.active_storage.variant_processor
  Rails.logger.info("ActiveStorage variant processor: #{processor}")

  if processor == :vips && defined?(Vips)
    begin
      Rails.logger.info("libvips version: #{Vips.version_string}; concurrency=#{Vips.concurrency}")
    rescue => e
      Rails.logger.warn("Unable to query libvips: #{e.message}")
    end
  end
end

