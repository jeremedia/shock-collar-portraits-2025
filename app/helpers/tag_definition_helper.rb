module TagDefinitionHelper
  def expression_tag_options
    TagDefinition.cached_tags_by_category('expression').map do |tag|
      { value: tag.name, label: tag.tag_with_emoji, display: tag.display_text }
    end
  end

  def appearance_tag_options
    TagDefinition.cached_tags_by_category('appearance').map do |tag|
      { value: tag.name, label: tag.tag_with_emoji, display: tag.display_text }
    end
  end

  def accessory_tag_options
    TagDefinition.cached_tags_by_category('accessory').map do |tag|
      { value: tag.name, label: tag.tag_with_emoji, display: tag.display_text }
    end
  end

  def tags_for_category(category)
    TagDefinition.cached_tags_by_category(category)
  end

  def tag_button_classes(active = false)
    base_classes = "w-full px-2 py-1 text-xs font-medium border rounded hover:border-yellow-500 transition-all text-left"
    if active
      "#{base_classes} bg-yellow-600 text-black border-yellow-600"
    else
      "#{base_classes} bg-gray-800 text-gray-400 border-gray-700"
    end
  end
end