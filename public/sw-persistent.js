// Service Worker v15.0.0 - Persistent Storage with IndexedDB
// Implements Lightroom-style permanent image caching
// v15.0.0 - Skip caching JS files to avoid stale code

const CACHE_VERSION = 'v15.0.0';
const CACHE_NAME = `shock-collar-cache-${CACHE_VERSION}`;
const DB_NAME = 'ShockCollarGallery';
const DB_VERSION = 3; // Align with app preloader DB schema and fix metadata keyPath
const STORES = {
  images: 'images',        // Binary image data
  metadata: 'metadata',    // Image URLs, sizes, timestamps
  sessions: 'sessions'     // Session data for offline use
};

// URLs to cache on install (only safe, static routes)
const urlsToCache = [
  '/',
  '/gallery',
  '/heroes'
];

class PersistentImageCache {
  constructor() {
    this.dbPromise = this.initDB();
  }
  
  async initDB() {
    return new Promise((resolve, reject) => {
      const request = indexedDB.open(DB_NAME, DB_VERSION);

      request.onerror = () => reject(request.error);
      request.onsuccess = () => {
        const db = request.result;
        // Ensure we don't block future upgrades
        db.onversionchange = () => {
          // Close current connection so a new version can be opened elsewhere
          try { db.close(); } catch (_) {}
        };
        resolve(db);
      };

      request.onupgradeneeded = (event) => {
        const db = event.target.result;

        // Create object stores
        if (!db.objectStoreNames.contains(STORES.images)) {
          const imageStore = db.createObjectStore(STORES.images, { keyPath: 'url' });
          imageStore.createIndex('variant', 'variant', { unique: false });
          imageStore.createIndex('timestamp', 'timestamp', { unique: false });
        }

        // Ensure metadata store matches app schema (keyPath: 'id')
        if (db.objectStoreNames.contains(STORES.metadata)) {
          try { db.deleteObjectStore(STORES.metadata); } catch (_) {}
        }
        const metadataStore = db.createObjectStore(STORES.metadata, { keyPath: 'id' });
        try { metadataStore.createIndex('created_at', 'created_at', { unique: false }); } catch (_) {}

        if (!db.objectStoreNames.contains(STORES.sessions)) {
          db.createObjectStore(STORES.sessions, { keyPath: 'id' });
        }

        // Settings store for metadata versioning
        if (!db.objectStoreNames.contains('settings')) {
          db.createObjectStore('settings', { keyPath: 'key' });
        }
      };
    });
  }
  
  async getImage(url) {
    try {
      const db = await this.dbPromise;
      const tx = db.transaction([STORES.images], 'readonly');
      const store = tx.objectStore(STORES.images);
      const request = store.get(url);
      
      return new Promise((resolve, reject) => {
        request.onsuccess = () => {
          const data = request.result;
          if (data && data.blob) {
            // Return Response object from blob
            resolve(new Response(data.blob, {
              headers: {
                'Content-Type': data.contentType,
                'Cache-Control': 'immutable',
                'X-Cache': 'IndexedDB'
              }
            }));
          } else {
            resolve(null);
          }
        };
        request.onerror = () => reject(request.error);
      });
    } catch (error) {
      console.error('[SW Persistent] IndexedDB error:', error);
      return null;
    }
  }
  
  async storeImage(url, response) {
    try {
      const blob = await response.blob();
      const db = await this.dbPromise;
      const tx = db.transaction([STORES.images], 'readwrite');
      const store = tx.objectStore(STORES.images);
      
      const imageData = {
        url: url,
        blob: blob,
        contentType: response.headers.get('Content-Type') || 'image/jpeg',
        size: blob.size,
        timestamp: Date.now(),
        variant: this.detectVariant(url)
      };
      
      return new Promise((resolve, reject) => {
        const request = store.put(imageData);
        request.onsuccess = () => {
          console.log('[SW Persistent] Stored in IndexedDB:', url, 'Size:', blob.size);
          resolve(true);
        };
        request.onerror = () => {
          console.error('[SW Persistent] Failed to store:', url, request.error);
          reject(request.error);
        };
      });
    } catch (error) {
      console.error('[SW Persistent] Store error:', error);
      return false;
    }
  }
  
  detectVariant(url) {
    if (url.includes('thumb') || url.includes('thumbnail')) return 'thumb';
    if (url.includes('large')) return 'large';
    if (url.includes('medium')) return 'medium';
    return 'original';
  }
  
  async getStorageInfo() {
    try {
      const db = await this.dbPromise;
      const tx = db.transaction([STORES.images], 'readonly');
      const store = tx.objectStore(STORES.images);
      const countRequest = store.count();
      
      return new Promise((resolve) => {
        countRequest.onsuccess = () => {
          resolve({
            count: countRequest.result,
            dbName: DB_NAME
          });
        };
      });
    } catch (error) {
      console.error('[SW Persistent] Storage info error:', error);
      return { count: 0, dbName: DB_NAME };
    }
  }
}

// Initialize persistent cache immediately
let persistentCache = new PersistentImageCache();

self.addEventListener('install', event => {
  console.log('[SW Persistent] Installing version:', CACHE_VERSION);
  
  event.waitUntil(
    caches.open(CACHE_NAME).then(cache => {
      console.log('[SW Persistent] Caching app shell');
      return cache.addAll(urlsToCache);
    }).then(() => {
      console.log('[SW Persistent] Skipping waiting');
      return self.skipWaiting();
    })
  );
});

self.addEventListener('activate', event => {
  console.log('[SW Persistent] Activating version:', CACHE_VERSION);
  
  event.waitUntil(
    caches.keys().then(cacheNames => {
      return Promise.all(
        cacheNames
          .filter(cacheName => cacheName.startsWith('shock-collar-cache-') && cacheName !== CACHE_NAME)
          .map(cacheName => {
            console.log('[SW Persistent] Removing old cache:', cacheName);
            return caches.delete(cacheName);
          })
      );
    }).then(() => {
      // Immediately claim all clients
      console.log('[SW Persistent] Claiming all clients');
      return self.clients.claim();
    })
  );
});

// Helper function to determine if URL should be cached
function shouldCache(url) {
  // Don't cache admin routes
  if (url.includes('/admin/')) {
    return false;
  }
  
  // Skip JavaScript files to avoid stale code in development
  if (url.includes('.js') && url.includes('/assets/')) {
    console.log('[SW Persistent] Skipping JS file to avoid stale code:', url.substring(0, 80));
    return false;
  }
  
  // Cache all Active Storage URLs (Rails 8 patterns)
  if (url.includes('/rails/active_storage/')) {
    console.log('[SW Persistent] Active Storage URL detected:', url.substring(0, 100) + '...');
    return true;
  }
  
  // Cache S3 URLs for Active Storage (production)
  if (url.includes('.s3.') && url.includes('.amazonaws.com/')) {
    console.log('[SW Persistent] S3 URL detected:', url.substring(0, 100) + '...');
    return true;
  }
  
  // Cache CSS and font assets only
  if (url.includes('/assets/') && (url.endsWith('.css') || url.endsWith('.woff2') || url.endsWith('.woff'))) {
    return true;
  }
  
  return false;
}

// Enhanced fetch handler with IndexedDB
self.addEventListener('fetch', event => {
  const url = event.request.url;
  
  // Handle image requests with persistent storage
  if (shouldCache(url)) {
    console.log('[SW Persistent] 🎯 Intercepting:', url.substring(0, 100) + '...');
    event.respondWith(
      (async () => {
        // Try IndexedDB first
        if (persistentCache) {
          const cachedResponse = await persistentCache.getImage(url);
          if (cachedResponse) {
            console.log('[SW Persistent] IndexedDB hit:', url);
            return cachedResponse;
          }
        }
        
        // Try regular cache
        const cacheResponse = await caches.match(event.request);
        if (cacheResponse) {
          console.log('[SW Persistent] Cache hit:', url);
          // Store in IndexedDB for next time
          if (persistentCache) {
            const ct = cacheResponse.headers.get('Content-Type') || '';
            if (ct.startsWith('image/')) {
              persistentCache.storeImage(url, cacheResponse.clone());
            }
          }
          return cacheResponse;
        }
        
        // Fallback to network
        try {
          // Clone the request to modify headers if needed
          const modifiedRequest = new Request(event.request, {
            mode: 'cors',
            credentials: 'omit'
          });
          
          const response = await fetch(modifiedRequest);
          console.log('[SW Persistent] Network response type:', response.type, 'for:', url.substring(0, 100));
          
          if (response.ok) {
            // Always try to cache the response for future loads (even if opaque)
            try {
              const cache = await caches.open(CACHE_NAME);
              await cache.put(event.request, response.clone());
            } catch (e) {
              console.warn('[SW Persistent] Failed to put in cache:', e);
            }

            // Store binary in IndexedDB only for images with readable bodies
            try {
              const contentType = response.headers.get('Content-Type') || '';
              if (persistentCache && contentType.startsWith('image/')) {
                persistentCache.storeImage(url, response.clone());
              }
            } catch (_) {
              // Likely an opaque response; skip IDB storage
            }

            console.log('[SW Persistent] Cached from network:', url.substring(0, 100));
          }
          return response;
        } catch (error) {
          console.error('[SW Persistent] Fetch failed:', url, error);
          // Return a placeholder if offline
          return new Response('Image unavailable offline', { status: 503 });
        }
      })()
    );
  }
  // Handle other cacheable requests
  else if (shouldCache(url)) {
    event.respondWith(
      caches.match(event.request).then(response => {
        if (response) {
          console.log('[SW Persistent] Cache hit:', url);
          return response;
        }
        
        return fetch(event.request).then(response => {
          if (response.ok) {
            return caches.open(CACHE_NAME).then(cache => {
              cache.put(event.request, response.clone());
              return response;
            });
          }
          return response;
        });
      })
    );
  }
  // Handle navigation requests with network-first strategy
  else if (event.request.mode === 'navigate') {
    event.respondWith(
      fetch(event.request).catch(() => {
        return caches.match('/');
      })
    );
  }
});

// Handle messages from the client
self.addEventListener('message', event => {
  if (event.data && event.data.type === 'GET_STORAGE_INFO') {
    if (persistentCache) {
      persistentCache.getStorageInfo().then(info => {
        event.ports[0].postMessage({
          type: 'STORAGE_INFO',
          data: info
        });
      });
    }
  }
  
  if (event.data && event.data.type === 'SKIP_WAITING') {
    self.skipWaiting();
  }
});

console.log('[SW Persistent] Service Worker loaded with IndexedDB support');
