# OKNOTOK Shock Collar Portraits - Vue 3 Web App

## 🎯 Overview
High-performance Vue 3 single-page application with automatic thumbnail generation, optimized for iPad viewing over Tailscale network.

## 📋 Current Status - COMPLETED ✅
- **Vue 3 App**: Fully implemented with router, Pinia stores, and all components
- **Backend Server**: Express API with Sharp image processing operational
- **Total Sessions**: 141 (140 Canon R5, 1 iPhone)
- **Total Photos**: 3,943
- **Storage Used**: 82GB (Canon) + ~250MB (iPhone)
- **Cached Thumbnails**: 3,692 images already processed
- **Photo Sizes**: Canon JPGs ~10-12MB, iPhone HEIC ~1.6-1.8MB

## 🏗️ Architecture

### 1. Backend Server (Express + Sharp)
Express.js API server on port 3000 with image processing capabilities.

#### API Endpoints
- `GET /api/sessions` - List all sessions with metadata
- `GET /api/sessions/:id` - Get specific session details
- `GET /api/images/:size/:path` - Serve optimized images (thumb/medium/full)
- `GET /api/settings` - Retrieve hero selections
- `POST /api/settings` - Store hero selections
- `GET /api/watch` - SSE endpoint for real-time updates

#### Image Processing
- **Sharp** library for fast image processing
- HEIC → JPEG conversion for iPhone photos
- WebP format for modern browsers
- Cache processed images in `.thumbs/` directory

### 2. Image Processing Pipeline

#### Size Variants
- **Thumbnail**: 300px wide (~50KB) - Grid view
- **Medium**: 800px wide (~200KB) - iPad viewing
- **Full**: Original size - Detailed viewing

#### Caching Strategy
- Lazy generation: create thumbnails on first request
- Directory structure: `.thumbs/{size}/{session}/{filename}.webp`
- Estimated space: ~15GB additional for all thumbnails

### 3. Vue 3 Frontend

#### Component Structure
```
src/
├── views/
│   ├── GalleryView.vue      # Main gallery with collapsible days
│   └── SessionView.vue       # Individual session viewer
├── components/
│   ├── DaySection.vue        # Collapsible day container
│   ├── SessionCard.vue       # Session thumbnail card
│   ├── ImageViewer.vue       # Full-screen image viewer
│   ├── ThumbnailGrid.vue     # Grid of thumbnails in session
│   ├── UpcomingSessions.vue  # Upcoming session display
│   └── QuickNav.vue          # Navigation bar
├── stores/
│   ├── sessions.js           # Session data management
│   └── settings.js           # User preferences
└── router/
    └── index.js              # Vue Router configuration
```

#### Key Features
- **Vue Router** for SPA navigation
- **Pinia** for state management
- **Intersection Observer** for lazy loading
- **Touch gestures** for iPad (swipe navigation)
- **PWA capabilities** for offline viewing
- **Virtual scrolling** for performance

### 4. Project Structure
```
shock-collar-vue/
├── server/
│   ├── index.js              # Express server
│   ├── imageProcessor.js     # Sharp thumbnail generation
│   ├── sessionScanner.js     # Directory scanning
│   └── cache.js              # Cache management
├── src/
│   ├── views/
│   ├── components/
│   ├── stores/
│   ├── router/
│   ├── utils/
│   └── App.vue
├── public/
│   └── manifest.json         # PWA manifest
├── .thumbs/                  # Generated thumbnails
├── vite.config.js
└── package.json
```

### 5. Network Configuration

#### Development
- Vite dev server: Port 5173
- Express API: Port 3000

#### Production
- Express serves both API and Vue app on Port 3000

#### Access URLs
- Local: `http://192.168.1.68:3000`
- Tailscale: `http://100.97.169.52:3000`
- Hostname: `http://[your-mac-name].local:3000`

## 📝 Implementation Steps

### Phase 1: Setup & Dependencies
1. Initialize Vue 3 project with Vite
2. Install dependencies:
   - Backend: `express sharp cors chokidar compression`
   - Frontend: `vue-router pinia axios hammerjs`
3. Setup basic project structure
4. Configure Vite for network access

### Phase 2: Image Processing Backend
1. Create Sharp-based thumbnail generator
2. Implement HEIC to JPEG/WebP conversion
3. Setup caching system with file watching
4. Test with sample images from each source

### Phase 3: Express API Server
1. Create Express server with CORS
2. Implement session scanning from existing metadata
3. Build RESTful API endpoints
4. Add Server-Sent Events for real-time updates
5. Implement static file serving for production

### Phase 4: Vue Frontend Core
1. Port existing HTML/CSS to Vue components
2. Implement Vue Router with routes:
   - `/` - Gallery view
   - `/session/:id` - Session view
   - `/settings` - App settings
3. Setup Pinia stores for state management
4. Create responsive layout for iPad

### Phase 5: Interactive Features
1. Implement touch gestures (swipe, pinch-zoom)
2. Add keyboard navigation
3. Create smooth transitions between views
4. Implement virtual scrolling for large galleries
5. Add loading states and skeleton screens

### Phase 6: Optimization & PWA
1. Implement service worker for offline support
2. Add image preloading strategies
3. Optimize bundle size with code splitting
4. Create app manifest for home screen install
5. Add meta tags for iPad viewport

### Phase 7: Deployment & Testing
1. Build production bundle
2. Create PM2 configuration for server
3. Setup auto-start on Mac boot
4. Test on iPad over Tailscale
5. Create backup and update scripts

## 🎯 Key Improvements

### Performance
- **95% smaller** initial load (thumbnails vs full images)
- **Lazy loading** prevents loading all 3900 images at once
- **Virtual scrolling** for smooth performance with large galleries
- **WebP format** for 30% smaller file sizes

### User Experience
- **Instant** image switching with pre-caching
- **Smooth animations** between views
- **Touch-optimized** for natural iPad interaction
- **Real-time updates** when adding new photos
- **Offline support** with service worker

### Features
- **Search/filter** by date, session, or camera type
- **Batch operations** for selecting multiple hero shots
- **Export** selected photos as ZIP
- **Share links** to specific sessions
- **Statistics** dashboard with insights

## 💾 Storage Estimates
- Original files: 82GB (unchanged)
- Thumbnails (300px): ~5GB
- Medium (800px): ~10GB (generated on-demand)
- Cache overhead: ~1GB
- **Total**: ~98GB

## 🚀 Quick Start Commands
```bash
# Project is already setup and ready to run!
cd shock-collar-vue

# Start both servers for development
npm run server:dev   # Backend API on port 3001
npm run dev         # Vue frontend on port 5174

# Or run both simultaneously
npm run dev:full    # Runs both servers concurrently

# Production build
npm run build       # Build Vue app
npm run start       # Start production server

# Access URLs
# Local: http://localhost:5174
# Network: http://192.168.86.194:5174
# Tailscale: http://100.97.169.52:5174
```

## 🔧 Configuration Files

### vite.config.js
- Configure for network access
- Setup proxy for API in development
- Optimize build for production

### server/config.js
- Photo directory paths
- Cache settings
- Network configuration
- Image processing options

## 📱 iPad Optimization
- Touch gestures for navigation
- Optimized for Safari on iPadOS
- Home screen installable
- Works offline after first load
- Responsive design for portrait/landscape

## 🔄 Future Enhancements
- Face detection for auto-cropping
- ML-based "best shot" suggestions
- Collaborative selection with multiple users
- Cloud backup integration
- Print ordering integration

---
*This document serves as the implementation guide for converting the OKNOTOK Shock Collar Portraits gallery into a modern Vue 3 web application optimized for iPad viewing over local network.*