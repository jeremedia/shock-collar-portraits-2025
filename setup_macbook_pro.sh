#!/bin/bash

# Setup script for MacBook Pro development environment
# Run this on the MacBook Pro after cloning the repo

echo "🚀 Setting up OKNOTOK Shock Collar Portraits on MacBook Pro..."

# Navigate to backend directory
cd /Volumes/jer4TBv3/shock-collar-portraits-2025/backend

# Install Ruby dependencies
echo "📦 Installing Ruby gems..."
bundle install

# Install Node dependencies
echo "📦 Installing Node packages..."
npm install

# Setup database
echo "🗄️ Setting up database..."
rails db:create 2>/dev/null || true  # Create if doesn't exist
rails db:migrate                      # Run migrations
rails db:seed                          # Seed admin user

# Create .env file if it doesn't exist
if [ ! -f .env ]; then
  echo "📝 Creating .env file..."
  cat > .env << 'EOF'
# Development environment variables
GMAIL_USERNAME=mrok@oknotok.com
GMAIL_APP_PASSWORD=your-app-password-here
RAILS_HOST=localhost
EOF
  echo "⚠️  Don't forget to update .env with your Gmail app password!"
  echo "💡  Prefer credentials? Run \"bin/rails credentials:edit\" and add smtp.username/app_password there."
fi

# Create storage directories if needed
mkdir -p storage
mkdir -p tmp/pids
mkdir -p log

# Build CSS
echo "🎨 Building Tailwind CSS..."
rails tailwindcss:build

echo "✅ Setup complete!"
echo ""
echo "To start the development server, run:"
echo "  cd /Volumes/jer4TBv3/shock-collar-portraits-2025/backend"
echo "  bin/dev"
echo ""
echo "The app will be available at http://localhost:4000"
echo ""
echo "⚠️  Note: You'll need to transfer any photo files from Active Storage separately"
echo "   Photos are typically stored in storage/ directory"
