# Rails 8 Backend Architecture for OKNOTOK Shock Collar Portraits

## Current System Analysis

### What We Have
- **3,510 photos** across 180 sessions (burst groups)
- **Photo organization**: Burst detection (30-second gaps) creating sessions
- **Vue 3 PWA**: Gallery viewer with hero selection
- **Local Storage Data**: 
  - Hero photo selections per session
  - Email collection for sitters
- **File Structure**: 
  - `/card_download_1/burst_XXX_timestamp/` - Canon photos
  - `/iphone_sessions/` - iPhone backup photos

### Current Pain Points
- Critical data (emails, hero selections) only in browser localStorage
- No persistent database
- No offplaya access
- No association between sitters and their photos
- Manual photo organization

## Rails 8 Architecture

### Core Models

```ruby
# app/models/burn_event.rb
class BurnEvent < ApplicationRecord
  # Fields: theme:string, year:integer, location:string
  has_many :session_days, dependent: :destroy
  has_many :sessions, through: :session_days
  
  # e.g., theme: "OKNOTOK Shock Collar Portraits", year: 2025
end

# app/models/session_day.rb
class SessionDay < ApplicationRecord
  # Fields: burn_event_id:integer, day_name:string, date:date
  belongs_to :burn_event
  has_many :sessions, dependent: :destroy
  
  # day_name: "monday", "tuesday", etc.
end

# app/models/session.rb
class Session < ApplicationRecord
  # Fields: session_day_id:integer, session_number:integer, 
  #         started_at:datetime, ended_at:datetime, burst_id:string,
  #         source:string (Canon R5/iPhone), photo_count:integer
  belongs_to :session_day
  has_many :sittings, dependent: :destroy
  has_many :photos, dependent: :destroy
  
  scope :with_sittings, -> { joins(:sittings).distinct }
  scope :without_sittings, -> { left_joins(:sittings).where(sittings: { id: nil }) }
end

# app/models/sitting.rb  
class Sitting < ApplicationRecord
  # Fields: session_id:integer, name:string, email:string, 
  #         position:integer, hero_photo_id:integer, 
  #         shock_intensity:integer, notes:text
  belongs_to :session
  belongs_to :hero_photo, class_name: 'Photo', optional: true
  has_many :photos, dependent: :destroy
  
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
end

# app/models/photo.rb
class Photo < ApplicationRecord
  # Fields: session_id:integer, sitting_id:integer (optional),
  #         filename:string, original_path:string, 
  #         position:integer, rejected:boolean, 
  #         metadata:jsonb, exif_data:jsonb
  belongs_to :session
  belongs_to :sitting, optional: true
  has_one_attached :image
  
  scope :not_rejected, -> { where(rejected: false) }
  scope :heroes, -> { joins(:hero_sittings) }
end
```

### Database Schema Additions

```ruby
# Indexes for performance
add_index :photos, [:session_id, :position]
add_index :photos, :filename, unique: true
add_index :sittings, :email
add_index :sittings, [:session_id, :position]

# JSONB for flexible metadata storage
# photos.metadata: { camera_settings: {}, burst_info: {} }
# photos.exif_data: { ISO, shutter_speed, aperture, etc. }
```

## Implementation Phases

### Phase 1: Rails Setup & Import
1. Create Rails 8 app with PostgreSQL
2. Generate models and migrations
3. Setup Active Storage for photos
4. Create import rake task for existing photos
5. Import photo_index.json structure

### Phase 2: Data Migration
1. Export localStorage data from browser
2. Import email collections to sittings
3. Import hero selections
4. Associate photos with sessions

### Phase 3: API Development
1. JSON API for Vue frontend
   - GET /api/sessions
   - GET /api/sessions/:id
   - PUT /api/sessions/:id/hero
   - POST /api/sittings
2. Photo serving via Active Storage
3. Maintain compatibility with existing Vue app

### Phase 4: Admin Interface
1. Rails admin dashboard
   - Session management
   - Sitting management  
   - Photo review/rejection
   - Email export
2. Bulk operations
   - Assign photos to sittings
   - Batch hero selection
   - Export for post-event gallery

### Phase 5: Post-Event Features
1. Public gallery generation
2. Individual sitting galleries (shareable links)
3. Download packages per sitting
4. Email notifications with gallery links

## Import Strategy

### Photo Import Process
```ruby
# lib/tasks/import.rake
namespace :import do
  task photos: :environment do
    # 1. Create BurnEvent for 2025
    # 2. Parse photo_index.json
    # 3. Create SessionDays (monday-friday)
    # 4. For each burst in index:
    #    - Create Session
    #    - Import photos maintaining positions
    #    - Store original paths for reference
    # 5. Handle iPhone sessions specially
  end
  
  task emails: :environment do
    # Import from localStorage export JSON
    # Match sessions by session_number
    # Create Sitting records
  end
  
  task heroes: :environment do
    # Import hero selections from localStorage
    # Update hero_photo_id on sittings
  end
end
```

## API Endpoints

### Core APIs for Vue Frontend
- `GET /api/burn_events/:year` - Get event with all data
- `GET /api/sessions` - List all sessions with photos
- `GET /api/sessions/:id` - Get session with photos
- `PUT /api/sessions/:id/hero` - Set hero photo
- `POST /api/sittings` - Create sitting (email collection)
- `GET /api/sittings/session/:session_id` - Get sitting for session
- `PUT /api/photos/:id/reject` - Mark photo as rejected

### Active Storage URLs
- Photos served via Rails Active Storage
- Signed URLs for security
- Variant processing for thumbnails

## Deployment Considerations

### Development
- SQLite for local development
- Store photos in `storage/` directory
- Seeds file with sample data

### Production (Offplaya)
- PostgreSQL database
- S3 or local storage for photos
- Redis for ActionCable (future live updates)
- Scheduled backups of database

## Migration Commands

```bash
# Initial setup
rails new shock_collar_rails -d postgresql
cd shock_collar_rails

# Generate models
rails g model BurnEvent theme:string year:integer location:string
rails g model SessionDay burn_event:references day_name:string date:date
rails g model Session session_day:references session_number:integer started_at:datetime ended_at:datetime burst_id:string source:string photo_count:integer
rails g model Sitting session:references name:string email:string position:integer hero_photo_id:integer shock_intensity:integer notes:text
rails g model Photo session:references sitting:references filename:string original_path:string position:integer rejected:boolean metadata:jsonb exif_data:jsonb

# Setup Active Storage
rails active_storage:install

# Run migrations
rails db:create db:migrate

# Import existing data
rails import:photos
rails import:emails  
rails import:heroes
```

## Benefits Over Current System

1. **Persistent Storage**: All data in PostgreSQL, no localStorage dependency
2. **Offplaya Access**: Deployable server for post-event access
3. **Data Integrity**: Foreign keys, validations, transactions
4. **Scalability**: Can handle multiple events/years
5. **Admin Tools**: Rails admin for managing sittings/sessions
6. **Export Features**: CSV, JSON exports for analysis
7. **Email Integration**: ActionMailer for sending gallery links
8. **Backup/Recovery**: Database backups vs localStorage
9. **Multi-user**: Multiple people can manage the system
10. **Analytics**: SQL queries for insights (photos per day, etc.)

## Next Steps

1. Create Rails app with models
2. Write import task for existing 180 sessions
3. Build API endpoints for Vue compatibility
4. Create admin interface
5. Deploy and test with real data