// Shock Collar Portraits - Service Worker for Thumbnail Caching
// Version 1.0.0

const CACHE_NAME = 'shock-collar-thumbnails-v1';
const THUMBNAIL_CACHE = 'thumbnails-cache-v1';
const MAX_CACHE_AGE = 7 * 24 * 60 * 60 * 1000; // 7 days in milliseconds
const MAX_CACHE_ENTRIES = 1000; // Maximum number of cached thumbnails

// URLs to cache thumbnails from
const THUMBNAIL_PATTERNS = [
  /^https?:\/\/[^\/]+\/photos\/thumb\//,
  /^https?:\/\/[^\/]+\/photos\/medium\//,
  /^https?:\/\/[^\/]+\/rails\/active_storage\/representations\/.*\/thumb$/,
  /^https?:\/\/[^\/]+\/rails\/active_storage\/representations\/.*$/
];

// Install event - setup caches
self.addEventListener('install', event => {
  console.log('Service Worker installing...');
  event.waitUntil(
    Promise.all([
      caches.open(CACHE_NAME),
      caches.open(THUMBNAIL_CACHE)
    ]).then(() => {
      console.log('Service Worker caches initialized');
      self.skipWaiting();
    })
  );
});

// Activate event - cleanup old caches
self.addEventListener('activate', event => {
  console.log('Service Worker activating...');
  event.waitUntil(
    Promise.all([
      // Clean up old cache versions
      caches.keys().then(cacheNames => {
        return Promise.all(
          cacheNames.map(cacheName => {
            if (cacheName !== CACHE_NAME && cacheName !== THUMBNAIL_CACHE) {
              console.log('Deleting old cache:', cacheName);
              return caches.delete(cacheName);
            }
          })
        );
      }),
      // Clean up old thumbnail entries
      cleanupThumbnailCache()
    ]).then(() => {
      console.log('Service Worker activated');
      self.clients.claim();
    })
  );
});

// Fetch event - handle thumbnail caching
self.addEventListener('fetch', event => {
  const url = event.request.url;
  
  // Only cache GET requests
  if (event.request.method !== 'GET') {
    return;
  }
  
  // Check if this is a thumbnail request
  if (isThumbnailRequest(url)) {
    event.respondWith(handleThumbnailRequest(event.request));
    return;
  }
  
  // For other requests, just pass through
  event.respondWith(fetch(event.request));
});

// Check if URL matches thumbnail patterns
function isThumbnailRequest(url) {
  return THUMBNAIL_PATTERNS.some(pattern => pattern.test(url));
}

// Handle thumbnail requests with cache-first strategy
async function handleThumbnailRequest(request) {
  try {
    const cache = await caches.open(THUMBNAIL_CACHE);
    const cachedResponse = await cache.match(request);
    
    // If found in cache and not expired, return it
    if (cachedResponse) {
      const cachedDate = cachedResponse.headers.get('sw-cached-date');
      if (cachedDate) {
        const cacheAge = Date.now() - parseInt(cachedDate);
        if (cacheAge < MAX_CACHE_AGE) {
          console.log('Cache HIT:', request.url);
          return cachedResponse;
        }
      }
    }
    
    // Not in cache or expired, fetch from network
    console.log('Cache MISS:', request.url);
    const networkResponse = await fetch(request);
    
    // Only cache successful responses
    if (networkResponse.ok) {
      // Clone the response and add cache metadata
      const responseToCache = networkResponse.clone();
      const headers = new Headers(responseToCache.headers);
      headers.set('sw-cached-date', Date.now().toString());
      
      const cachedResponse = new Response(responseToCache.body, {
        status: responseToCache.status,
        statusText: responseToCache.statusText,
        headers: headers
      });
      
      // Cache the response
      await cache.put(request, cachedResponse);
      
      // Cleanup cache if it gets too large
      await maintainCacheSize();
    }
    
    return networkResponse;
  } catch (error) {
    console.error('Error handling thumbnail request:', error);
    
    // Try to return cached version even if expired
    const cache = await caches.open(THUMBNAIL_CACHE);
    const cachedResponse = await cache.match(request);
    if (cachedResponse) {
      console.log('Returning expired cache due to network error:', request.url);
      return cachedResponse;
    }
    
    // Return error response
    return new Response('Thumbnail not available offline', {
      status: 503,
      statusText: 'Service Unavailable'
    });
  }
}

// Cleanup expired thumbnail cache entries
async function cleanupThumbnailCache() {
  try {
    const cache = await caches.open(THUMBNAIL_CACHE);
    const requests = await cache.keys();
    const now = Date.now();
    
    let deletedCount = 0;
    
    for (const request of requests) {
      const response = await cache.match(request);
      if (response) {
        const cachedDate = response.headers.get('sw-cached-date');
        if (cachedDate) {
          const cacheAge = now - parseInt(cachedDate);
          if (cacheAge > MAX_CACHE_AGE) {
            await cache.delete(request);
            deletedCount++;
          }
        }
      }
    }
    
    if (deletedCount > 0) {
      console.log(`Cleaned up ${deletedCount} expired thumbnail cache entries`);
    }
  } catch (error) {
    console.error('Error cleaning up thumbnail cache:', error);
  }
}

// Maintain cache size by removing oldest entries
async function maintainCacheSize() {
  try {
    const cache = await caches.open(THUMBNAIL_CACHE);
    const requests = await cache.keys();
    
    if (requests.length <= MAX_CACHE_ENTRIES) {
      return;
    }
    
    // Get all cached items with their timestamps
    const cachedItems = [];
    for (const request of requests) {
      const response = await cache.match(request);
      if (response) {
        const cachedDate = response.headers.get('sw-cached-date');
        cachedItems.push({
          request,
          timestamp: cachedDate ? parseInt(cachedDate) : 0
        });
      }
    }
    
    // Sort by timestamp (oldest first)
    cachedItems.sort((a, b) => a.timestamp - b.timestamp);
    
    // Remove oldest entries
    const itemsToRemove = cachedItems.length - MAX_CACHE_ENTRIES;
    for (let i = 0; i < itemsToRemove; i++) {
      await cache.delete(cachedItems[i].request);
    }
    
    console.log(`Removed ${itemsToRemove} oldest thumbnail cache entries`);
  } catch (error) {
    console.error('Error maintaining cache size:', error);
  }
}

// Handle messages from the main thread
self.addEventListener('message', event => {
  const { type, data } = event.data;
  
  switch (type) {
    case 'CACHE_THUMBNAILS':
      // Preload thumbnails for a session
      event.waitUntil(preloadThumbnails(data.urls));
      break;
      
    case 'CLEAR_CACHE':
      // Clear all thumbnail cache
      event.waitUntil(clearThumbnailCache());
      break;
      
    case 'GET_CACHE_STATUS':
      // Return cache status
      event.waitUntil(getCacheStatus().then(status => {
        event.source.postMessage({ type: 'CACHE_STATUS', data: status });
      }));
      break;
  }
});

// Preload thumbnails in background
async function preloadThumbnails(urls) {
  try {
    console.log(`Preloading ${urls.length} thumbnails...`);
    
    const promises = urls.map(url => {
      return fetch(url).then(response => {
        if (response.ok) {
          return caches.open(THUMBNAIL_CACHE).then(cache => {
            const headers = new Headers(response.headers);
            headers.set('sw-cached-date', Date.now().toString());
            
            const cachedResponse = new Response(response.body, {
              status: response.status,
              statusText: response.statusText,
              headers: headers
            });
            
            return cache.put(url, cachedResponse);
          });
        }
      }).catch(error => {
        console.warn('Failed to preload thumbnail:', url, error);
      });
    });
    
    await Promise.allSettled(promises);
    console.log('Thumbnail preloading complete');
  } catch (error) {
    console.error('Error preloading thumbnails:', error);
  }
}

// Clear thumbnail cache
async function clearThumbnailCache() {
  try {
    await caches.delete(THUMBNAIL_CACHE);
    await caches.open(THUMBNAIL_CACHE);
    console.log('Thumbnail cache cleared');
  } catch (error) {
    console.error('Error clearing thumbnail cache:', error);
  }
}

// Get cache status
async function getCacheStatus() {
  try {
    const cache = await caches.open(THUMBNAIL_CACHE);
    const requests = await cache.keys();
    const totalSize = await calculateCacheSize(cache, requests);
    
    return {
      entries: requests.length,
      maxEntries: MAX_CACHE_ENTRIES,
      estimatedSize: totalSize,
      cacheVersion: THUMBNAIL_CACHE
    };
  } catch (error) {
    console.error('Error getting cache status:', error);
    return {
      entries: 0,
      maxEntries: MAX_CACHE_ENTRIES,
      estimatedSize: 0,
      cacheVersion: THUMBNAIL_CACHE,
      error: error.message
    };
  }
}

// Calculate approximate cache size
async function calculateCacheSize(cache, requests) {
  let totalSize = 0;
  const sampleSize = Math.min(10, requests.length); // Sample first 10 entries
  
  for (let i = 0; i < sampleSize; i++) {
    const response = await cache.match(requests[i]);
    if (response && response.body) {
      const clone = response.clone();
      const buffer = await clone.arrayBuffer();
      totalSize += buffer.byteLength;
    }
  }
  
  // Estimate total size based on sample
  if (sampleSize > 0) {
    totalSize = (totalSize / sampleSize) * requests.length;
  }
  
  return Math.round(totalSize / 1024); // Return size in KB
}