Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins "http://localhost:5173",
            "http://localhost:5174",
            "http://localhost:3000",
            "http://100.97.169.52:5173",
            "http://100.97.169.52:5174",
            "http://100.97.169.52:3000",
            "http://192.168.1.68:5173",
            "http://192.168.1.68:5174",
            "http://192.168.1.68:3000",
            "http://192.168.86.194:5173",
            "http://192.168.86.194:5174",
            "http://scp-25-dev.oknotok.com:5173",
            "http://scp-25-dev.oknotok.com:5174",
            "http://scp-25.oknotok.com:5173",
            "http://scp-25.oknotok.com:5174",
            "https://scp-25-dev.oknotok.com",
            "https://scp-25.oknotok.com"

    resource "*",
      headers: :any,
      methods: [ :get, :post, :put, :patch, :delete, :options, :head ],
      credentials: true
  end
end
