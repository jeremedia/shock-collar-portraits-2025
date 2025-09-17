import { Controller } from "@hotwired/stimulus"

// Preloader Screen Controller - Server-driven variant downloading
export default class extends Controller {
  static targets = [
    "overallProgressBar",
    "overallStatus",
    "currentPhoto",
    "photoGrid",
    "startButton",
    "skipButton",
    "completeForm",
    "skipForm",
    "phaseIndicator",
    "variantOverlay"
  ]
  
  static values = {
    photos: Array,
    sessions: Array,
    totalPhotos: Number,
    totalVariants: Number,
    estimatedSize: Number
  }
  
  connect() {
    console.log("Preloader screen connected");
    console.log(`Ready to cache ${this.totalPhotosValue} photos with ${this.totalVariantsValue} variants`);
    
    // Initialize state
    this.isDownloading = false;
    this.loadedVariants = 0;
    this.failedVariants = 0;
    // Scale client-side concurrency with available cores, capped
    const cores = (navigator.hardwareConcurrency || 8);
    this.concurrentDownloads = Math.min(8, Math.max(4, Math.floor(cores)));
    this.variantOrder = ['tiny_square_thumb', 'thumb', 'face_thumb', 'medium', 'large'];
    
    // Initialize variant URLs cache
    this.variantUrlsCache = {};
    
    // Create photo grid preview
    this.createPhotoGrid();
    
    // Load or fetch photo metadata, then detect cached photos
    this.initializePhotoMetadata();
  
    // Auto-start for better UX (optional)
    // setTimeout(() => this.startDownload(), 1000);
  }

  async ensureServiceWorkerControl(timeoutMs = 6000) {
    if (!('serviceWorker' in navigator)) return true;
    try {
      const registration = await navigator.serviceWorker.ready;
      if (navigator.serviceWorker.controller) return true;

      // Try to activate any waiting worker
      if (registration.waiting) {
        registration.waiting.postMessage({ type: 'SKIP_WAITING' });
      }

      return await new Promise((resolve) => {
        let resolved = false;
        const timer = setTimeout(() => { if (!resolved) resolve(false); }, timeoutMs);
        navigator.serviceWorker.addEventListener('controllerchange', () => {
          if (!resolved) {
            resolved = true;
            clearTimeout(timer);
            resolve(true);
          }
        }, { once: true });
      });
    } catch (_) {
      return false;
    }
  }

  // --- URL helpers to avoid absolute/relative mismatches between SW and app ---
  toAbsolute(url) {
    try {
      if (!url) return url;
      if (url.startsWith('http://') || url.startsWith('https://')) return url;
      if (url.startsWith('/')) return `${location.origin}${url}`;
      // Fallback: let URL resolve relative to current location
      return new URL(url, location.href).toString();
    } catch (_) { return url; }
  }

  toRelative(url) {
    try {
      if (!url) return url;
      const origin = location.origin;
      return url.startsWith(origin) ? url.slice(origin.length) || '/' : url;
    } catch (_) { return url; }
  }

  shouldTreatAsImageCache(url) {
    if (!url) return false;
    try {
      const u = this.toAbsolute(url);
      if (u.includes('/rails/active_storage/')) return true;
      if (u.includes('.s3.') && u.includes('.amazonaws.com/')) return true;
      return false;
    } catch (_) { return false; }
  }

  buildCachedUrlSetFromRecords(records) {
    const set = new Set();
    if (!Array.isArray(records)) return set;
    records.forEach(rec => {
      // Only consider image-like entries
      const ct = rec && (rec.contentType || (rec.blob && rec.blob.type)) || '';
      if (ct && !ct.startsWith('image/')) return;
      const u = rec && rec.url;
      if (!u) return;
      try {
        const abs = this.toAbsolute(u);
        const rel = this.toRelative(u);
        set.add(abs);
        set.add(rel);
      } catch (_) {
        set.add(u);
      }
    });
    return set;
  }
  
  createPhotoGrid() {
    if (!this.hasPhotoGridTarget) return;
    
    // Start with empty grid - photos will be added as they're loaded
    this.photoGridTarget.innerHTML = `
      <div class="text-gray-500 text-center col-span-full py-8">
        Photos will appear here as they are cached...
      </div>
    `;
    
    // Initialize the map for tracking photo elements
    this.photoElements = new Map();
    this.maxGridPhotos = 100; // Limit grid size for performance
  }
  
  async startDownload() {
    // Ensure SW will intercept before bulk caching
    const hasControl = await this.ensureServiceWorkerControl();
    if (!hasControl) {
      console.warn('Service worker not controlling this page yet; reload recommended.');
    }
    if (this.isDownloading) return;
    
    console.log("Starting download of all variants...");
    this.isDownloading = true;
    this.startTime = Date.now();
    this.cancelRequested = false;
    
    // Update UI - disable all buttons
    this.startButtonTarget.disabled = true;
    this.startButtonTarget.textContent = 'Downloading...';
    this.startButtonTarget.classList.remove('bg-red-600', 'hover:bg-red-700');
    this.startButtonTarget.classList.add('bg-gray-600');
    
    // Change skip button to cancel
    this.skipButtonTarget.textContent = 'Cancel Download';
    this.skipButtonTarget.classList.remove('bg-gray-700', 'hover:bg-gray-600');
    this.skipButtonTarget.classList.add('bg-orange-600', 'hover:bg-orange-700');
    
    // Disable test button if it exists
    const testButton = this.element.querySelector('[data-action*="downloadOneUncached"]');
    if (testButton) {
      testButton.disabled = true;
      testButton.classList.add('opacity-50', 'cursor-not-allowed');
    }
    
    // Process each variant type in phases
    for (const variantType of this.variantOrder) {
      if (this.cancelRequested) {
        console.log('Download cancelled by user');
        break;
      }
      await this.downloadVariantPhase(variantType);
    }
    
    // Check if cancelled or completed
    if (this.cancelRequested) {
      this.onDownloadCancelled();
    } else {
      this.onDownloadComplete();
    }
  }
  
  async downloadVariantPhase(variantType) {
    console.log(`Starting phase: ${variantType}`);
    
    // Update phase indicator
    this.updatePhaseIndicator(variantType, 'active');
    
    // Use cached metadata instead of fetching URLs!
    const variantUrls = {};
    for (const photo of this.photoMetadata) {
      if (photo.variants[variantType]) {
        variantUrls[photo.id] = photo.variants[variantType];
      }
    }
    
    // Filter photos that have URLs for this variant
    const photosWithVariant = this.photoMetadata.filter(p => p.variants[variantType]);
    
    if (photosWithVariant.length === 0) {
      console.log(`No photos with ${variantType} variant, skipping phase`);
      this.updatePhaseIndicator(variantType, 'complete');
      return;
    }
    
    // Process in batches
    for (let i = 0; i < photosWithVariant.length; i += this.concurrentDownloads) {
      if (!this.isDownloading || this.cancelRequested) break; // Allow cancellation
      
      const batch = photosWithVariant.slice(i, i + this.concurrentDownloads);
      
      // Add placeholder cards for photos that will be downloaded
      if (variantType === 'tiny_square_thumb') {
        batch.forEach(photo => {
          if (!this.photoElements.has(photo.id)) {
            this.addPhotoPlaceholder(photo);
          }
        });
      }
      
      await Promise.all(batch.map(async (photo) => {
        await this.downloadVariant(photo, variantType, variantUrls[photo.id]);
      }));
      
      // Update current photo indicator
      if (this.hasCurrentPhotoTarget) {
        this.currentPhotoTarget.textContent = 
          `Processing ${variantType}: Photo ${Math.min(i + this.concurrentDownloads, photosWithVariant.length)} of ${photosWithVariant.length}`;
      }
    }
    
    this.updatePhaseIndicator(variantType, 'complete');
  }
  
  async downloadVariant(photo, variantType, url) {
    if (!url) return;
    
    try {
      // Fetch through service worker for caching
      const response = await fetch(url);
      
      if (response.ok) {
        this.loadedVariants++;
        console.log(`✓ Loaded ${variantType} for photo ${photo.id}`);
        
        // Update UI for this photo
        this.updatePhotoCard(photo, variantType, url);
        
        // Fallback: also persist in IDB from the page context
        try { await this.storeImageLocally(url, response.clone()); } catch (_) {}

        // Update overall progress
        this.updateOverallProgress();
      } else {
        throw new Error(`HTTP ${response.status}`);
      }
    } catch (error) {
      this.failedVariants++;
      console.error(`✗ Failed ${variantType} for photo ${photo.id}:`, error.message);
      
      // Still update progress even for failures
      this.updateOverallProgress();
    }
  }
  
  addPhotoPlaceholder(photo) {
    if (!this.hasPhotoGridTarget) return;
    
    // Remove the initial placeholder message if it exists
    const placeholder = this.photoGridTarget.querySelector('.text-gray-500');
    if (placeholder) {
      placeholder.remove();
    }
    
    // Limit grid size for performance
    const currentPhotos = this.photoGridTarget.querySelectorAll('.photo-card');
    if (currentPhotos.length >= this.maxGridPhotos) {
      // Remove the oldest photo (last in grid)
      const oldestPhoto = currentPhotos[currentPhotos.length - 1];
      const oldPhotoId = oldestPhoto.dataset.photoId;
      this.photoElements.delete(parseInt(oldPhotoId));
      oldestPhoto.remove();
    }
    
    // Create placeholder card with loading animation
    const placeholderHtml = `
      <div class="photo-card relative bg-gray-800 rounded overflow-hidden aspect-square animate-fadeIn cursor-pointer hover:ring-2 hover:ring-yellow-500" 
           data-photo-id="${photo.id}"
           data-action="click->preloader-screen#showVariants"
           style="animation-delay: 0ms;">
        <div class="photo-thumb w-full h-full bg-gray-700 animate-pulse"></div>
        <div class="progress-ring">
          <svg class="w-8 h-8 transform -rotate-90">
            <circle cx="16" cy="16" r="14" stroke="rgba(255,255,255,0.1)" stroke-width="2" fill="none" />
            <circle cx="16" cy="16" r="14" stroke="rgba(239,68,68,1)" stroke-width="2" fill="none"
                    stroke-dasharray="88"
                    stroke-dashoffset="88"
                    class="progress-circle transition-all duration-300" />
          </svg>
          <span class="absolute inset-0 flex items-center justify-center text-xs text-white font-bold">
            0%
          </span>
        </div>
        <div class="absolute bottom-0 left-0 right-0 p-0.5 bg-gradient-to-t from-black/80">
          <div class="flex gap-0.5 justify-center">
            ${this.variantOrder.map(v => {
              if (v === 'face_thumb' && !photo.has_faces) return '';
              return `<div class="variant-dot w-1 h-1 rounded-full bg-gray-600" data-variant="${v}"></div>`;
            }).join('')}
          </div>
        </div>
      </div>
    `;
    
    // Prepend to grid
    this.photoGridTarget.insertAdjacentHTML('afterbegin', placeholderHtml);
    const element = this.photoGridTarget.querySelector(`[data-photo-id="${photo.id}"]`);
    this.photoElements.set(photo.id, element);
  }
  
  updatePhotoCard(photo, variantType, url) {
    let element = this.photoElements.get(photo.id);
    
    // If photo isn't in the grid yet, add it
    if (!element && this.hasPhotoGridTarget) {
      // Remove the placeholder message if it exists
      const placeholder = this.photoGridTarget.querySelector('.text-gray-500');
      if (placeholder) {
        placeholder.remove();
      }
      
      // Limit grid size for performance
      const currentPhotos = this.photoGridTarget.querySelectorAll('.photo-card');
      if (currentPhotos.length >= this.maxGridPhotos) {
        // Remove the oldest photo (last in grid)
        const oldestPhoto = currentPhotos[currentPhotos.length - 1];
        const oldPhotoId = oldestPhoto.dataset.photoId;
        this.photoElements.delete(parseInt(oldPhotoId));
        oldestPhoto.remove();
      }
      
      // Create the photo card HTML
      const photoCardHtml = `
        <div class="photo-card relative bg-gray-800 rounded overflow-hidden aspect-square animate-fadeIn cursor-pointer hover:ring-2 hover:ring-yellow-500" 
             data-photo-id="${photo.id}"
             data-action="click->preloader-screen#showVariants"
             style="animation-delay: 0ms;">
          <div class="photo-thumb w-full h-full bg-gray-700"></div>
          <div class="progress-ring">
            <svg class="w-8 h-8 transform -rotate-90">
              <circle cx="16" cy="16" r="14" stroke="rgba(255,255,255,0.1)" stroke-width="2" fill="none" />
              <circle cx="16" cy="16" r="14" stroke="rgba(239,68,68,1)" stroke-width="2" fill="none"
                      stroke-dasharray="88"
                      stroke-dashoffset="88"
                      class="progress-circle transition-all duration-300" />
            </svg>
            <span class="absolute inset-0 flex items-center justify-center text-xs text-white font-bold">
              0%
            </span>
          </div>
          <div class="absolute bottom-0 left-0 right-0 p-0.5 bg-gradient-to-t from-black/80">
            <div class="flex gap-0.5 justify-center">
              ${this.variantOrder.map(v => {
                if (v === 'face_thumb' && !photo.has_faces) return '';
                return `<div class="variant-dot w-1 h-1 rounded-full bg-gray-600" data-variant="${v}"></div>`;
              }).join('')}
            </div>
          </div>
        </div>
      `;
      
      // Always prepend new photos to the beginning of the grid
      this.photoGridTarget.insertAdjacentHTML('afterbegin', photoCardHtml);
      element = this.photoGridTarget.querySelector(`[data-photo-id="${photo.id}"]`);
      this.photoElements.set(photo.id, element);
    }
    
    if (!element) return;
    
    // Update thumbnail if this is the first visible variant
    if (variantType === 'tiny_square_thumb' || variantType === 'thumb') {
      const thumbDiv = element.querySelector('.photo-thumb');
      if (thumbDiv && !thumbDiv.style.backgroundImage) {
        thumbDiv.style.backgroundImage = `url(${url})`;
        thumbDiv.style.backgroundSize = 'cover';
        thumbDiv.style.backgroundPosition = 'center';
        thumbDiv.classList.remove('bg-gray-700', 'animate-pulse');
      }
    }
    
    // Update variant dot
    const dot = element.querySelector(`.variant-dot[data-variant="${variantType}"]`);
    if (dot) {
      dot.classList.add('loaded');
    }
    
    // Update progress ring
    const loadedDots = element.querySelectorAll('.variant-dot.loaded').length;
    const totalDots = element.querySelectorAll('.variant-dot').length;
    const progress = totalDots > 0 ? (loadedDots / totalDots) * 100 : 0;
    
    const progressCircle = element.querySelector('.progress-circle');
    const progressText = element.querySelector('.progress-ring span');
    
    if (progressCircle) {
      const offset = 88 - (88 * progress / 100);
      progressCircle.style.strokeDashoffset = offset;
      
      if (progress === 100) {
        progressCircle.style.stroke = 'rgba(34,197,94,1)'; // green
        element.classList.add('loaded');
      } else if (progress > 0) {
        progressCircle.style.stroke = 'rgba(251,191,36,1)'; // amber
      }
    }
    
    if (progressText) {
      if (progress === 100) {
        progressText.innerHTML = '✓';
      } else {
        progressText.textContent = `${Math.round(progress)}%`;
      }
    }
  }
  
  updateOverallProgress() {
    const total = this.totalVariantsValue;
    const loaded = this.loadedVariants;
    const failed = this.failedVariants;
    const processed = loaded + failed;
    const progress = total > 0 ? (processed / total) * 100 : 0;
    
    // Update progress bar
    if (this.hasOverallProgressBarTarget) {
      this.overallProgressBarTarget.style.width = `${progress}%`;
    }
    
    // Update status text
    if (this.hasOverallStatusTarget) {
      const status = failed > 0 ? 
        `${loaded} loaded, ${failed} failed / ${total} variants (${Math.round(progress)}%)` :
        `${loaded} / ${total} variants (${Math.round(progress)}%)`;
      this.overallStatusTarget.textContent = status;
    }
    
    // Update time estimate
    if (this.startTime && progress > 5) {
      const elapsed = Date.now() - this.startTime;
      const estimatedTotal = elapsed / (progress / 100);
      const remaining = estimatedTotal - elapsed;
      const minutes = Math.ceil(remaining / 60000);
      
      if (this.hasCurrentPhotoTarget && minutes > 0) {
        const base = this.currentPhotoTarget.textContent.split(' • ~')[0];
        this.currentPhotoTarget.textContent = `${base} • ~${minutes}m remaining`;
      }
    }
  }
  
  updatePhaseIndicator(phase, status) {
    const indicators = this.phaseIndicatorTargets;
    const indicator = indicators.find(el => el.dataset.phase === phase);
    
    if (indicator) {
      const dot = indicator.querySelector('div');
      
      if (status === 'active') {
        dot.classList.remove('bg-gray-700');
        dot.classList.add('bg-yellow-500', 'animate-pulse');
      } else if (status === 'complete') {
        dot.classList.remove('bg-gray-700', 'bg-yellow-500', 'animate-pulse');
        dot.classList.add('bg-green-500');
      }
    }
  }
  
  onDownloadComplete() {
    console.log(`Download complete! Loaded ${this.loadedVariants} variants, ${this.failedVariants} failed`);
    this.isDownloading = false;
    
    // Update UI
    this.startButtonTarget.textContent = 'Complete!';
    this.startButtonTarget.classList.remove('bg-gray-600');
    this.startButtonTarget.classList.add('bg-green-600');
    
    this.skipButtonTarget.textContent = 'Continue to Gallery';
    
    if (this.hasCurrentPhotoTarget) {
      this.currentPhotoTarget.innerHTML = `
        <span class="text-green-400 font-bold">
          ✓ All variants cached successfully!
        </span>
      `;
    }
    
    // Auto-redirect after 3 seconds
    setTimeout(() => {
      this.completePreloader();
    }, 3000);
  }
  
  skipPreloader() {
    if (this.isDownloading) {
      // Cancel download
      this.cancelRequested = true;
      this.isDownloading = false;
      console.log('Cancelling download...');
    } else {
      // Skip without downloading
      this.submitSkipForm();
    }
  }
  
  onDownloadCancelled() {
    console.log('Download cancelled');
    this.isDownloading = false;
    
    // Re-enable buttons
    this.startButtonTarget.disabled = false;
    this.startButtonTarget.textContent = 'Resume Caching';
    this.startButtonTarget.classList.remove('bg-gray-600');
    this.startButtonTarget.classList.add('bg-red-600', 'hover:bg-red-700');
    
    this.skipButtonTarget.textContent = 'Skip for Now';
    this.skipButtonTarget.classList.remove('bg-orange-600', 'hover:bg-orange-700');
    this.skipButtonTarget.classList.add('bg-gray-700', 'hover:bg-gray-600');
    
    // Re-enable test button
    const testButton = this.element.querySelector('[data-action*="downloadOneUncached"]');
    if (testButton) {
      testButton.disabled = false;
      testButton.classList.remove('opacity-50', 'cursor-not-allowed');
    }
    
    if (this.hasCurrentPhotoTarget) {
      this.currentPhotoTarget.innerHTML = `
        <span class="text-orange-400">
          Download cancelled. ${this.loadedVariants} variants cached.
        </span>
      `;
    }
  }
  
  completePreloader() {
    // Submit the complete form which will set cookie and redirect
    if (this.hasCompleteFormTarget) {
      this.completeFormTarget.requestSubmit();
    }
  }
  
  submitSkipForm() {
    // Submit the skip form which will set cookie and redirect
    if (this.hasSkipFormTarget) {
      this.skipFormTarget.requestSubmit();
    }
  }
  
  async downloadOneUncached() {
    // Ensure SW is controlling so fetches populate caches/IDB
    const hasControl = await this.ensureServiceWorkerControl();
    if (!hasControl) {
      console.warn('Service worker not controlling this page yet; reload recommended.');
    }
    console.log('Finding a completely uncached photo to download ALL variants for testing...');
    
    // Open IndexedDB to check what's already cached
    const dbName = 'ShockCollarGallery';
    const db = await new Promise((resolve, reject) => {
      const request = indexedDB.open(dbName); // use current version
      request.onsuccess = () => resolve(request.result);
      request.onerror = () => reject(request.error);
      request.onupgradeneeded = (event) => {
        const db = event.target.result;
        if (!db.objectStoreNames.contains('images')) {
          db.createObjectStore('images', { keyPath: 'url' });
        }
      };
    });
    
    // Try to find a photo with NO cached variants
    let testPhoto = null;
    let photoVariantUrls = {};
    
    // Randomize starting point to avoid always checking the same photos
    const startIndex = Math.floor(Math.random() * Math.max(0, this.photosValue.length - 100));
    
    // Check photos to find one with zero cached variants
    for (let offset = 0; offset < this.photosValue.length; offset += 5) {
      // Wrap around to check all photos
      const i = (startIndex + offset) % this.photosValue.length;
      const batch = this.photosValue.slice(i, Math.min(i + 5, this.photosValue.length));
      const photoIds = batch.map(p => p.id);
      
      console.log(`Checking batch ${i}-${i+5} for completely uncached photos...`);
      
      // Fetch ALL variant URLs for these photos
      const allVariantUrls = {};
      for (const variantType of this.variantOrder) {
        const response = await fetch(`/preloader/variant_urls?${new URLSearchParams({
          'photo_ids[]': photoIds,
          variant: variantType
        })}`);
        
        if (response.ok) {
          const urls = await response.json();
          for (const [photoId, url] of Object.entries(urls)) {
            if (!allVariantUrls[photoId]) allVariantUrls[photoId] = {};
            allVariantUrls[photoId][variantType] = url;
          }
        }
      }
      
      // Check each photo to see if ANY of its variants are cached
      for (const photo of batch) {
        const variants = allVariantUrls[photo.id];
        if (!variants || Object.keys(variants).length === 0) continue;
        
        let hasAnyCached = false;
        
        // Check if ANY variant is cached
        for (const [variantType, url] of Object.entries(variants)) {
          const transaction = db.transaction(['images'], 'readonly');
          const store = transaction.objectStore('images');
          
          // The service worker stores with 'url' as the key
          const cachedEntry = await new Promise((resolve) => {
            const request = store.get(url);
            request.onsuccess = () => resolve(request.result);
            request.onerror = () => resolve(null);
          });
          
          if (cachedEntry) {
            console.log(`  Photo ${photo.id} has cached ${variantType}, skipping...`);
            hasAnyCached = true;
            break;
          }
        }
        
        if (!hasAnyCached) {
          // Found a completely uncached photo!
          console.log(`Found completely uncached photo ${photo.id} with ${Object.keys(variants).length} variants to cache`);
          testPhoto = photo;
          photoVariantUrls = variants;
          break;
        }
      }
      
      if (testPhoto) break; // Found one, stop searching
    }
    
    db.close();
    
    if (!testPhoto || Object.keys(photoVariantUrls).length === 0) {
      console.log('All photos have at least some cached variants! Clear IndexedDB to test again.');
      return;
    }
    
    // Download ALL variants of the uncached photo
    console.log(`Caching ALL ${Object.keys(photoVariantUrls).length} variants for photo ${testPhoto.id}:`);
    let successCount = 0;
    let failCount = 0;
    
    // Disable all buttons during test
    this.startButtonTarget.disabled = true;
    this.skipButtonTarget.disabled = true;
    const testButton = this.element.querySelector('[data-action*="downloadOneUncached"]');
    if (testButton) {
      testButton.disabled = true;
      testButton.textContent = 'Testing...';
      testButton.classList.add('opacity-50', 'cursor-not-allowed');
    }
    
    // Add placeholder for the test photo immediately
    this.addPhotoPlaceholder(testPhoto);
    
    // Update the overall status to show we're testing
    if (this.hasOverallStatusTarget) {
      this.overallStatusTarget.textContent = `Testing: Caching photo ${testPhoto.id}...`;
    }
    
    // Process each variant like the main download does
    for (const [variantType, url] of Object.entries(photoVariantUrls)) {
      // Update phase indicator for current variant
      this.updatePhaseIndicator(variantType, 'active');
      
      try {
        console.log(`  Fetching ${variantType}: ${url.substring(0, 80)}...`);
        
        // Update current photo indicator
        if (this.hasCurrentPhotoTarget) {
          this.currentPhotoTarget.textContent = `Testing ${variantType} for photo ${testPhoto.id}`;
        }
        
        // Fetch through service worker for caching
        const imgResponse = await fetch(url);
        
        if (imgResponse.ok) {
          successCount++;
          this.loadedVariants++;
          console.log(`  ✓ ${variantType} cached`);
          
          // Update the photo card in the grid
          this.updatePhotoCard(testPhoto, variantType, url);
          // Fallback: also persist in IDB from the page context
          try { await this.storeImageLocally(url, imgResponse.clone()); } catch (_) {}
          
          // Update overall progress
          this.updateOverallProgress();
        } else {
          failCount++;
          this.failedVariants++;
          console.error(`  ✗ ${variantType} failed: HTTP ${imgResponse.status}`);
          
          // Still update progress for failures
          this.updateOverallProgress();
        }
      } catch (error) {
        failCount++;
        this.failedVariants++;
        console.error(`  ✗ ${variantType} error:`, error.message);
        
        // Still update progress for failures
        this.updateOverallProgress();
      }
      
      // Mark phase as complete
      this.updatePhaseIndicator(variantType, 'complete');
    }
    
    // Update final status
    if (this.hasCurrentPhotoTarget) {
      this.currentPhotoTarget.innerHTML = `<span class="text-green-400">✓ Test complete: Photo ${testPhoto.id} - ${successCount} cached, ${failCount} failed</span>`;
    }
    
    // Re-enable all buttons
    this.startButtonTarget.disabled = false;
    this.skipButtonTarget.disabled = false;
    if (testButton) {
      testButton.disabled = false;
      testButton.textContent = 'Test Cache 1 Photo';
      testButton.classList.remove('opacity-50', 'cursor-not-allowed');
    }
    
    console.log(`✅ Test complete: Photo ${testPhoto.id} - ${successCount} variants cached, ${failCount} failed`);
  }

  async storeImageLocally(url, response) {
    try {
      const contentType = response.headers.get('Content-Type') || '';
      if (!contentType.startsWith('image/')) return;
      const blob = await response.blob();
      const db = await new Promise((resolve, reject) => {
        const req = indexedDB.open('ShockCollarGallery', 3);
        req.onsuccess = () => resolve(req.result);
        req.onerror = () => reject(req.error);
        req.onupgradeneeded = (event) => {
          const db = event.target.result;
          if (!db.objectStoreNames.contains('images')) {
            db.createObjectStore('images', { keyPath: 'url' });
          }
        };
      });
      const tx = db.transaction(['images'], 'readwrite');
      const store = tx.objectStore('images');
      const record = {
        url: this.toAbsolute(url),
        blob,
        contentType,
        size: blob.size,
        timestamp: Date.now(),
        variant: this.variantOrder.find(v => (url || '').includes(v)) || 'original'
      };
      await new Promise((resolve, reject) => {
        const putReq = store.put(record);
        putReq.onsuccess = () => resolve();
        putReq.onerror = () => reject(putReq.error);
      });
      try { db.close(); } catch (_) {}
      console.log('Stored locally in IDB (page):', record.url);
    } catch (e) {
      console.warn('Failed to store locally in IDB:', e);
    }
  }
  
  async showVariants(event) {
    const photoCard = event.currentTarget;
    const photoId = parseInt(photoCard.dataset.photoId);
    const photo = this.photosValue.find(p => p.id === photoId);
    
    if (!photo) {
      console.error('Photo not found:', photoId);
      return;
    }
    
    console.log(`Showing cached variants for photo ${photoId}`);
    
    // Create overlay if it doesn't exist
    if (!this.variantOverlay) {
      this.createVariantOverlay();
    }
    
    // Show loading state
    this.variantOverlay.innerHTML = `
      <div class="fixed inset-0 bg-black bg-opacity-90 z-50 flex items-center justify-center">
        <div class="text-white text-xl">Loading variants...</div>
      </div>
    `;
    this.variantOverlay.classList.remove('hidden');
    
    // Fetch all variant URLs for this photo
    const variants = {};
    for (const variantType of this.variantOrder) {
      const response = await fetch(`/preloader/variant_urls?${new URLSearchParams({
        'photo_ids[]': [photoId],
        variant: variantType
      })}`);
      
      if (response.ok) {
        const urls = await response.json();
        if (urls[photoId]) {
          variants[variantType] = urls[photoId];
        }
      }
    }
    
    // Create the overlay content with all variants
    const variantHtml = Object.entries(variants).map(([type, url]) => {
      // Determine max sizes for each variant type
      let maxWidth = '100%';
      let maxHeight = '100%';
      
      if (type === 'tiny_square_thumb') {
        maxWidth = '40px';
        maxHeight = '40px';
      } else if (type === 'thumb' || type === 'face_thumb') {
        maxWidth = '300px';
        maxHeight = '300px';
      } else if (type === 'medium') {
        maxWidth = '800px';
        maxHeight = '800px';
      } else if (type === 'large') {
        maxWidth = '90vw';
        maxHeight = '80vh';
      }
      
      return `
        <div class="flex flex-col items-center">
          <h3 class="text-yellow-500 font-bold mb-2">${type}</h3>
          <div class="bg-gray-800 p-2 rounded">
            <img src="${url}" 
                 alt="${type}" 
                 class="block"
                 style="max-width: ${maxWidth}; max-height: ${maxHeight}; object-fit: contain;"
                 onerror="this.parentElement.innerHTML='<span class=\\'text-red-500\\'>Failed to load from cache</span>'"
            />
          </div>
          <p class="text-gray-400 text-xs mt-1">${url.substring(0, 50)}...</p>
        </div>
      `;
    }).join('');
    
    // Update overlay with all variants
    this.variantOverlay.innerHTML = `
      <div class="fixed inset-0 bg-black bg-opacity-95 z-50 overflow-auto" 
           data-action="click->preloader-screen#closeVariantOverlay">
        <div class="container mx-auto p-8">
          <div class="bg-gray-900 rounded-lg p-6" 
               data-action="click->preloader-screen#stopPropagation">
            <div class="flex justify-between items-center mb-6">
              <h2 class="text-2xl font-bold text-white">
                Photo ${photoId} - Cached Variants
              </h2>
              <button class="text-gray-400 hover:text-white text-2xl"
                      data-action="click->preloader-screen#closeVariantOverlay">
                ×
              </button>
            </div>
            
            <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
              ${variantHtml}
            </div>
            
            <div class="mt-6 text-center">
              <p class="text-gray-500 text-sm">
                ${Object.keys(variants).length} variants cached • Click outside or press ESC to close
              </p>
            </div>
          </div>
        </div>
      </div>
    `;
    
    // Add ESC key handler
    this.escHandler = (e) => {
      if (e.key === 'Escape') {
        this.closeVariantOverlay();
      }
    };
    document.addEventListener('keydown', this.escHandler);
  }
  
  createVariantOverlay() {
    this.variantOverlay = document.createElement('div');
    this.variantOverlay.classList.add('hidden');
    document.body.appendChild(this.variantOverlay);
  }
  
  closeVariantOverlay() {
    if (this.variantOverlay) {
      this.variantOverlay.classList.add('hidden');
    }
    if (this.escHandler) {
      document.removeEventListener('keydown', this.escHandler);
      this.escHandler = null;
    }
  }
  
  stopPropagation(event) {
    event.stopPropagation();
  }
  
  async initializePhotoMetadata() {
    console.log('Initializing photo metadata...');
    
    if (this.hasCurrentPhotoTarget) {
      this.currentPhotoTarget.textContent = 'Loading photo metadata...';
    }
    
    try {
      // Open IndexedDB
      const dbName = 'ShockCollarGallery';
      console.log('Opening IndexedDB...');
      
      // Add timeout to prevent hanging (allow extra time for SW upgrades)
      const dbOpenTimeout = setTimeout(() => {
        console.error('IndexedDB open timeout after 15 seconds');
        if (this.hasCurrentPhotoTarget) {
          this.currentPhotoTarget.innerHTML = `<span class=\"text-red-400\">Database timeout — please refresh the page. If it persists, close other tabs using this site.</span>`;
        }
      }, 15000);
      
      const db = await new Promise((resolve, reject) => {
        const request = indexedDB.open(dbName, 3); // Align with SW DB schema; metadata store keyPath 'id'
        
        request.onsuccess = (event) => {
          clearTimeout(dbOpenTimeout);
          console.log('IndexedDB opened successfully');
          resolve(event.target.result);
        };
        
        request.onerror = (event) => {
          clearTimeout(dbOpenTimeout);
          console.error('Failed to open IndexedDB:', request.error);
          reject(request.error || new Error('Failed to open database'));
        };
        
        request.onblocked = () => {
          clearTimeout(dbOpenTimeout);
          console.error('IndexedDB blocked - close other tabs');
          reject(new Error('Database blocked - please close other tabs and refresh'));
        };
        
        request.onupgradeneeded = (event) => {
          console.log('Upgrading IndexedDB schema from version', event.oldVersion, 'to', event.newVersion);
          const db = event.target.result;
          
          // Create images store if it doesn't exist
          if (!db.objectStoreNames.contains('images')) {
            console.log('Creating images store');
            db.createObjectStore('images', { keyPath: 'url' });
          }
          
          // Create metadata store for photo info
          if (!db.objectStoreNames.contains('metadata')) {
            console.log('Creating metadata store');
            const metadataStore = db.createObjectStore('metadata', { keyPath: 'id' });
            metadataStore.createIndex('created_at', 'created_at', { unique: false });
          }
          
          // Create settings store for metadata version tracking
          if (!db.objectStoreNames.contains('settings')) {
            console.log('Creating settings store');
            db.createObjectStore('settings', { keyPath: 'key' });
          }
        };
      });
      
      // Check if we have fresh metadata
      const settingsTx = db.transaction(['settings'], 'readonly');
      const settingsStore = settingsTx.objectStore('settings');
      const metadataVersion = await new Promise((resolve) => {
        const request = settingsStore.get('metadata_version');
        request.onsuccess = () => resolve(request.result);
        request.onerror = () => resolve(null);
      });
      
      const oneHourAgo = Date.now() - (60 * 60 * 1000);
      const needsFetch = !metadataVersion || metadataVersion.timestamp < oneHourAgo;
      
      if (needsFetch) {
        console.log('Fetching fresh photo metadata from server...');
        
        // Fetch all metadata in ONE request (respect ?limit param in URL)
        const currentParams = new URLSearchParams(window.location.search);
        const metaUrl = new URL('/preloader/all_photo_metadata', window.location.origin);
        const limitParam = currentParams.get('limit');
        if (limitParam) metaUrl.searchParams.set('limit', limitParam);
        const response = await fetch(metaUrl.toString());
        if (!response.ok) {
          throw new Error(`Failed to fetch metadata: HTTP ${response.status}`);
        }
        
        const data = await response.json();
        console.log(`Received metadata for ${data.photos.length} photos`);
        
        // Store all metadata in IndexedDB
        const tx = db.transaction(['metadata', 'settings'], 'readwrite');
        const metadataStore = tx.objectStore('metadata');
        const settingsStore = tx.objectStore('settings');
        
        // Clear old metadata
        await new Promise((resolve) => {
          const clearRequest = metadataStore.clear();
          clearRequest.onsuccess = () => resolve();
          clearRequest.onerror = () => resolve();
        });
        
        // Store each photo's metadata
        for (const photo of data.photos) {
          metadataStore.put(photo);
        }
        
        // Update version timestamp
        settingsStore.put({
          key: 'metadata_version',
          timestamp: Date.now(),
          generated_at: data.generated_at,
          count: data.total_count
        });
        
        // Wait for transaction to complete
        await new Promise((resolve, reject) => {
          tx.oncomplete = () => {
            console.log('Metadata stored in IndexedDB');
            resolve();
          };
          tx.onerror = () => reject(tx.error);
        });
        
        // Use the fetched data directly
        this.photoMetadata = data.photos;
      } else {
        console.log('Using cached metadata from IndexedDB');
        
        // Load metadata from IndexedDB
        const metadataTx = db.transaction(['metadata'], 'readonly');
        const metadataStore = metadataTx.objectStore('metadata');
        
        let cached = await new Promise((resolve) => {
          const request = metadataStore.getAll();
          request.onsuccess = () => resolve(request.result);
          request.onerror = () => resolve([]);
        });
        
        // Respect current ?limit parameter even when using cached metadata
        const currentParams = new URLSearchParams(window.location.search);
        const limitParam = currentParams.get('limit');
        if (limitParam && limitParam.toLowerCase() !== 'all') {
          const n = parseInt(limitParam, 10);
          if (!Number.isNaN(n) && n > 0) {
            cached = cached.slice(0, n);
          }
        }
        
        this.photoMetadata = cached;
        console.log(`Loaded ${this.photoMetadata.length} photos from cache`);
      }
      
      // Now detect cached photos using the metadata
      await this.detectCachedPhotosOptimized(db);
      
      db.close();
      
    } catch (error) {
      console.error('Error initializing metadata:', error);
      if (this.hasCurrentPhotoTarget) {
        this.currentPhotoTarget.innerHTML = `<span class="text-red-400">Error loading metadata: ${error.message}</span>`;
      }
    }
  }
  
  async detectCachedPhotosOptimized(db) {
    console.log('Detecting cached photos using local metadata...');
    
    if (this.hasCurrentPhotoTarget) {
      this.currentPhotoTarget.textContent = 'Detecting already-cached photos and variants...';
    }
    
    // Get all cached image URLs from IndexedDB (filter to image content types)
    const imagesTx = db.transaction(['images'], 'readonly');
    const imagesStore = imagesTx.objectStore('images');
    const getAllRequest = imagesStore.getAll();
    let cachedUrls = new Set();
    await new Promise((resolve) => {
      getAllRequest.onsuccess = () => {
        cachedUrls = this.buildCachedUrlSetFromRecords(getAllRequest.result || []);
        resolve();
      };
      getAllRequest.onerror = () => resolve();
    });

    // Also include Cache API entries (opaque responses end up here)
    try {
      const cacheNames = await caches.keys();
      for (const name of cacheNames) {
        if (!name.startsWith('shock-collar-cache-')) continue;
        const cache = await caches.open(name);
        const requests = await cache.keys();
        for (const req of requests) {
          const keyUrl = req.url;
          if (!this.shouldTreatAsImageCache(keyUrl)) continue;
          try {
            cachedUrls.add(this.toAbsolute(keyUrl));
            cachedUrls.add(this.toRelative(keyUrl));
          } catch (_) {
            cachedUrls.add(keyUrl);
          }
        }
      }
    } catch (e) {
      console.warn('Cache API not accessible for detection:', e);
    }
    
    console.log(`Found ${cachedUrls.size} cached images in storage`);
    
    // Now check each photo's variants using LOCAL metadata (no HTTP requests!)
    let photosWithCache = 0;
    let totalCachedVariants = 0;
    
    for (const photo of this.photoMetadata) {
      let cachedVariantCount = 0;
      let hasTinyThumb = false;
      let tinyThumbUrl = null;
      
      // Check each variant URL against cached URLs
      for (const [variantType, url] of Object.entries(photo.variants)) {
        const absUrl = this.toAbsolute(url);
        const relUrl = this.toRelative(url);
        if (cachedUrls.has(url) || cachedUrls.has(absUrl) || cachedUrls.has(relUrl)) {
          cachedVariantCount++;
          totalCachedVariants++;
          
          if (variantType === 'tiny_square_thumb') {
            hasTinyThumb = true;
            tinyThumbUrl = url;
          }
        }
      }
      
      // If this photo has cached variants, show it
      if (cachedVariantCount > 0) {
        photosWithCache++;
        
        // Add to grid if not already there
        if (!this.photoElements.has(photo.id)) {
          this.addPhotoPlaceholder(photo);
        }
        
        // Update the photo card
        const element = this.photoElements.get(photo.id);
        if (element) {
          // Show tiny thumb if cached
          if (hasTinyThumb && tinyThumbUrl) {
            const thumbDiv = element.querySelector('.photo-thumb');
            if (thumbDiv) {
              thumbDiv.style.backgroundImage = `url(${tinyThumbUrl})`;
              thumbDiv.style.backgroundSize = 'cover';
              thumbDiv.style.backgroundPosition = 'center';
              thumbDiv.classList.remove('bg-gray-700', 'animate-pulse');
            }
          }
          
          // Update variant dots
          for (const [variantType, url] of Object.entries(photo.variants)) {
            if (cachedUrls.has(url)) {
              const dot = element.querySelector(`.variant-dot[data-variant="${variantType}"]`);
              if (dot) {
                dot.classList.remove('bg-gray-600');
                dot.classList.add('bg-green-500', 'loaded');
              }
            }
          }
          
          // Update progress ring
          const totalVariants = Object.keys(photo.variants).length;
          const progress = (cachedVariantCount / totalVariants) * 100;
          
          const progressCircle = element.querySelector('.progress-circle');
          const progressText = element.querySelector('.progress-ring span');
          
          if (progressCircle) {
            const offset = 88 - (88 * progress / 100);
            progressCircle.style.strokeDashoffset = offset;
            
            if (progress === 100) {
              progressCircle.style.stroke = 'rgba(34,197,94,1)';
              element.classList.add('loaded');
            } else if (progress > 0) {
              progressCircle.style.stroke = 'rgba(251,191,36,1)';
            }
          }
          
          if (progressText) {
            if (progress === 100) {
              progressText.innerHTML = '✓';
            } else {
              progressText.textContent = `${Math.round(progress)}%`;
            }
          }
        }
      }
    }
    
    // Update overall progress
    this.loadedVariants = totalCachedVariants;
    this.updateOverallProgress();
    
    // Final status
    if (this.hasCurrentPhotoTarget) {
      if (photosWithCache > 0) {
        this.currentPhotoTarget.innerHTML = `
          <span class="text-green-400">
            Found ${photosWithCache} photos with ${totalCachedVariants} cached variants
          </span>
        `;
      } else {
        this.currentPhotoTarget.textContent = 'No cached photos found. Ready to start caching!';
      }
    }
    
    console.log(`Detection complete: ${photosWithCache} photos with ${totalCachedVariants} cached variants (INSTANT!)`);
  }
  
  async detectCachedPhotos() {
    console.log('Detecting already-cached photos and variants...');
    
    // Update status
    if (this.hasCurrentPhotoTarget) {
      this.currentPhotoTarget.textContent = 'Detecting already-cached photos and variants...';
    }
    
    // Open IndexedDB
    const dbName = 'ShockCollarGallery';
    const db = await new Promise((resolve, reject) => {
      const request = indexedDB.open(dbName); // use current version
      request.onsuccess = () => resolve(request.result);
      request.onerror = () => reject(request.error);
      request.onupgradeneeded = (event) => {
        const db = event.target.result;
        if (!db.objectStoreNames.contains('images')) {
          db.createObjectStore('images', { keyPath: 'url' });
        }
      };
    });
    
    // Get all cached URLs from IndexedDB
    let cachedUrls = new Set();
    const transaction = db.transaction(['images'], 'readonly');
    const store = transaction.objectStore('images');
    const getAllRequest = store.getAll();
    await new Promise((resolve) => {
      getAllRequest.onsuccess = () => {
        cachedUrls = this.buildCachedUrlSetFromRecords(getAllRequest.result || []);
        resolve();
      };
      getAllRequest.onerror = () => resolve();
    });

    // Also include Cache API entries
    try {
      const cacheNames = await caches.keys();
      for (const name of cacheNames) {
        if (!name.startsWith('shock-collar-cache-')) continue;
        const cache = await caches.open(name);
        const requests = await cache.keys();
        for (const req of requests) {
          const keyUrl = req.url;
          if (!this.shouldTreatAsImageCache(keyUrl)) continue;
          try {
            cachedUrls.add(this.toAbsolute(keyUrl));
            cachedUrls.add(this.toRelative(keyUrl));
          } catch (_) {
            cachedUrls.add(keyUrl);
          }
        }
      }
    } catch (e) {
      console.warn('Cache API not accessible for detection:', e);
    }
    
    console.log(`Found ${cachedUrls.size} cached images in storage`);
    
    // Early exit if no cached images
    if (cachedUrls.size === 0) {
      if (this.hasCurrentPhotoTarget) {
        this.currentPhotoTarget.textContent = 'No cached photos found. Ready to start caching!';
      }
      db.close();
      return;
    }
    
    // Check each photo to see what variants are cached
    let photosWithCache = 0;
    let totalCachedVariants = 0;
    const batchSize = 100; // Even larger batches since we're parallel
    
    console.log(`Starting to scan ${this.photosValue.length} photos in batches of ${batchSize}`);
    
    try {
      for (let i = 0; i < this.photosValue.length; i += batchSize) {
        const batch = this.photosValue.slice(i, Math.min(i + batchSize, this.photosValue.length));
        const photoIds = batch.map(p => p.id);
        
        console.log(`Processing batch ${i}-${i + batch.length} with ${photoIds.length} photos`);
        
        // Fetch URLs for all variants of this batch IN PARALLEL
        const batchVariants = {};
        const variantPromises = this.variantOrder.map(async (variantType) => {
          try {
            const params = new URLSearchParams();
            photoIds.forEach(id => params.append('photo_ids[]', id));
            params.append('variant', variantType);
            
            const response = await fetch(`/preloader/variant_urls?${params}`);
            
            if (response.ok) {
              const urls = await response.json();
              return { variantType, urls };
            } else {
              console.error(`Failed to fetch ${variantType}: HTTP ${response.status}`);
              return null;
            }
          } catch (error) {
            console.error(`Error fetching ${variantType}:`, error);
            return null;
          }
        });
        
        // Wait for all variant fetches to complete in parallel
        const results = await Promise.all(variantPromises);
        
        console.log(`Got ${results.filter(r => r).length} variant results for batch`);
        
        // Organize the results
        results.forEach(result => {
          if (result) {
            for (const [photoId, url] of Object.entries(result.urls)) {
              if (!batchVariants[photoId]) batchVariants[photoId] = {};
              batchVariants[photoId][result.variantType] = url;
            }
          }
        });
        
        // Check which variants are cached and display photos with cached variants
        for (const photo of batch) {
          const variants = batchVariants[photo.id];
          if (!variants) continue;
          
          let cachedVariantCount = 0;
          let hasTinyThumb = false;
          let tinyThumbUrl = null;
          
          // Check each variant
          for (const [variantType, url] of Object.entries(variants)) {
            const absUrl = this.toAbsolute(url);
            const relUrl = this.toRelative(url);
            if (cachedUrls.has(url) || cachedUrls.has(absUrl) || cachedUrls.has(relUrl)) {
              cachedVariantCount++;
              totalCachedVariants++;
              
              if (variantType === 'tiny_square_thumb') {
                hasTinyThumb = true;
                tinyThumbUrl = url;
              }
            }
          }
          
          // If this photo has any cached variants, show it in the grid
          if (cachedVariantCount > 0) {
            photosWithCache++;
            
            // Add the photo to the grid if not already there
            if (!this.photoElements.has(photo.id)) {
              this.addPhotoPlaceholder(photo);
            }
            
            // Update the photo card with cached variant info
            const element = this.photoElements.get(photo.id);
            if (element) {
              // If we have the tiny thumb, show it
              if (hasTinyThumb && tinyThumbUrl) {
                const thumbDiv = element.querySelector('.photo-thumb');
                if (thumbDiv) {
                  thumbDiv.style.backgroundImage = `url(${tinyThumbUrl})`;
                  thumbDiv.style.backgroundSize = 'cover';
                  thumbDiv.style.backgroundPosition = 'center';
                  thumbDiv.classList.remove('bg-gray-700', 'animate-pulse');
                }
              }
              
              // Update variant dots to show what's cached
              for (const [variantType, url] of Object.entries(variants)) {
                if (cachedUrls.has(url)) {
                  const dot = element.querySelector(`.variant-dot[data-variant="${variantType}"]`);
                  if (dot) {
                    dot.classList.remove('bg-gray-600');
                    dot.classList.add('bg-green-500', 'loaded');
                  }
                }
              }
              
              // Update progress ring
              const totalVariants = Object.keys(variants).length;
              const progress = (cachedVariantCount / totalVariants) * 100;
              
              const progressCircle = element.querySelector('.progress-circle');
              const progressText = element.querySelector('.progress-ring span');
              
              if (progressCircle) {
                const offset = 88 - (88 * progress / 100);
                progressCircle.style.strokeDashoffset = offset;
                
                if (progress === 100) {
                  progressCircle.style.stroke = 'rgba(34,197,94,1)'; // green
                  element.classList.add('loaded');
                } else if (progress > 0) {
                  progressCircle.style.stroke = 'rgba(251,191,36,1)'; // amber
                }
              }
              
              if (progressText) {
                if (progress === 100) {
                  progressText.innerHTML = '✓';
                } else {
                  progressText.textContent = `${Math.round(progress)}%`;
                }
              }
            }
          }
        }
        
        // Update status as we go (moved inside the batch loop)
        if (this.hasCurrentPhotoTarget) {
          this.currentPhotoTarget.textContent = `Scanning cache: ${Math.min(i + batchSize, this.photosValue.length)} / ${this.photosValue.length} photos checked...`;
        }
      }
    } catch (error) {
      console.error('Error during cache detection:', error);
      if (this.hasCurrentPhotoTarget) {
        this.currentPhotoTarget.innerHTML = `<span class="text-red-400">Error detecting cached photos: ${error.message}</span>`;
      }
    } finally {
      db.close();
    }
    
    // Update the loaded variants count for accurate progress
    this.loadedVariants = totalCachedVariants;
    this.updateOverallProgress();
    
    // Final status
    if (this.hasCurrentPhotoTarget) {
      if (photosWithCache > 0) {
        this.currentPhotoTarget.innerHTML = `
          <span class="text-green-400">
            Found ${photosWithCache} photos with ${totalCachedVariants} cached variants
          </span>
        `;
      } else {
        this.currentPhotoTarget.textContent = 'No cached photos found. Ready to start caching!';
      }
    }
    
    console.log(`Detection complete: ${photosWithCache} photos with ${totalCachedVariants} cached variants`);
  }
}
