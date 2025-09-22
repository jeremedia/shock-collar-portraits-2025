# Configure libvips (ruby-vips) concurrency to avoid native crashes under heavy multi-threaded load.
# You can raise this on stable environments; start conservative on macOS dev.

# Optional eager-load: enable only if explicitly requested.
# In clustered Puma, preloading native libs before fork can cause instability;
# prefer loading in each worker (see config/puma.rb :on_worker_boot).
begin
  require "vips" if ENV["VIPS_EAGER_LOAD"] == "1"
rescue LoadError
  # ruby-vips not available; skip
end

begin
  if defined?(Vips)
    # Conservative concurrency by default for stability on macOS
    Vips.concurrency = Integer(ENV.fetch("VIPS_CONCURRENCY", 1))
    # Limit cache to avoid high memory pressure under load
    Vips.cache_set_max(Integer(ENV.fetch("VIPS_CACHE_MAX", 100)))
    Vips.cache_set_max_mem(Integer(ENV.fetch("VIPS_CACHE_MAX_MEM", 256 * 1024 * 1024)))
  end
rescue => e
  Rails.logger.warn("Vips configuration failed: #{e.message}") if defined?(Rails)
end
