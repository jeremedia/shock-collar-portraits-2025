# # Guarded workaround for macOS segfault in libvips loader introspection
# # Context: segfault at ImageProcessing::Vips::Processor::Utils.select_valid_loader_options
# # when calling Vips.vips_foreign_find_load. This patch bypasses the preflight
# # introspection when explicitly enabled via ENV and on Darwin.
# 
# if ENV["VIPS_SKIP_LOADER_INTROSPECTION"] == "1" && RUBY_PLATFORM.include?("darwin")
  # begin
  #   require "image_processing/vips"
  # rescue LoadError
  #   # The gem will be required later by Active Storage; we’ll patch once loaded.
  # end
# 
  # patch_fn = proc do
  #   utils = ::ImageProcessing::Vips::Processor::Utils rescue nil
  #   next unless utils
# 
  #   # Redefine the two utils methods to skip vips_foreign_find_* when enabled.
  #   utils.module_eval do
  #     module_function
# 
  #     def select_valid_loader_options(source_path, options)
  #       # Skip loader introspection entirely under the guarded workaround,
  #       # but strip options known to be invalid for common single-frame formats.
  #       opts = options.dup
  #       begin
  #         ext = File.extname(source_path.to_s).downcase
  #         # Only a subset of formats support :page or multi-frame selection.
  #         multi_frame_exts = %w[.gif .tif .tiff .pdf .heic .heif .avif .webp .svg]
  #         opts.delete(:page) unless multi_frame_exts.include?(ext)
  #       rescue => e
  #         Rails.logger.warn("VIPS workaround: error filtering loader opts: #{e.class}: #{e.message}") if defined?(Rails)
  #       end
  #       opts
  #     rescue => e
  #       # If anything unexpected happens, fall back to returning options.
  #       Rails.logger.warn("VIPS workaround: loader introspection skipped due to #{e.class}: #{e.message}") if defined?(Rails)
  #       options
  #     end
# 
  #     def select_valid_saver_options(destination_path, options)
  #       # Also skip saver introspection to avoid similar crashes.
  #       options
  #     rescue => e
  #       Rails.logger.warn("VIPS workaround: saver introspection skipped due to #{e.class}: #{e.message}") if defined?(Rails)
  #       options
  #     end
  #   end
# 
  #   Rails.logger.info("VIPS workaround enabled: skipping vips_foreign_find_(load|save) introspection on macOS") if defined?(Rails)
  # end
# 
  # if defined?(::ImageProcessing::Vips::Processor::Utils)
  #   patch_fn.call
  # else
  #   # If the gem wasn't loaded yet, patch right after initialization when it is.
  #   Rails.application.config.to_prepare { patch_fn.call }
  # end
# end
