namespace :photos do
  desc "Transfer original photos from MacBook Air to organized structure"
  task transfer_from_air: :environment do
    require "open3"
    require "json"

    air_host = "jeremy@jer-air"
    air_base_path = "/Users/jeremy/Desktop/OKNOTOK/OK-SHOCK-25"
    local_base_path = Rails.root.join("session_originals")

    # Create a mapping of filenames to their destination folders
    puts "Building transfer map..."
    transfer_map = {}
    missing_files = []

    Photo.includes(:photo_session).find_each do |photo|
      next unless photo.photo_session&.started_at && photo.filename

      day = photo.photo_session.started_at.strftime("%A").downcase
      next unless %w[monday tuesday wednesday thursday friday].include?(day)

      folder_name = File.basename(photo.filename, ".*")
      destination = local_base_path.join(day, folder_name)

      transfer_map[photo.filename] = {
        destination: destination.to_s,
        day: day,
        folder_name: folder_name
      }
    end

    puts "Need to transfer #{transfer_map.keys.length} files"

    # Step 1: Find all available files on the Air
    puts "\nScanning MacBook Air for photos..."
    cmd = "ssh #{air_host} 'find #{air_base_path} -type f \\( -name \"*.JPG\" -o -name \"*.HEIC\" \\) 2>/dev/null'"

    air_files = {}
    stdout, stderr, status = Open3.capture3(cmd)

    if status.success?
      stdout.each_line do |line|
        path = line.strip
        filename = File.basename(path)
        air_files[filename] = path
      end
      puts "Found #{air_files.keys.length} files on Air"
    else
      puts "Error scanning Air: #{stderr}"
      exit 1
    end

    # Step 2: Create transfer commands
    transfers = []
    found_count = 0

    transfer_map.each do |filename, info|
      if air_files[filename]
        transfers << {
          source: air_files[filename],
          destination: info[:destination],
          filename: filename,
          day: info[:day]
        }
        found_count += 1
      else
        missing_files << filename
      end
    end

    puts "Matched #{found_count}/#{transfer_map.keys.length} files"

    if missing_files.any?
      puts "\n⚠️  Missing #{missing_files.length} files:"
      missing_files.first(10).each { |f| puts "  - #{f}" }
      puts "  ... and #{missing_files.length - 10} more" if missing_files.length > 10
    end

    # Step 3: Execute transfers
    if transfers.any?
      puts "\n📦 Starting transfer of #{transfers.length} files..."

      # Group by day for progress tracking
      by_day = transfers.group_by { |t| t[:day] }

      by_day.each do |day, day_transfers|
        puts "\n#{day.capitalize}: #{day_transfers.length} files"

        day_transfers.each_with_index do |transfer, index|
          # Use rsync for efficient transfer with progress
          destination_dir = transfer[:destination]
          source_path = transfer[:source]
          filename = transfer[:filename]

          # Ensure destination directory exists
          FileUtils.mkdir_p(destination_dir)

          # Transfer file
          cmd = "rsync -avz --progress #{air_host}:'#{source_path}' '#{destination_dir}/'"

          if index % 100 == 0
            puts "  Progress: #{index}/#{day_transfers.length} (#{filename})"
          end

          success = system(cmd, out: File::NULL, err: File::NULL)

          unless success
            puts "  ⚠️  Failed to transfer: #{filename}"
          end
        end

        puts "  ✅ Completed #{day.capitalize}"
      end
    end

    # Step 4: Verify transfer
    puts "\n🔍 Verifying transfer..."
    verification_count = 0

    transfers.each do |transfer|
      local_file = File.join(transfer[:destination], transfer[:filename])
      if File.exist?(local_file)
        verification_count += 1
      end
    end

    puts "✅ Successfully transferred: #{verification_count}/#{transfers.length} files"

    # Generate report
    report_path = local_base_path.join("transfer_report_#{Time.now.strftime('%Y%m%d_%H%M%S')}.json")
    report = {
      timestamp: Time.now.iso8601,
      total_needed: transfer_map.keys.length,
      found_on_air: found_count,
      transferred: verification_count,
      missing: missing_files,
      transfers: transfers
    }

    File.write(report_path, JSON.pretty_generate(report))
    puts "\n📄 Report saved to: #{report_path}"
  end

  desc "Quick scan to check what files are available on Air"
  task scan_air: :environment do
    air_host = "jeremy@jer-air"
    air_base_path = "/Users/jeremy/Desktop/OKNOTOK/OK-SHOCK-25"

    puts "Scanning MacBook Air..."

    # Check each directory
    directories = [
      "card_download_1",
      "thursday_friday_temp",
      "iphone_day_one_shots"
    ]

    directories.each do |dir|
      cmd = "ssh #{air_host} 'find #{air_base_path}/#{dir} -type f \\( -name \"*.JPG\" -o -name \"*.HEIC\" \\) 2>/dev/null | wc -l'"
      count = `#{cmd}`.strip
      puts "#{dir}: #{count} files"

      # Sample first few files
      cmd = "ssh #{air_host} 'find #{air_base_path}/#{dir} -type f \\( -name \"*.JPG\" -o -name \"*.HEIC\" \\) 2>/dev/null | head -5'"
      puts `#{cmd}`.split("\n").map { |f| "  → #{File.basename(f)}" }.join("\n")
      puts
    end
  end

  desc "Parallel transfer using xargs for speed"
  task fast_transfer: :environment do
    air_host = "jeremy@jer-air"
    air_base_path = "/Users/jeremy/Desktop/OKNOTOK/OK-SHOCK-25"
    local_base_path = Rails.root.join("session_originals")

    # Generate transfer list
    transfer_list = []

    Photo.includes(:photo_session).find_each do |photo|
      next unless photo.photo_session&.started_at && photo.filename

      day = photo.photo_session.started_at.strftime("%A").downcase
      next unless %w[monday tuesday wednesday thursday friday].include?(day)

      folder_name = File.basename(photo.filename, ".*")
      destination = local_base_path.join(day, folder_name)

      transfer_list << "#{photo.filename}:#{destination}"
    end

    # Write transfer list to file
    list_file = local_base_path.join("transfer_list.txt")
    File.write(list_file, transfer_list.join("\n"))

    # Create parallel transfer script
    script_path = local_base_path.join("parallel_transfer.sh")

    script_content = <<~BASH
      #!/bin/bash

      AIR_HOST="#{air_host}"
      AIR_BASE="#{air_base_path}"

      # Function to transfer a single file
      transfer_file() {
        local filename="$1"
        local destination="$2"

        # Find the file on Air
        source=$(ssh $AIR_HOST "find $AIR_BASE -name '$filename' -type f 2>/dev/null | head -1")

        if [ -n "$source" ]; then
          mkdir -p "$destination"
          rsync -az $AIR_HOST:"$source" "$destination/"
          echo "✓ $filename"
        else
          echo "✗ $filename (not found)"
        fi
      }

      export -f transfer_file
      export AIR_HOST AIR_BASE

      # Process in parallel (8 concurrent transfers)
      cat #{list_file} | while IFS=':' read -r filename destination; do
        echo "$filename:$destination"
      done | xargs -P 8 -I {} bash -c 'IFS=":" read -r f d <<< "{}"; transfer_file "$f" "$d"'
    BASH

    File.write(script_path, script_content)
    FileUtils.chmod(0755, script_path)

    puts "Created parallel transfer script: #{script_path}"
    puts "Run it with: #{script_path}"
  end
end
