namespace :tags do
  desc "Seed initial tag definitions from hardcoded lists"
  task seed: :environment do
    puts "Seeding tag definitions..."

    # Expression tags with emojis
    expression_tags = [
      { name: "smiling", emoji: "😊", order: 10 },
      { name: "serious", emoji: "😐", order: 20 },
      { name: "laughing", emoji: "😂", order: 30 },
      { name: "surprised", emoji: "😮", order: 40 },
      { name: "shocked", emoji: "😱", order: 50 },
      { name: "confused", emoji: "😕", order: 60 },
      { name: "orgasm", emoji: "🤯", order: 70 },
      { name: "pain", emoji: "😣", order: 80 },
      { name: "stoic", emoji: "🗿", order: 90 },
      { name: "jazz hands", emoji: "🤗", display_name: "Jazz Hands", order: 100 }
    ]

    # Appearance tags
    appearance_tags = [
      { name: "blonde", emoji: "👱", order: 10 },
      { name: "brunette", emoji: "👤", order: 20 },
      { name: "redhead", emoji: "🦰", order: 30 },
      { name: "bald", emoji: "👨‍🦲", order: 40 },
      { name: "extensions", order: 50 },
      { name: "beard", emoji: "🧔", order: 60 },
      { name: "mustache", order: 70 },
      { name: "tattoos", emoji: "🎨", order: 80 },
      { name: "piercings", emoji: "💍", order: 90 },
      { name: "topless", order: 100 },
      { name: "eyes closed", emoji: "😌", display_name: "Eyes Closed", order: 110 },
      { name: "mouth open", emoji: "😮", display_name: "Mouth Open", order: 120 }
    ]

    # Accessory tags
    accessory_tags = [
      { name: "hat", emoji: "🎩", order: 10 },
      { name: "sunglasses", emoji: "🕶️", order: 20 },
      { name: "goggles", emoji: "🥽", order: 30 },
      { name: "glasses", emoji: "👓", order: 40 },
      { name: "mask", emoji: "😷", order: 50 },
      { name: "costume", emoji: "🎭", order: 60 },
      { name: "jewelry", emoji: "💎", order: 70 },
      { name: "body paint", emoji: "🎨", display_name: "Body Paint", order: 80 }
    ]

    # Create expression tags
    expression_tags.each do |tag_data|
      tag = TagDefinition.find_or_initialize_by(name: tag_data[:name])
      tag.assign_attributes(
        category: "expression",
        emoji: tag_data[:emoji],
        display_name: tag_data[:display_name],
        display_order: tag_data[:order],
        active: true
      )
      if tag.save
        puts "  ✓ Created/Updated expression tag: #{tag.name}"
      else
        puts "  ✗ Failed to create expression tag: #{tag.name} - #{tag.errors.full_messages.join(', ')}"
      end
    end

    # Create appearance tags
    appearance_tags.each do |tag_data|
      tag = TagDefinition.find_or_initialize_by(name: tag_data[:name])
      tag.assign_attributes(
        category: "appearance",
        emoji: tag_data[:emoji],
        display_name: tag_data[:display_name],
        display_order: tag_data[:order],
        active: true
      )
      if tag.save
        puts "  ✓ Created/Updated appearance tag: #{tag.name}"
      else
        puts "  ✗ Failed to create appearance tag: #{tag.name} - #{tag.errors.full_messages.join(', ')}"
      end
    end

    # Create accessory tags
    accessory_tags.each do |tag_data|
      tag = TagDefinition.find_or_initialize_by(name: tag_data[:name])
      tag.assign_attributes(
        category: "accessory",
        emoji: tag_data[:emoji],
        display_name: tag_data[:display_name],
        display_order: tag_data[:order],
        active: true
      )
      if tag.save
        puts "  ✓ Created/Updated accessory tag: #{tag.name}"
      else
        puts "  ✗ Failed to create accessory tag: #{tag.name} - #{tag.errors.full_messages.join(', ')}"
      end
    end

    puts "\nTag seeding complete!"
    puts "Total tags: #{TagDefinition.count}"
    puts "  Expression: #{TagDefinition.by_category('expression').count}"
    puts "  Appearance: #{TagDefinition.by_category('appearance').count}"
    puts "  Accessory: #{TagDefinition.by_category('accessory').count}"
  end

  desc "Clear all tag definitions"
  task clear: :environment do
    count = TagDefinition.destroy_all.count
    puts "Cleared #{count} tag definitions"
  end

  desc "Reset tags (clear and reseed)"
  task reset: [ :clear, :seed ]
end
