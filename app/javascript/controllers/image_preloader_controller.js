import { Controller } from "@hotwired/stimulus"
import storageManager from "persistent_storage"

// Image Preloader Controller
// Manages bulk downloading and persistent caching of gallery images
export default class extends Controller {
  static targets = ["progress", "status", "button", "container", "details"]
  
  async connect() {
    console.log("Image preloader connected");
    console.log("Storage manager available:", !!storageManager);
    console.log("Service worker controller:", navigator.serviceWorker?.controller?.scriptURL);
    this.imageUrls = new Set();
    this.downloadQueue = [];
    this.isDownloading = false;
    this.batchSize = 3; // Download 3 images concurrently
    
    try {
      // Wait for service worker to be ready
      if ('serviceWorker' in navigator) {
        const registration = await navigator.serviceWorker.ready;
        const activeWorker = navigator.serviceWorker.controller || registration.active;
        console.log("Service worker ready, active worker:", activeWorker?.scriptURL);
        console.log("Service worker state:", activeWorker?.state);
      }
      
      // Check initial storage status
      await this.checkStorageStatus();
      
      // Collect all image URLs on the page
      this.collectImageUrls();
    } catch (error) {
      console.error("Error in image preloader connect:", error);
      if (this.hasStatusTarget) {
        this.statusTarget.innerHTML = '<div class="text-red-400">Error initializing storage</div>';
      }
    }
  }
  
  async checkStorageStatus() {
    try {
      // Get storage estimate
      const estimate = await storageManager.getStorageEstimate();
      const isPersisted = await storageManager.checkPersisted();
      
      // Get IndexedDB info
      const dbInfo = await storageManager.getIndexedDBInfo();
      let imageCount = 0;
      
      if (dbInfo && dbInfo.length > 0) {
        for (const db of dbInfo) {
          for (const store of db.stores) {
            if (store.name === 'images') {
              imageCount = store.count;
            }
          }
        }
      }
      
      // Get service worker storage info
      const swInfo = await storageManager.checkServiceWorkerStorage();
      if (swInfo) {
        imageCount = swInfo.count || imageCount;
      }
      
      // Update UI
      if (this.hasStatusTarget) {
        const usageText = estimate ? 
          `${estimate.percent}% used (${storageManager.formatBytes(estimate.usage)} / ${storageManager.formatBytes(estimate.quota)})` :
          'Unable to determine';
        
        this.statusTarget.innerHTML = `
          <div class="space-y-2 text-sm">
            <div class="flex justify-between">
              <span class="text-gray-400">Storage:</span>
              <span class="text-white">${usageText}</span>
            </div>
            <div class="flex justify-between">
              <span class="text-gray-400">Persistent:</span>
              <span class="${isPersisted ? 'text-green-400' : 'text-yellow-400'}">
                ${isPersisted ? '✓ Enabled' : '✗ Disabled'}
              </span>
            </div>
            <div class="flex justify-between">
              <span class="text-gray-400">Cached Images:</span>
              <span class="text-white">${imageCount}</span>
            </div>
          </div>
        `;
      }
      
      // Show appropriate button based on persistence status
      if (!isPersisted && this.hasButtonTarget) {
        this.showPersistencePrompt();
      } else if (this.hasButtonTarget) {
        this.showPreloadButton();
      }
    } catch (error) {
      console.error('Error checking storage status:', error);
      if (this.hasStatusTarget) {
        this.statusTarget.innerHTML = '<p class="text-red-400">Error checking storage status</p>';
      }
    }
  }
  
  showPersistencePrompt() {
    this.buttonTarget.innerHTML = `
      <button 
        class="w-full bg-yellow-600 hover:bg-yellow-700 text-black font-bold px-4 py-2 rounded transition-colors"
        data-action="click->image-preloader#requestPersistence">
        Enable Permanent Storage
      </button>
      <p class="text-xs text-gray-400 mt-2">
        Required for offline access
      </p>
    `;
  }
  
  async showPreloadButton() {
    // Re-collect URLs in case new images were loaded
    this.collectImageUrls();
    const totalImages = this.imageUrls.size;
    let hasActiveWorker = false;
    
    if ('serviceWorker' in navigator) {
      const registration = await navigator.serviceWorker.ready;
      hasActiveWorker = !!(navigator.serviceWorker.controller || registration.active);
      console.log('🔍 PRELOADER: Service worker active?', hasActiveWorker, 'Controller:', !!navigator.serviceWorker.controller, 'Active:', !!registration.active);
    }
    
    this.buttonTarget.innerHTML = `
      ${!hasActiveWorker ? `
        <div class="bg-yellow-600 text-black p-2 rounded mb-2 text-sm">
          ⚠️ Service Worker not active. Refresh page or click below.
        </div>
        <button 
          class="w-full bg-yellow-600 hover:bg-yellow-700 text-black font-bold px-4 py-2 rounded transition-colors mb-2"
          data-action="click->image-preloader#activateServiceWorker">
          Activate Service Worker
        </button>
      ` : ''}
      <button 
        class="w-full bg-blue-600 hover:bg-blue-700 text-white font-bold px-4 py-2 rounded transition-colors"
        data-action="click->image-preloader#testCaching"
        ${this.isDownloading || !hasActiveWorker ? 'disabled' : ''}>
        ${this.isDownloading ? 'Testing...' : 'Test Cache (2 images)'}
      </button>
      <button 
        class="w-full mt-1 bg-red-600 hover:bg-red-700 text-white font-bold px-4 py-2 rounded transition-colors"
        data-action="click->image-preloader#startPreloading"
        ${this.isDownloading || !hasActiveWorker ? 'disabled' : ''}>
        ${this.isDownloading ? 'Downloading...' : `Cache All Images (${totalImages})`}
      </button>
      <button 
        class="w-full mt-1 bg-yellow-600 hover:bg-yellow-700 text-black font-bold px-4 py-1 rounded transition-colors text-xs"
        data-action="click->image-preloader#testLoadImages">
        🧪 Test Load Visible Images
      </button>
      <button 
        class="w-full mt-2 bg-gray-700 hover:bg-gray-600 text-white px-4 py-2 rounded transition-colors text-sm"
        data-action="click->image-preloader#clearCache">
        Clear Cache
      </button>
    `;
  }
  
  async activateServiceWorker() {
    console.log('Attempting to activate service worker...');
    window.location.reload();
  }
  
  async requestPersistence() {
    try {
      const granted = await storageManager.requestPersistence();
      
      if (granted) {
        if (this.hasButtonTarget) {
          this.buttonTarget.innerHTML = `
            <div class="text-green-400 text-center">
              <p class="font-bold">✓ Permanent storage enabled!</p>
              <p class="text-xs mt-1">Images will persist indefinitely</p>
            </div>
          `;
        }
        
        // Refresh status and show preload button after a delay
        setTimeout(() => {
          this.checkStorageStatus();
        }, 2000);
      } else {
        if (this.hasButtonTarget) {
          this.buttonTarget.innerHTML = `
            <div class="text-yellow-400 text-center">
              <p>Browser denied persistent storage</p>
              <p class="text-xs mt-1 text-gray-400">This is normal for dev environments</p>
              <p class="text-xs mt-1">Images will still be cached but may be cleared if device runs low on space</p>
              <p class="text-xs mt-2 text-blue-400">Tip: Bookmark this site to enable persistence</p>
            </div>
          `;
        }
        
        // Show preload button anyway - caching still works!
        setTimeout(() => {
          this.showPreloadButton();
        }, 4000);
      }
    } catch (error) {
      console.error('Error requesting persistence:', error);
      if (this.hasButtonTarget) {
        this.buttonTarget.innerHTML = '<p class="text-red-400">Error enabling persistence</p>';
      }
    }
  }
  
  collectImageUrls() {
    // Find all images with Active Storage URLs (both src and data-src)
    const allImages = document.querySelectorAll('img');
    console.log(`🔍 PRELOADER: Checking ${allImages.length} img elements`);
    
    let railsCount = 0;
    let s3Count = 0;
    let dataRailsCount = 0;
    let dataS3Count = 0;
    
    allImages.forEach(img => {
      // Check src attribute for Active Storage URLs (Rails paths)
      if (img.src && img.src.includes('/rails/active_storage')) {
        this.imageUrls.add(img.src);
        railsCount++;
      }
      
      // Check src attribute for S3 URLs (production)
      if (img.src && img.src.includes('.s3.') && img.src.includes('.amazonaws.com/')) {
        this.imageUrls.add(img.src);
        s3Count++;
      }
      
      // Check data-src attribute for lazy loaded Active Storage images (Rails paths)
      if (img.dataset.src && img.dataset.src.includes('/rails/active_storage')) {
        this.imageUrls.add(img.dataset.src);
        dataRailsCount++;
      }
      
      // Check data-src attribute for lazy loaded S3 URLs (production)
      if (img.dataset.src && img.dataset.src.includes('.s3.') && img.dataset.src.includes('.amazonaws.com/')) {
        this.imageUrls.add(img.dataset.src);
        dataS3Count++;
      }
    });
    
    console.log(`🔍 PRELOADER: Found ${this.imageUrls.size} unique images to cache`);
    console.log(`   - src Rails: ${railsCount}, src S3: ${s3Count}`);
    console.log(`   - data-src Rails: ${dataRailsCount}, data-src S3: ${dataS3Count}`);
    
    // Debug: Show first few URLs
    if (this.imageUrls.size > 0) {
      console.log('🔍 PRELOADER: Sample URLs:', Array.from(this.imageUrls).slice(0, 3));
    } else {
      console.log('🔍 PRELOADER: No Active Storage URLs found. Checking all img elements:');
      const sampleImages = Array.from(document.querySelectorAll('img')).slice(0, 3);
      sampleImages.forEach((img, i) => {
        console.log(`🔍 PRELOADER: Image ${i}:`, { src: img.src, dataSrc: img.dataset.src });
      });
    }
  }
  
  async testCaching() {
    // First test if service worker is intercepting
    console.log('🧪 Testing service worker interception...');
    
    // Try fetching a test URL to see if SW intercepts
    const testUrl = 'https://shock-collar-portraits-2025.s3.us-west-2.amazonaws.com/test';
    try {
      const response = await fetch(testUrl);
      console.log('🧪 Test fetch response type:', response.type);
    } catch (e) {
      console.log('🧪 Test fetch error (expected):', e.message);
    }
    
    await this.startPreloading(2);
  }
  
  async startPreloading(eventOrLimit = null) {
    // Handle both event object (from button click) and numeric limit
    let limitCount = null;
    if (typeof eventOrLimit === 'number') {
      limitCount = eventOrLimit;
    }
    
    console.log('🚀 PRELOADER: startPreloading called with limit:', limitCount);
    
    if (this.isDownloading) {
      console.log('Download already in progress');
      return;
    }
    
    this.isDownloading = true;
    const allUrls = Array.from(this.imageUrls);
    this.downloadQueue = limitCount ? allUrls.slice(0, limitCount) : allUrls;
    const total = this.downloadQueue.length;
    let completed = 0;
    let failed = 0;
    
    // Update button to show it's downloading
    this.showPreloadButton();
    
    // Show progress bar
    if (this.hasProgressTarget) {
      this.progressTarget.innerHTML = `
        <div class="mt-3">
          <div class="flex justify-between text-xs text-gray-400 mb-1">
            <span>Downloading...</span>
            <span id="progress-text">0 / ${total}</span>
          </div>
          <div class="w-full bg-gray-700 rounded-full h-2">
            <div id="progress-bar" class="bg-red-600 h-2 rounded-full transition-all duration-300" style="width: 0%"></div>
          </div>
          <div id="progress-status" class="text-xs text-gray-400 mt-1"></div>
        </div>
      `;
    }
    
    // Process downloads in batches
    while (this.downloadQueue.length > 0) {
      const batch = this.downloadQueue.splice(0, this.batchSize);
      
      await Promise.all(batch.map(async (url) => {
        try {
          console.log('🔄 Fetching for cache:', url);
          
          // Fetch normally to allow service worker interception
          const response = await fetch(url);
          
          console.log('📡 Response headers:', {
            'x-cache': response.headers.get('X-Cache'),
            'cache-control': response.headers.get('Cache-Control'),
            'content-type': response.headers.get('Content-Type'),
            'access-control-allow-origin': response.headers.get('Access-Control-Allow-Origin'),
            'response-type': response.type,
            status: response.status
          });
          
          if (response.ok) {
            completed++;
            console.log(`✅ Fetch success:`, url.substring(0, 80) + '...');
          } else {
            failed++;
            console.error(`❌ Fetch failed: ${url.substring(0, 80)}..., status: ${response.status}`);
          }
        } catch (error) {
          failed++;
          console.error(`Error caching: ${url}`, error);
        }
        
        // Update progress
        this.updateProgress(completed, failed, total);
      }));
      
      // Small delay between batches to avoid overwhelming the server
      if (this.downloadQueue.length > 0) {
        await new Promise(resolve => setTimeout(resolve, 100));
      }
    }
    
    // Download complete
    this.isDownloading = false;
    this.onDownloadComplete(completed, failed, total);
  }
  
  updateProgress(completed, failed, total) {
    const percent = Math.round((completed + failed) / total * 100);
    
    const progressBar = document.getElementById('progress-bar');
    const progressText = document.getElementById('progress-text');
    const progressStatus = document.getElementById('progress-status');
    
    if (progressBar) {
      progressBar.style.width = `${percent}%`;
    }
    
    if (progressText) {
      progressText.textContent = `${completed + failed} / ${total}`;
    }
    
    if (progressStatus) {
      if (failed > 0) {
        progressStatus.innerHTML = `<span class="text-yellow-400">⚠ ${failed} failed</span>`;
      }
    }
  }
  
  onDownloadComplete(completed, failed, total) {
    // Update progress to show completion
    if (this.hasProgressTarget) {
      const allSuccess = failed === 0;
      const message = allSuccess ? 
        `✓ All ${completed} images cached successfully!` :
        `✓ Cached ${completed} of ${total} images (${failed} failed)`;
      
      this.progressTarget.innerHTML = `
        <div class="mt-3 text-center">
          <p class="${allSuccess ? 'text-green-400' : 'text-yellow-400'} font-bold">
            ${message}
          </p>
          <p class="text-xs text-gray-400 mt-2">
            Images are now available offline
          </p>
        </div>
      `;
    }
    
    // Refresh storage status
    this.checkStorageStatus();
    
    // Hide the progress after 5 seconds
    setTimeout(() => {
      if (this.hasProgressTarget) {
        this.progressTarget.innerHTML = '';
      }
    }, 5000);
  }
  
  async clearCache() {
    if (confirm('This will clear all cached images. Are you sure?')) {
      try {
        const cleared = await storageManager.clearAllStorage();
        
        if (cleared) {
          if (this.hasProgressTarget) {
            this.progressTarget.innerHTML = `
              <div class="mt-3 text-center text-green-400">
                <p class="font-bold">✓ Cache cleared successfully</p>
              </div>
            `;
          }
          
          // Refresh the page to reload service worker
          setTimeout(() => {
            window.location.reload();
          }, 1500);
        } else {
          if (this.hasProgressTarget) {
            this.progressTarget.innerHTML = `
              <div class="mt-3 text-center text-red-400">
                <p>Failed to clear cache</p>
              </div>
            `;
          }
        }
      } catch (error) {
        console.error('Error clearing cache:', error);
        if (this.hasProgressTarget) {
          this.progressTarget.innerHTML = `
            <div class="mt-3 text-center text-red-400">
              <p>Error: ${error.message}</p>
            </div>
          `;
        }
      }
    }
  }
  
  // Manual test to load visible images immediately
  testLoadImages() {
    console.log('🧪 TEST: Manually loading visible images')
    
    // Find all lazy-images controllers on the page
    const lazyControllers = document.querySelectorAll('[data-controller*="lazy-images"]')
    console.log('Found', lazyControllers.length, 'lazy-images controllers')
    
    lazyControllers.forEach((element, index) => {
      // Find images with data-src within this controller
      const lazyImages = element.querySelectorAll('img[data-src]')
      console.log(`Controller ${index}: Found ${lazyImages.length} lazy images`)
      
      // Load first few images from each controller
      Array.from(lazyImages).slice(0, 2).forEach((img, imgIndex) => {
        console.log(`Loading test image ${imgIndex}:`, img.dataset.src.substring(0, 100) + '...')
        this.loadTestImage(img)
      })
    })
  }
  
  loadTestImage(img) {
    const src = img.dataset.src
    if (!src) return
    
    console.log('🧪 TEST Loading:', src)
    
    // Create a new image to preload
    const imageLoader = new Image()
    
    imageLoader.onload = () => {
      console.log('✅ TEST Success:', src.substring(0, 100) + '...')
      img.src = src
      img.classList.add('loaded', 'test-loaded')
      img.removeAttribute('data-src')
      img.style.transition = 'opacity 0.3s ease-in-out'
      img.style.opacity = '1'
    }
    
    imageLoader.onerror = (error) => {
      console.error('❌ TEST Failed:', src.substring(0, 100) + '...', error)
      img.classList.add('error', 'test-error')
      img.style.backgroundColor = '#dc2626'
      img.style.opacity = '0.5'
    }
    
    // Start loading
    imageLoader.src = src
  }
  
  // Toggle visibility of the preloader panel
  togglePanel(event) {
    if (event) event.preventDefault();
    
    if (this.hasContainerTarget) {
      this.containerTarget.classList.toggle('hidden');
    }
  }
}