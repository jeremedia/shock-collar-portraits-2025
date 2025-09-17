class Ahoy::Store < Ahoy::DatabaseStore
end

# set to true for JavaScript tracking
Ahoy.api = false

# set to true for geocoding (and add the geocoder gem to your Gemfile)
# we recommend configuring local geocoding as well
# see https://github.com/ankane/ahoy#geocoding
Ahoy.geocode = false

# Cookie settings for privacy
Ahoy.cookies = :none  # Don't set cookies, use server-side only
Ahoy.visit_duration = 30.minutes

# Track authenticated users
Ahoy.user_method = :current_user

# Mask IPs for privacy (store only first 3 octets)
Ahoy.mask_ips = true

# Track these controllers (nil = all)
Ahoy.track_bots = false

# Exclude admin paths from tracking to reduce noise
Ahoy.exclude_method = lambda do |controller, request|
  request.path.start_with?('/admin/') && !request.path.include?('/admin/dashboard')
end