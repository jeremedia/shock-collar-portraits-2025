# OKNOTOK Shock Collar Portraits - Burning Man 2025

A Rails 8 web application for managing, viewing, and selecting portrait photos from the OKNOTOK Shock Collar Portraits project at Burning Man 2025.

## 📸 Project Overview

This system manages 3,943 photos across 141 portrait sessions taken during Burning Man 2025, where participants received electric shocks while having their portraits taken. The application provides:

- Gallery view with session organization by day
- Individual session viewer with photo selection
- Hero shot selection and persistence
- Sitter information collection (name, email, notes)
- Admin interface for data management and face detection
- Mobile-optimized interface for iPad viewing
- Integrated image processing with Active Storage

## 🏗️ Architecture

This is a Rails 8 application with integrated UI using:
- **Rails 8.0.2** with SQLite/PostgreSQL database
- **Stimulus.js** for JavaScript interactivity
- **Turbo** for SPA-like navigation
- **Tailwind CSS** for styling
- **Active Storage** for image processing and serving
- **Solid Queue** for background job processing

## 🚀 Quick Start

### Prerequisites
- Ruby 3.4.5
- PostgreSQL (for production) or SQLite (development)
- ImageMagick (for image processing)

### Development Setup

```bash
# Install dependencies
bundle install

# Setup database
bin/rails db:create db:migrate db:seed

# Start development server with Tailwind watcher
bin/dev
# Access at http://localhost:4000
```

### Alternative: Run components separately
```bash
# Terminal 1 - Rails server
bin/rails server -p 4000

# Terminal 2 - Tailwind CSS watcher
bin/rails tailwindcss:watch

# Terminal 3 - Background jobs
bin/jobs
```

## 📁 Project Structure

```
shock-collar-portraits-2025/
├── app/
│   ├── controllers/        # Rails controllers (API and web)
│   │   ├── admin/          # Admin interface controllers
│   │   └── api/            # API endpoints
│   ├── models/             # ActiveRecord models
│   ├── views/              # ERB templates
│   │   ├── admin/          # Admin interface views
│   │   ├── gallery/        # Main gallery views
│   │   └── heroes/         # Hero selection views
│   ├── javascript/         # Stimulus controllers
│   │   └── controllers/    # Interactive UI components
│   └── jobs/               # Background jobs
├── config/                 # Rails configuration
├── db/                     # Database migrations and schema
├── public/                 # Static assets
├── storage/               # Active Storage files
├── test/                  # Test suite
├── docs/                  # Documentation
├── scripts/               # Utility scripts
└── archive/               # Historical code
    └── vue-frontend/      # Original Vue.js implementation (retired)
```

## 🔑 Key Features

### Photo Management
- Automatic session detection from burst photos (30-second gaps)
- Thumbnail generation via Active Storage variants
- Support for Canon R5 RAW and iPhone HEIC formats
- Face detection with native macOS Vision framework

### Data Models
- **BurnEvent**: Event context (Burning Man 2025)
- **PhotoSession**: Groups of photos taken in bursts
- **Sitting**: Individual portrait session with person info
- **Photo**: Individual photo with metadata and Active Storage attachment

### User Interface
- Responsive gallery with collapsible day sections
- Touch-optimized for iPad viewing
- Keyboard navigation support
- Real-time selection updates
- Admin dashboard for data management

## 🌐 Network Access

The application is designed to work over local network and Tailscale:
- Local: `http://localhost:4000`
- Network: `http://[your-ip]:4000`
- Tailscale: `http://100.97.169.52:4000`

## 📝 Environment Variables

Create a `.env` file in the root directory:

```bash
# Database (production only)
DATABASE_URL=postgresql://...

# Photo storage path
PHOTOS_PATH=/path/to/original/photos

# Active Storage (optional)
AWS_ACCESS_KEY_ID=...
AWS_SECRET_ACCESS_KEY=...
AWS_REGION=...
AWS_BUCKET=...
```

## 🧪 Testing & Quality

```bash
# Run tests
bin/rails test

# Run specific test file
bin/rails test test/controllers/gallery_controller_test.rb

# Run linter
bin/rubocop

# Auto-fix linting issues
bin/rubocop -A

# Security analysis
bin/brakeman --no-pager
```

## 📚 Documentation

See the `docs/` directory for:
- `SYSTEM_DOCUMENTATION.md` - Detailed system overview
- `RAILS_ARCHITECTURE.md` - Backend architecture details
- `QUICK_REFERENCE.md` - Common commands and tasks
- `CLAUDE.md` - AI assistant guidelines

## 🛠️ Development Tools

### Rails Console
```bash
bin/rails c
```

### Database Console
```bash
bin/rails db
```

### View Routes
```bash
bin/rails routes
```

### Background Jobs Dashboard
Access Solid Queue dashboard at `/admin/jobs` (when configured)

## 🚀 Deployment

### Production Build
```bash
# Precompile assets
bin/rails assets:precompile

# Run database migrations
bin/rails db:migrate

# Start production server
RAILS_ENV=production bin/rails server
```

### Docker Deployment
```bash
# Build image
docker build -t shock-collar-app .

# Run container
docker run -p 3000:3000 shock-collar-app
```

## 🤝 Contributing

This is a personal project from Burning Man 2025. Feel free to fork and adapt for your own photo management needs!

## 📄 License

Private project - all rights reserved

---

*Built with ⚡ at Burning Man 2025*