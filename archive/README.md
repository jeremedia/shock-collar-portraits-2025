# Archive Directory

This directory contains historical code that is no longer in active use but is preserved for reference.

## vue-frontend/

The original Vue.js 3 frontend application that was used before the UI was integrated directly into the Rails application. This implementation included:

- Vue 3 with Composition API
- Pinia for state management
- Vue Router for SPA navigation
- Separate Express.js server for image processing
- Sharp library for thumbnail generation

### Why it was retired

The Vue frontend was replaced with a Rails-integrated UI using:
- Rails views with ERB templates
- Stimulus.js for JavaScript interactivity
- Turbo for SPA-like navigation
- Active Storage for image processing
- Direct integration with Rails backend

This change simplified deployment, reduced complexity, and improved performance by eliminating the need for a separate frontend server and API communication layer.

### Historical Context

- **Created**: September 2025
- **Retired**: September 2025
- **Original Purpose**: Provide a modern, responsive gallery interface for viewing and selecting shock collar portraits from Burning Man 2025

The code is preserved here for reference and potential future use of specific components or patterns.