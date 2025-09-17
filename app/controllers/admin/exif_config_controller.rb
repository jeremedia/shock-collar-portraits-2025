class Admin::ExifConfigController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_admin!

  def index
    # Get a sample photo with comprehensive EXIF data for configuration
    @sample_photo = Photo.joins(:image_attachment)
                         .where.not(exif_data: [nil, {}])
                         .where("JSON_EXTRACT(exif_data, '$.Camera') IS NOT NULL")
                         .first

    if @sample_photo.nil?
      redirect_to admin_dashboard_path, alert: 'No photos with EXIF data found. Please extract EXIF data first.'
      return
    end

    # Get current configuration
    @current_config = AppSetting.exif_visible_fields

    # Get all available fields from the sample photo
    @available_fields = extract_available_fields(@sample_photo.exif_data)
  end

  def update
    begin
      # Parse the configuration from form params
      config = parse_config_from_params

      # Save the configuration
      AppSetting.set_exif_visible_fields(config)

      redirect_to admin_exif_config_index_path, notice: 'EXIF field configuration saved successfully!'
    rescue => e
      Rails.logger.error "Failed to save EXIF config: #{e.message}"
      redirect_to admin_exif_config_index_path, alert: "Failed to save configuration: #{e.message}"
    end
  end

  def reset
    # Reset to default configuration
    AppSetting.set_exif_visible_fields(AppSetting.default_exif_fields)
    redirect_to admin_exif_config_index_path, notice: 'EXIF configuration reset to defaults!'
  end

  private

  def ensure_admin!
    redirect_to root_path unless current_user&.admin?
  end

  def extract_available_fields(exif_data)
    available = {}
    return available unless exif_data.is_a?(Hash)

    # Organize all available fields by category
    exif_data.each do |category, fields|
      next unless fields.is_a?(Hash)

      available[category] = fields.keys.sort
    end

    available
  end

  def parse_config_from_params
    config = {}

    params.each do |key, value|
      # Look for parameters like "Camera_Make", "Exposure_ISO", etc.
      if key.match(/^([^_]+)_(.+)$/) && value == '1'
        category = $1
        field = $2

        config[category] ||= []
        config[category] << field
      end
    end

    config
  end
end