module ApplicationHelper
  def github_release_version
    Rails.cache.fetch("github_release_version", expires_in: 1.minute) do
      begin
        require "net/http"
        require "json"

        uri = URI("https://api.github.com/repos/jeremedia/shock-collar-portraits-2025/releases/latest")
        response = Net::HTTP.get_response(uri)

        if response.code == "200"
          data = JSON.parse(response.body)
          data["tag_name"] || "dev"
        else
          "dev"
        end
      rescue => e
        Rails.logger.error "Failed to fetch GitHub release version: #{e.message}"
        "dev"
      end
    end
  end
end
