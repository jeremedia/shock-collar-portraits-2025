# Service Worker Image Caching Fix

## Problem
Rails Active Storage images were not being cached by the service worker because:
1. Images loaded via `<img>` tags are requested as `no-cors` by default
2. This creates opaque responses with status 0 that can't be inspected by JavaScript
3. The previous service worker was rejecting opaque responses
4. Cache API's `add()` method fails with opaque responses

## Solution Implemented

### 1. Added CORS Headers to Active Storage
**File:** `config/initializers/active_storage_cors.rb`
- Adds `Access-Control-Allow-Origin: *` headers to Active Storage proxy controllers
- Enables proper CORS responses instead of opaque responses
- Sets cache headers for better performance

### 2. Created Image Helper 
**File:** `app/helpers/image_helper.rb`
- `cached_image_tag`: Wrapper that adds `crossorigin="anonymous"` to all images
- `active_storage_image_tag`: Specific helper for Active Storage images

### 3. Updated Service Worker
**File:** `public/sw.js` (v13)
- Now properly handles BOTH opaque and CORS responses
- Uses `cache.put()` instead of `cache.add()` for opaque responses
- Accepts status 0 (opaque) responses as valid for caching
- Improved error handling and logging

## How to Test

### 1. Restart Rails Server
The CORS initializer requires a server restart:
```bash
# Stop the server if running
# Then restart it
```

### 2. Clear Browser Cache
1. Open Chrome DevTools (F12)
2. Go to Application tab
3. Click "Storage" in left sidebar
4. Click "Clear site data"

### 3. Force Service Worker Update
In the browser console:
```javascript
// Unregister old service worker
navigator.serviceWorker.getRegistrations().then(function(registrations) {
  for(let registration of registrations) {
    registration.unregister();
  }
});
// Reload the page - new service worker will install
```

### 4. Update Image Tags
To enable proper caching, update your views to include `crossorigin`:

```erb
<!-- Old -->
<%= image_tag rails_blob_url(photo.image.variant(:thumb)) %>

<!-- New - with crossorigin for proper caching -->
<%= image_tag rails_blob_url(photo.image.variant(:thumb)), 
              crossorigin: "anonymous" %>

<!-- Or use the new helper -->
<%= cached_image_tag rails_blob_url(photo.image.variant(:thumb)) %>
```

### 5. Monitor Caching
Open DevTools Console and watch for messages:
- `[SW v13] Installing...` - Service worker installing
- `[SW v13] Cache miss, fetching:` - First load from network
- `[SW v13] Cached response:` - Successfully cached
- `[SW v13] Cache hit:` - Served from cache
- `[SW v13] Cached opaque response:` - Cached an opaque response (fallback)

### 6. Verify Cache Contents
In DevTools > Application > Cache Storage:
- Look for `images-v13` cache
- Should see cached image URLs
- Images should load instantly on subsequent visits

## What's Different Now

1. **CORS Headers**: Active Storage now sends proper CORS headers
2. **Crossorigin Attribute**: Images can request CORS mode for non-opaque responses  
3. **Service Worker**: Accepts and caches both CORS and opaque responses
4. **Better Fallback**: Even without crossorigin attribute, opaque responses are cached

## Rollback Instructions
If issues occur:
1. Delete `config/initializers/active_storage_cors.rb`
2. Restore previous `public/sw.js` from git
3. Remove `crossorigin` attributes from image tags
4. Clear browser cache and service workers

## Next Steps
To fully implement across the app:
1. Update all image_tag calls to include `crossorigin: "anonymous"`
2. Or replace `image_tag` with `cached_image_tag` helper
3. Consider using a CDN with proper CORS headers for production