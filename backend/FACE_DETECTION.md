# Face Detection and Face-Only Thumbnails

## Overview
This feature uses macOS Vision framework to detect faces in photos and generate face-centered thumbnail crops. The system processes photos to identify face regions and creates optimized thumbnails that focus on the subject's face.

## Architecture

### 1. Face Detection Pipeline
- **Swift Script** (`bin/detect_faces.swift`): Uses Apple's Vision framework for face detection
- **Rails Service** (`app/services/face_detection_service.rb`): Coordinates detection and database storage
- **Background Processing**: Face detection runs asynchronously per photo

### 2. Data Storage
- Face data stored in `photos.face_data` JSONB column
- Includes normalized face coordinates and confidence scores
- Timestamp tracked in `face_detected_at` field

### 3. Face Crop Generation
- Dynamic variant generation using Active Storage
- 40% padding around detected face region
- Falls back to regular thumbnail if no face detected

## Implementation Details

### Swift Face Detection Script
```swift
// bin/detect_faces.swift
// Uses Vision framework to detect faces
// Returns JSON with normalized coordinates
```

### Rails Service Object
```ruby
# app/services/face_detection_service.rb
class FaceDetectionService
  def detect_for_photo(photo)
    # Executes Swift script
    # Parses results
    # Saves to database
  end
  
  def self.face_crop_params(photo)
    # Calculates crop region with padding
    # Returns extract_area parameters
  end
end
```

### Photo Model Integration
```ruby
# app/models/photo.rb
def detect_faces!
  ::FaceDetectionService.new.detect_for_photo(self)
end

def has_faces?
  face_data.present? && face_data['faces'].is_a?(Array) && face_data['faces'].any?
end

def face_crop_url(size: 300)
  # Generates face-centered thumbnail URL
  # Uses vips extract_area for cropping
end
```

## UI Components

### Index Page Footer
- "Faces Only" checkbox toggles between regular and face-cropped thumbnails
- Preference saved in localStorage
- Smooth CSS transitions between modes

### JavaScript Controller
```javascript
// app/javascript/controllers/thumbnail_size_controller.js
updateFaceMode() {
  // Toggles .face-mode class on grids
  // Shows/hides appropriate thumbnail divs
}
```

### View Templates
Each session card contains both thumbnail types:
- `.regular-thumbnail` - Standard crop
- `.face-thumbnail` - Face-centered crop

CSS controls visibility based on `.face-mode` class.

## Processing Workflow

### Batch Processing
```ruby
# Process all photos in a session
session.photos.each do |photo|
  photo.detect_faces!
end
```

### Rake Tasks
```ruby
# lib/tasks/face_detection.rake
namespace :photos do
  desc "Process face detection for all photos"
  task detect_faces: :environment do
    Photo.where(face_detected_at: nil).find_each do |photo|
      photo.detect_faces!
    end
  end
end
```

## Configuration

### Requirements
- macOS with Vision framework
- Swift compiler
- Active Storage with vips processor
- ImageMagick or libvips

### Database Migrations
```ruby
add_column :photos, :face_data, :jsonb
add_column :photos, :face_detected_at, :datetime
add_index :photos, :face_detected_at
```

## Performance Considerations

### Caching
- Face detection results cached in database
- Active Storage variants cached on disk
- One-time processing per photo

### Optimization
- Lazy loading of face thumbnails
- Progressive enhancement (shows regular thumb while loading)
- Batch processing for efficiency

## Error Handling

### Fallback Strategy
1. If face detection fails → Show regular thumbnail
2. If no faces detected → Show regular thumbnail
3. If crop generation fails → Show regular thumbnail

### Common Issues
- Missing Active Storage attachments
- Swift script permissions
- Vision framework availability

## Usage Examples

### Enable Face-Only Mode
1. Click "Faces Only" checkbox in index footer
2. All thumbnails switch to face-centered crops
3. Preference persists across sessions

### Process New Photos
```ruby
# After importing new photos
PhotoSession.last.photos.each(&:detect_faces!)
```

### Check Processing Status
```ruby
# View processing stats
total = Photo.count
processed = Photo.where.not(face_detected_at: nil).count
with_faces = Photo.where("face_data IS NOT NULL AND json_array_length(json_extract(face_data, '$.faces')) > 0").count

puts "#{processed}/#{total} processed, #{with_faces} with faces"
```

## Future Enhancements
- Multiple face handling
- Face recognition for grouping
- Auto-selection of best face crop
- Facial expression analysis
- Smart cropping for group photos