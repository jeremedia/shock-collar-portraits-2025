# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

OKNOTOK Shock Collar Portraits - A Rails 8 web application for managing 3,943 photos from 141 portrait sessions at Burning Man 2025. The application features integrated UI with Stimulus.js controllers, Active Storage for image processing, and a comprehensive admin interface.

## Architecture

**Rails 8 Application Structure:**
- `app/` - MVC components with integrated UI
  - `controllers/` - Rails controllers including admin and API
  - `models/` - ActiveRecord models
  - `views/` - ERB templates for gallery, admin, heroes
  - `javascript/controllers/` - Stimulus.js controllers for interactivity
  - `jobs/` - Background jobs for face detection and processing
- `config/` - Rails configuration and routes
- `db/` - Database migrations and schema
- `public/` - Static assets
- `storage/` - Active Storage files
- `test/` - Minitest suite
- `docs/` - Architecture documentation
- `scripts/` - Photo sync utilities
- `archive/vue-frontend/` - Historical Vue.js implementation (retired)

## Common Development Commands

### Rails Development

```bash
# Start development (server + Tailwind watcher + jobs)
bin/dev              # Runs on port 4000

# Alternative: run components separately
bin/rails server -p 4000     # Rails server only
bin/rails tailwindcss:watch   # CSS watcher
bin/jobs                      # Background jobs

# Database
bin/rails db:prepare          # Create/migrate database
bin/rails db:migrate          # Run migrations
bin/rails db:seed            # Load seed data
bin/rails db:reset          # Drop, create, migrate, seed

# Testing & Quality
bin/rails test               # Run all tests
bin/rails test test/path/to/test.rb  # Run specific test
bin/rubocop                  # Run linter
bin/rubocop -A              # Auto-correct linting issues
bin/brakeman --no-pager     # Security analysis

# Console & Debugging
bin/rails c                  # Rails console
bin/rails db                 # Database console
bin/rails routes            # View all routes
bin/rails routes -g gallery # Grep routes
```

## Key Models & Data Flow

### Core Models
- **BurnEvent** - Event context (Burning Man 2025)
- **PhotoSession** - Burst group of photos (30-second gap detection)
- **Sitting** - Individual portrait session with person info
- **Photo** - Individual photo with metadata and Active Storage attachment
- **FaceDetectionJob** - Background job for face detection

### Controllers
- **GalleryController** - Main gallery views
- **Admin::AdminController** - Admin dashboard and operations
- **Admin::ThumbnailsController** - Thumbnail management
- **HeroesController** - Hero photo selection

### Stimulus Controllers
- `image_viewer_controller.js` - Full-screen image viewing with keyboard navigation
- `admin_editor_controller.js` - Admin interface interactions
- `day_accordion_controller.js` - Collapsible day sections
- `thumbnail_size_controller.js` - Dynamic thumbnail sizing
- `queue_status_controller.js` - Real-time job queue monitoring
- `stats_controller.js` - Statistics page with Chart.js visualizations

## API Endpoints & Routes

### Main Routes
- `GET /` - Gallery index
- `GET /gallery` - Gallery view
- `GET /gallery/:id` - Session view
- `GET /admin` - Admin dashboard
- `GET /admin/face_detection` - Face detection interface
- `GET /heroes` - Hero selections view

### Image Serving
- Active Storage handles all image variants
- Thumbnails generated on-demand with caching
- Support for Canon JPG and iPhone HEIC formats

## Development Guidelines

### Rails Conventions
- Follow RuboCop Rails Omakase style (configured in `.rubocop.yml`)
- Use service objects for complex logic
- Background jobs via Solid Queue for heavy processing
- Credentials managed via `bin/rails credentials:edit`
- Prefer Stimulus controllers over inline JavaScript

### Database
- SQLite for development (default)
- PostgreSQL for production
- Use Rails migrations for schema changes
- Active Storage for file attachments

### Testing
- Minitest for all tests (in `test/` directory)
- Test files named `*_test.rb`
- Run before committing changes

### Commit Messages
Use conventional commits: `feat:`, `fix:`, `chore:`, `docs:`, `refactor:`, `test:`

## Photo Processing

- **Original Photos**: 82GB Canon R5 + ~250MB iPhone
- **Formats**: Canon JPG (10-12MB), iPhone HEIC (1.6-1.8MB)
- **Processing**: Active Storage variants with ImageMagick
- **Face Detection**: macOS Vision framework via Swift script
- **Sizes**: Multiple variants generated on-demand

## Environment Configuration

### Development
- Port 4000 for Rails server
- SQLite database (no configuration needed)
- Photos served from local storage

### Production
- PostgreSQL database via DATABASE_URL
- Optional S3 for Active Storage
- Solid Queue for background jobs

## Common Tasks

### Adding New Photos
1. Place photos in appropriate directory structure
2. Run import rake task: `bin/rails photos:import`
3. Process face detection: via admin interface

### Database Operations
```bash
# Backup database
bin/rails db:dump

# Restore database
bin/rails db:restore

# Console operations
bin/rails c
PhotoSession.count
Photo.where(sitting: nil).count
```

### Debugging
- Check logs: `tail -f log/development.log`
- Rails console for interactive debugging
- Browser DevTools for Stimulus controllers
- `/admin/queue_status` for job monitoring

## Important Files

- `config/routes.rb` - All application routes
- `app/models/` - Data models and business logic
- `app/controllers/admin/` - Admin functionality
- `app/javascript/controllers/` - Frontend interactivity
- `db/schema.rb` - Current database structure
- `Procfile.dev` - Development server configuration

## Chart.js Plugin Integration (CRITICAL for Stats Page)

### Understanding the Architecture
The stats page uses Chartkick which bundles Chart.js as `Chart.bundle.js`. This creates specific requirements for adding Chart.js plugins:

1. **Chartkick provides Chart.js**: The `Chart.bundle.js` file contains the complete Chart.js library
2. **Plugin dependency issue**: Chart.js plugins expect to import `chart.js` and `chart.js/helpers`
3. **Solution**: Map these imports to the bundled version in importmap

### Adding a Chart.js Plugin - Step by Step

1. **Download the UMD version** (NOT the ESM version):
```bash
curl -o vendor/javascript/chartjs-plugin-name.js \
  https://cdn.jsdelivr.net/npm/chartjs-plugin-name/dist/chartjs-plugin-name.min.js
```

2. **Configure importmap.rb** with REQUIRED mappings:
```ruby
# config/importmap.rb
pin "chartkick", to: "chartkick.js"
pin "Chart.bundle", to: "Chart.bundle.js"

# CRITICAL: These mappings are REQUIRED for plugins to work
pin "chart.js/helpers", to: "Chart.bundle.js"  # Plugins look for this
pin "chart.js", to: "Chart.bundle.js"          # Plugins look for this

# Your plugin
pin "chartjs-plugin-name", to: "chartjs-plugin-name.js"
```

3. **Import in stats_controller.js**:
```javascript
// Load plugin AFTER Chart.js is available
if (window.Chart && !window.chartjsPluginName) {
  await import("chartjs-plugin-name")
}
```

4. **Clear the stats cache**:
```bash
bin/rails runner 'StatsCache.stats_json(version: StatsCache.version, force: true)'
```

### Common Errors and Solutions

- **"Cannot read properties of undefined (reading 'helpers')"**: The plugin can't find Chart.js helpers. Ensure the `chart.js/helpers` mapping exists in importmap.rb
- **Plugin not loading**: Make sure you're using the UMD version, not ESM
- **404 errors**: Check that the plugin file exists in `vendor/javascript/`

### Example: Rain Annotation
The Tuesday timeline chart shows a rain indicator from 3:00-3:33 PM using the chartjs-plugin-annotation plugin. This was added following the exact steps above.