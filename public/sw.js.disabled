// Service Worker v13.0.0 - Fixed Active Storage Image Caching
// Handles both CORS and opaque responses properly

const CACHE_VERSION = 'v13';
const CACHE_NAME = `images-${CACHE_VERSION}`;

// Patterns to identify cacheable image URLs
const CACHEABLE_PATTERNS = [
  '/rails/active_storage/',           // Proxied Active Storage URLs
  '/rails/representations/',          // Rails variant URLs
  '/rails/disk/',                     // Local disk storage URLs
  '.s3.amazonaws.com/',               // S3 direct URLs
  '.s3.us-west-2.amazonaws.com/',    // S3 region-specific URLs
  '.s3-us-west-2.amazonaws.com/',    // Alternative S3 format
  '/photos/',                         // Direct photo routes
  '.jpg', '.jpeg', '.png', '.webp', '.gif'  // Image extensions
];

// Check if URL should be cached
function shouldCache(url) {
  return CACHEABLE_PATTERNS.some(pattern => url.toLowerCase().includes(pattern.toLowerCase()));
}

// Install and activate immediately
self.addEventListener('install', event => {
  console.log('[SW v13] Installing...');
  self.skipWaiting();
});

self.addEventListener('activate', event => {
  console.log('[SW v13] Activating...');
  event.waitUntil(
    caches.keys().then(names => {
      return Promise.all(
        names
          .filter(name => name !== CACHE_NAME)
          .map(name => {
            console.log('[SW v13] Deleting old cache:', name);
            return caches.delete(name);
          })
      );
    }).then(() => {
      console.log('[SW v13] Claiming clients');
      return self.clients.claim();
    })
  );
});

// Fetch event - Cache-first strategy with proper handling
self.addEventListener('fetch', event => {
  const url = event.request.url;
  
  // Only process GET requests for images
  if (event.request.method !== 'GET' || !shouldCache(url)) {
    return;
  }
  
  event.respondWith(
    caches.match(event.request)
      .then(cachedResponse => {
        // Return cached response if found
        if (cachedResponse) {
          console.log('[SW v13] Cache hit:', url);
          return cachedResponse;
        }
        
        // Cache miss - fetch from network
        console.log('[SW v13] Cache miss, fetching:', url);
        
        // Clone the request for fetch
        const fetchRequest = event.request.clone();
        
        return fetch(fetchRequest).then(response => {
          // Check if we got a valid response
          if (!response) {
            console.log('[SW v13] No response for:', url);
            return response;
          }
          
          // Don't cache error responses
          if (response.status !== 200 && response.status !== 0) {
            console.log('[SW v13] Non-200 status:', response.status, url);
            return response;
          }
          
          // Handle both opaque and CORS responses
          const isOpaque = response.type === 'opaque';
          const isCors = response.type === 'cors';
          const isBasic = response.type === 'basic';
          
          // Cache successful responses (including opaque)
          if (response.status === 200 || isOpaque) {
            const responseToCache = response.clone();
            
            caches.open(CACHE_NAME)
              .then(cache => {
                // Use put() instead of add() for opaque responses
                cache.put(event.request, responseToCache)
                  .then(() => {
                    if (isOpaque) {
                      console.log('[SW v13] Cached opaque response:', url);
                    } else {
                      console.log('[SW v13] Cached response:', url);
                    }
                  })
                  .catch(err => {
                    console.error('[SW v13] Cache put error:', err, url);
                  });
              });
          }
          
          return response;
        }).catch(error => {
          console.error('[SW v13] Fetch error:', error, url);
          // Return a fallback or let it fail
          return new Response('Network error', {
            status: 408,
            headers: { 'Content-Type': 'text/plain' }
          });
        });
      })
      .catch(error => {
        console.error('[SW v13] Cache match error:', error);
        return fetch(event.request);
      })
  );
});

// Listen for messages from the page
self.addEventListener('message', event => {
  const { type, data } = event.data || {};
  
  if (type === 'SKIP_WAITING') {
    self.skipWaiting();
  }
  
  if (type === 'CLEAR_CACHE') {
    event.waitUntil(
      caches.delete(CACHE_NAME)
        .then(() => {
          console.log('[SW v13] Cache cleared');
          return self.clients.matchAll();
        })
        .then(clients => {
          clients.forEach(client => {
            client.postMessage({ type: 'CACHE_CLEARED' });
          });
        })
    );
  }
  
  // Preload specific URLs
  if (type === 'CACHE_URLS' && data && data.urls) {
    event.waitUntil(
      caches.open(CACHE_NAME).then(cache => {
        const validUrls = data.urls.filter(url => shouldCache(url));
        console.log('[SW v13] Preloading', validUrls.length, 'images');
        
        return Promise.all(
          validUrls.map(url => {
            return fetch(url, { mode: 'no-cors' })
              .then(response => {
                if (response) {
                  return cache.put(url, response);
                }
              })
              .catch(err => {
                console.error('[SW v13] Preload failed:', url, err);
              });
          })
        );
      })
    );
  }
  
  // Get cache statistics
  if (type === 'GET_CACHE_STATS') {
    caches.open(CACHE_NAME).then(cache => {
      return cache.keys();
    }).then(keys => {
      event.ports[0].postMessage({
        type: 'CACHE_STATS',
        data: {
          count: keys.length,
          version: CACHE_VERSION
        }
      });
    });
  }
});

console.log('[SW v13] Service Worker loaded and ready');