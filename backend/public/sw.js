// Simple thumbnail caching service worker
// Version 9.0.0 - Force activation

const CACHE_VERSION = 'v11';
const CACHE_NAME = `thumbnails-${CACHE_VERSION}`;

// Install and activate immediately
self.addEventListener('install', event => {
  console.log('[SW] Installing version', CACHE_VERSION);
  self.skipWaiting();
});

self.addEventListener('activate', event => {
  console.log('[SW] Activating version', CACHE_VERSION);
  event.waitUntil(
    caches.keys().then(names => {
      return Promise.all(
        names.filter(name => name.startsWith('thumbnails-') && name !== CACHE_NAME)
             .map(name => {
               console.log('[SW] Deleting old cache', name);
               return caches.delete(name);
             })
      );
    }).then(() => self.clients.claim())
  );
});

// Cache any Active Storage images
self.addEventListener('fetch', event => {
  const url = event.request.url;
  
  // Log EVERY fetch to verify SW is working
  console.log('[SW] Fetch event for:', url);
  
  // Only cache Active Storage URLs
  if (!url.includes('/rails/active_storage/')) {
    return;
  }
  
  console.log('[SW] Handling Active Storage request:', url);
  
  event.respondWith(
    caches.open(CACHE_NAME).then(cache => {
      return cache.match(event.request).then(response => {
        if (response) {
          console.log('[SW] Cache hit:', url);
          return response;
        }
        
        console.log('[SW] Cache miss, fetching:', url);
        return fetch(event.request).then(response => {
          // Only cache successful responses
          if (response.ok) {
            cache.put(event.request, response.clone());
            console.log('[SW] Cached:', url);
          }
          return response;
        });
      });
    })
  );
});