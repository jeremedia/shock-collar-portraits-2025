# OKNOTOK Shock Collar Portraits - Burning Man 2025

A full-stack web application for managing, viewing, and selecting portrait photos from the OKNOTOK Shock Collar Portraits project at Burning Man 2025.

## 📸 Project Overview

This system manages 3,943 photos across 141 portrait sessions taken during Burning Man 2025, where participants received electric shocks while having their portraits taken. The application provides:

- Gallery view with session organization by day
- Individual session viewer with photo selection
- Hero shot selection and persistence
- Sitter information collection (name, email, notes)
- Admin interface for data management
- Mobile-optimized interface for iPad viewing

## 🏗️ Architecture

This is a monorepo containing:
- **Frontend**: Vue 3 SPA with Pinia state management
- **Backend**: Rails 8 API with PostgreSQL database
- **Scripts**: Photo sync and data migration utilities
- **Docs**: System documentation and architecture notes

## 🚀 Quick Start

### Prerequisites
- Ruby 3.4.5
- Node.js 18+
- PostgreSQL (for production)

### Frontend Development
```bash
cd frontend
npm install
npm run dev
# Access at http://localhost:5173
```

### Backend Development
```bash
cd backend
bundle install
rails db:create db:migrate
rails server -p 4000
# API at http://localhost:4000
```

### Running Both
```bash
# Terminal 1
cd backend && rails server -p 4000

# Terminal 2
cd frontend && npm run dev
```

## 📁 Project Structure
```
shock-collar-portraits-2025/
├── frontend/          # Vue 3 application
│   ├── src/
│   │   ├── components/
│   │   ├── views/
│   │   ├── stores/    # Pinia stores
│   │   └── services/  # API integration
│   └── package.json
├── backend/           # Rails API
│   ├── app/
│   │   ├── controllers/api/
│   │   └── models/
│   ├── db/
│   └── Gemfile
├── docs/              # Documentation
├── scripts/           # Utility scripts
└── data-archive/      # Metadata exports
```

## 🔑 Key Features

### Photo Management
- Automatic session detection from burst photos
- Thumbnail generation and caching
- Support for Canon R5 RAW and iPhone HEIC formats

### Data Models
- **PhotoSession**: Groups of photos taken in bursts
- **Sitting**: Individual portrait session with person info
- **Photo**: Individual photo with metadata
- **BurnEvent**: Event context (Burning Man 2025)

### User Interface
- Responsive gallery with collapsible day sections
- Touch-optimized for iPad
- Keyboard navigation support
- Real-time selection updates

## 🔄 Data Migration

The system is transitioning from localStorage to database storage. Current localStorage keys:
- `shock_collar_selections` - Hero photo selections
- `shock_collar_emails` - Sitter contact information
- `gallery_collapsed_days` - UI state

Migration script available in `scripts/export_localstorage.html`

## 🌐 Network Access

The application is designed to work over local network and Tailscale:
- Local: `http://localhost:5173`
- Network: `http://[your-ip]:5173`
- Tailscale: `http://100.97.169.52:5173`

## 📝 Environment Variables

### Frontend (.env)
```
VITE_API_URL=http://localhost:4000
```

### Backend (.env)
```
DATABASE_URL=postgresql://...
PHOTOS_PATH=/path/to/photos
```

## 🧪 Testing

```bash
# Frontend tests
cd frontend && npm test

# Backend tests
cd backend && rails test
```

## 📚 Documentation

See the `docs/` directory for:
- `CLAUDE.md` - Detailed implementation plan
- `RAILS_ARCHITECTURE.md` - Backend architecture
- `SYSTEM_DOCUMENTATION.md` - System overview
- `QUICK_REFERENCE.md` - Common commands

## 🛠️ Development Tools

- Vue DevTools for frontend debugging
- Rails console for backend: `rails c`
- Photo sync script: `scripts/sync_camera.sh`

## 🤝 Contributing

This is a personal project from Burning Man 2025. Feel free to fork and adapt for your own photo management needs!

## 📄 License

Private project - all rights reserved

---

*Built with ⚡ at Burning Man 2025*