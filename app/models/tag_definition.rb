class TagDefinition < ApplicationRecord
  CATEGORIES = %w[expression appearance accessory other].freeze

  # Validations
  validates :name, presence: true, uniqueness: true
  validates :category, presence: true, inclusion: { in: CATEGORIES }
  validates :display_order, presence: true, numericality: { greater_than_or_equal_to: 0 }

  # Scopes
  scope :active, -> { where(active: true) }
  scope :by_category, ->(category) { where(category: category) }
  scope :ordered, -> { order(:display_order, :name) }

  # Class methods for easy access
  def self.expression_tags
    active.by_category("expression").ordered
  end

  def self.appearance_tags
    active.by_category("appearance").ordered
  end

  def self.accessory_tags
    active.by_category("accessory").ordered
  end

  def self.cached_tags_by_category(category)
    Rails.cache.fetch("tag_definitions/#{category}", expires_in: 1.hour) do
      active.by_category(category).ordered.to_a
    end
  end

  # Instance methods
  def display_text
    display_name.presence || name.humanize
  end

  def tag_with_emoji
    emoji.present? ? "#{emoji} #{display_text}" : display_text
  end

  # Clear cache when tags are modified
  after_commit :clear_cache

  private

  def clear_cache
    # Clear specific category caches
    TagDefinition::CATEGORIES.each do |category|
      Rails.cache.delete("tag_definitions/#{category}")
    end
  end
end
