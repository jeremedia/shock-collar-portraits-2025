class AppSetting < ApplicationRecord
  validates :key, presence: true, uniqueness: true

  # Serialize value as JSON
  serialize :value, coder: JSON

  # Class methods for easy access
  def self.get(key, default = nil)
    setting = find_by(key: key)
    setting&.value || default
  end

  def self.set(key, value)
    setting = find_or_initialize_by(key: key)
    setting.value = value
    setting.save!
    setting
  end

  # EXIF-specific methods
  def self.exif_visible_fields
    get("exif_visible_fields", default_exif_fields)
  end

  def self.set_exif_visible_fields(fields)
    set("exif_visible_fields", fields)
  end

  # Default EXIF fields to show (sensible defaults for photo selection)
  def self.default_exif_fields
    {
      "Camera" => %w[Make Model LensModel SerialNumber],
      "Exposure" => %w[ExposureTime FNumber ISO ExposureCompensation Flash WhiteBalance],
      "Image" => %w[ImageWidth ImageHeight DateTimeOriginal Orientation],
      "GPS" => %w[GPSLatitude GPSLongitude],
      "Other" => %w[FocalLength OwnerName]
    }
  end
end
