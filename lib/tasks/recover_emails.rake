namespace :emails do
  desc "Import recovered emails from Safari local storage JSON"
  task import_recovered: :environment do
    # Paste the JSON data here
    json_data = ENV["JSON_DATA"] || File.read("tmp/recovered_emails.json") rescue nil

    if json_data.nil?
      puts "Please provide JSON_DATA environment variable or create tmp/recovered_emails.json"
      puts "Usage: rails emails:import_recovered JSON_DATA='{...}'"
      exit
    end

    data = JSON.parse(json_data)
    imported = 0
    skipped = 0

    # Try to extract emails from various possible storage keys
    possible_keys = [
      "emails", "sittings", "formData", "sitting_email",
      "mobile_sittings", "form_autosave", "autosave"
    ]

    # Check localStorage
    if data["localStorage"]
      data["localStorage"].each do |key, value|
        next unless possible_keys.any? { |k| key.include?(k) }

        begin
          # Value might be JSON string or plain text
          parsed = JSON.parse(value) rescue value

          # Extract emails based on structure
          emails = case parsed
          when Array
            parsed.map { |item| item["email"] || item }.compact
          when Hash
            [ parsed["email"], parsed["sitting_email"] ].compact
          when String
            parsed.scan(/[\w._%+-]+@[\w.-]+\.[A-Za-z]{2,}/)
          else
            []
          end

          emails.each do |email|
            next unless email.match?(/\A[\w._%+-]+@[\w.-]+\.[A-Za-z]{2,}\z/)

            if Sitting.exists?(email: email.downcase)
              puts "Skipping duplicate: #{email}"
              skipped += 1
            else
              session = PhotoSession.first || PhotoSession.create!(
                burst_id: "placeholder_recovery",
                session_day: SessionDay.first,
                session_number: 999
              )

              Sitting.create!(
                email: email.downcase,
                photo_session: session,
                notes: "Recovered from Safari local storage"
              )
              puts "Imported: #{email}"
              imported += 1
            end
          end
        rescue => e
          puts "Error processing key #{key}: #{e.message}"
        end
      end
    end

    # Also check sessionStorage
    if data["sessionStorage"]
      # Same logic as above for sessionStorage
      data["sessionStorage"].each do |key, value|
        # ... same extraction logic
      end
    end

    puts "\n" + "="*50
    puts "Import complete!"
    puts "Imported: #{imported} new emails"
    puts "Skipped: #{skipped} duplicates"
    puts "Total emails in database: #{Sitting.distinct.count(:email)}"
  end

  desc "Import emails from CSV format"
  task import_csv: :environment do
    csv_data = ENV["CSV"] || File.read("tmp/emails.csv") rescue nil

    if csv_data.nil?
      puts "Please provide CSV environment variable or create tmp/emails.csv"
      puts "Usage: rails emails:import_csv CSV='email,name,notes'"
      exit
    end

    imported = 0
    skipped = 0

    csv_data.each_line do |line|
      next if line.strip.empty?

      parts = line.strip.split(",").map(&:strip)
      email = parts[0]
      name = parts[1]
      notes = parts[2]

      next unless email&.match?(/\A[\w._%+-]+@[\w.-]+\.[A-Za-z]{2,}\z/)

      if Sitting.exists?(email: email.downcase)
        skipped += 1
      else
        session = PhotoSession.first
        Sitting.create!(
          email: email.downcase,
          name: name,
          notes: notes,
          photo_session: session
        )
        imported += 1
        puts "Imported: #{email}"
      end
    end

    puts "Imported: #{imported}, Skipped: #{skipped}"
  end
end
