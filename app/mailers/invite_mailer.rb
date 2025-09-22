class InviteMailer < ApplicationMailer
  # Set from address to your oknotok.com email
  default from: "jeremy@oknotok.com",
          reply_to: "jeremy@oknotok.com"

  def portrait_ready(sitting)
    @sitting = sitting
    @photo_session = sitting.photo_session
    @playa_name = sitting.playa_name.presence || sitting.legal_name.presence || "Friend"
    @portrait_url = gallery_url(@photo_session)
    @hero_url = heroes_url
    @stats_url = stats_url

    # Personalized subject line
    subject = "#{@playa_name}, your Shock Collar Portrait from OKNOTOK 2025 is ready!"

    # Track opens with a pixel (if using Postmark or SendGrid)
    headers["X-PM-Tag"] = "portrait-invite"

    mail(
      to: sitting.email,
      subject: subject
    )
  end

  # Batch send method with rate limiting
  def self.send_all_invites(test_mode: false, limit: nil)
    sittings = Sitting.where.not(email: [ nil, "" ])
                      .joins(:photo_session)
                      .distinct

    sittings = sittings.limit(limit) if limit

    results = {
      sent: [],
      failed: [],
      skipped: []
    }

    sittings.find_each.with_index do |sitting, index|
      begin
        # Skip if no photos in session
        if sitting.photo_session.photos.empty?
          results[:skipped] << { email: sitting.email, reason: "No photos in session" }
          next
        end

        if test_mode
          puts "[TEST] Would send to: #{sitting.email} (#{sitting.playa_name})"
          results[:sent] << sitting.email
        else
          InviteMailer.portrait_ready(sitting).deliver_later
          results[:sent] << sitting.email
          puts "[#{index + 1}] Sent to: #{sitting.email}"

          # Rate limit: 10 emails per second (Postmark limit)
          sleep(0.1) if index % 10 == 0
        end
      rescue => e
        results[:failed] << { email: sitting.email, error: e.message }
        puts "[ERROR] Failed to send to #{sitting.email}: #{e.message}"
      end
    end

    results
  end
end
