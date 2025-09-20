import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["image", "counter", "thumbnail", "heroInput", "heroButton", "heroPhotoId", "emailForm", "rejectInput", "rejectButton", "splitButton", "imageWrapper", "faceOverlay", "faceRectangleToggle", "downloadButton", "exifPanel", "exifContent", "mainContainer", "photoContainer"]
  static values = { total: Number, sessionId: String, showRejected: Boolean, initialIndex: Number, prevSession: String, nextSession: String }
  
  initialize() {
    this.loaderStates = new WeakMap()
  }

  connect() {
    // Check URL parameter for starting position
    const urlParams = new URLSearchParams(window.location.search)
    const startParam = urlParams.get('start')
    const imageParam = urlParams.get('image')

    if (startParam === 'last') {
      this.currentIndex = this.totalValue - 1
    } else if (imageParam) {
      // Parse image parameter (1-based index)
      const imageIndex = parseInt(imageParam) - 1
      if (imageIndex >= 0 && imageIndex < this.totalValue) {
        this.currentIndex = imageIndex
      } else {
        this.currentIndex = this.hasInitialIndexValue ? this.initialIndexValue : 0
      }
    } else {
      // Use the initial index (hero photo or first photo)
      this.currentIndex = this.hasInitialIndexValue ? this.initialIndexValue : 0
    }

    // Load face rectangle preference
    if (this.hasFaceRectangleToggleTarget) {
      const showRectangles = localStorage.getItem('showFaceRectangles') === 'true'
      this.faceRectangleToggleTarget.checked = showRectangles
    }

    // Initialize EXIF panel state from localStorage
    this.exifPanelOpen = localStorage.getItem('exifPanelOpen') === 'true'
    if (this.exifPanelOpen) {
      this.showExifPanel()
    }

    // Load EXIF field configuration
    this.loadExifConfiguration()

    this.setupImageLoading()
    this.updateDisplay()

    // Add keyboard navigation
    document.addEventListener("keydown", this.handleKeyPress.bind(this))

    // Preload session thumbnails in service worker cache
    this.preloadSessionThumbnails()
  }
  
  setupImageLoading() {
    this.imageTargets.forEach((container) => {
      const img = container.querySelector('img')
      if (img) {
        this.attachImageLoader(img, container)
      }
    })

    this.thumbnailTargets.forEach((thumb) => {
      const img = thumb.querySelector('img')
      if (img) {
        this.attachImageLoader(img, thumb)
      }
    })
  }
  
  disconnect() {
    document.removeEventListener("keydown", this.handleKeyPress.bind(this))
  }
  
  handleKeyPress(event) {
    switch(event.key) {
      case "ArrowLeft":
        this.previous()
        break
      case "ArrowRight":
        this.next()
        break
      case "ArrowDown":
        event.preventDefault()
        this.nextSession()
        break
      case "ArrowUp":
        event.preventDefault()
        window.location.href = "/"
        break
      case " ":
        event.preventDefault()
        this.heroButtonTarget.click()
        break
      case "x":
      case "X":
        event.preventDefault()
        this.toggleExifPanel()
        break
      case "Escape":
        window.location.href = "/"
        break
    }
  }
  
  next() {
    if (this.currentIndex < this.totalValue - 1) {
      this.currentIndex++
      this.updateDisplay()
    } else {
      // At last photo, navigate to next session
      this.nextSession()
    }
  }
  
  previous() {
    if (this.currentIndex > 0) {
      this.currentIndex--
      this.updateDisplay()
    } else {
      // At first photo, navigate to previous session
      this.previousSession()
    }
  }
  
  goToImage(event) {
    this.currentIndex = parseInt(event.currentTarget.dataset.index)
    this.updateDisplay()
  }
  
  previousSession() {
    if (this.prevSessionValue) {
      // Add parameter to start at last photo
      const url = new URL(this.prevSessionValue, window.location.origin)
      url.searchParams.set('start', 'last')
      if (this.showRejectedValue) {
        url.searchParams.set('show_rejected', 'true')
      }
      window.location.href = url.href
    }
  }
  
  nextSession() {
    if (this.nextSessionValue) {
      // Add parameter to start at first photo for continuous navigation
      const url = new URL(this.nextSessionValue, window.location.origin)
      url.searchParams.set('start', 'first')
      if (this.showRejectedValue) {
        url.searchParams.set('show_rejected', 'true')
      }
      window.location.href = url.href
    }
  }
  
  updateDisplay() {
    // Update URL with current image position
    this.updateURL()

    // Update page title with current photo position
    this.updatePageTitle()

    // Load image for current index if not already loaded
    this.loadImageForIndex(this.currentIndex)
    
    // Hide all images and apply rejected styling
    this.imageTargets.forEach((img, index) => {
      if (index === this.currentIndex) {
        img.classList.remove("hidden")
        
        // Apply rejected styling to main image if needed
        const isRejected = this.thumbnailTargets[index]?.dataset.rejected === 'true'
        if (isRejected && this.showRejectedValue) {
          img.classList.add("rejected-photo")
        } else {
          img.classList.remove("rejected-photo")
        }
      } else {
        img.classList.add("hidden")
        img.classList.remove("rejected-photo")
      }
    })
    
    // Update counter
    this.counterTarget.textContent = `${this.currentIndex + 1} / ${this.totalValue}`
    
    // Update hero input with current photo ID
    const currentImage = this.imageTargets[this.currentIndex]
    let currentPhotoId = null
    
    if (currentImage && this.hasHeroInputTarget) {
      const photoId = currentImage.querySelector("img").dataset.photoId
      if (photoId) {
        this.heroInputTarget.value = photoId
        currentPhotoId = photoId
      }
    }
    
    // Get hero photo ID
    const heroPhotoId = this.hasHeroPhotoIdTarget ? this.heroPhotoIdTarget.value : null
    
    // Update thumbnails and hero button
    this.thumbnailTargets.forEach((thumb, index) => {
      const thumbPhotoId = thumb.dataset.photoId
      const isHero = thumbPhotoId === heroPhotoId
      const isCurrent = index === this.currentIndex
      const isRejected = thumb.dataset.rejected === 'true'
      
      // Reset all border classes and rejected styling
      thumb.classList.remove("border-gray-600", "border-yellow-500", "border-red-500", "border-4", "rejected-thumbnail")
      
      // Apply rejected styling first if needed
      if (isRejected && this.showRejectedValue) {
        thumb.classList.add("rejected-thumbnail")
      }
      
      // Apply appropriate border styling (priority: hero > current > default/rejected)
      if (isHero) {
        thumb.classList.add("border-yellow-500", "border-4")
      } else if (isCurrent) {
        thumb.classList.add("border-red-500")
      } else if (isRejected && this.showRejectedValue) {
        // rejected-thumbnail class already handles border, but ensure it's red
        thumb.classList.add("border-red-500")
      } else {
        thumb.classList.add("border-gray-600")
      }
    })
    
    // Update hero button text and styling
    if (this.hasHeroButtonTarget) {
      const isCurrentHero = currentPhotoId === heroPhotoId
      const button = this.heroButtonTarget

      if (isCurrentHero) {
        button.value = button.dataset.heroText || "★ Selected as Hero"
        button.classList.add("bg-red-600", "text-white")
        button.classList.remove("bg-gray-700/70", "text-gray-300", "hover:bg-gray-600/70")
      } else {
        button.value = button.dataset.selectText || "☆ Select as Hero"
        button.classList.add("bg-gray-700/70", "text-gray-300")
        button.classList.remove("bg-red-600", "text-white")
      }
    }
    
    // Update reject input with current photo ID
    if (currentImage && this.hasRejectInputTarget) {
      const photoId = currentImage.querySelector("img").dataset.photoId
      if (photoId) {
        this.rejectInputTarget.value = photoId
      }
    }
    
    // Update reject button text and styling based on photo rejected state
    if (this.hasRejectButtonTarget) {
      const currentThumbnail = this.thumbnailTargets[this.currentIndex]
      const isCurrentRejected = currentThumbnail && currentThumbnail.dataset.rejected === 'true'
      const button = this.rejectButtonTarget
      
      if (isCurrentRejected) {
        button.value = button.dataset.rejectedText || "✅ Rejected"
        button.classList.add("bg-red-600", "text-white")
        button.classList.remove("bg-gray-600/90", "text-white")
      } else {
        button.value = button.dataset.rejectText || "🗑️ Reject"
        button.classList.add("bg-gray-600/90", "text-white")
        button.classList.remove("bg-red-600", "text-white")
      }
    }
    
    // Update split button state - disable for first photo
    if (this.hasSplitButtonTarget) {
      if (this.currentIndex === 0) {
        this.splitButtonTarget.disabled = true
        this.splitButtonTarget.title = "Cannot split at the first photo"
      } else {
        this.splitButtonTarget.disabled = false
        this.splitButtonTarget.title = `Split session at photo ${this.currentIndex + 1}`
      }
    }
    
    // Scroll thumbnail into view
    const activeThumbnail = this.thumbnailTargets[this.currentIndex]
    if (activeThumbnail) {
      activeThumbnail.scrollIntoView({ behavior: "smooth", inline: "center", block: "nearest" })
    }
    
    // Update face rectangles for current image
    this.updateFaceRectangles()

    // Update EXIF data if panel is open
    if (this.exifPanelOpen && this.hasExifContentTarget) {
      this.loadExifData()
    }
  }
  
  toggleFaceRectangles(event) {
    const showRectangles = event.target.checked
    localStorage.setItem('showFaceRectangles', showRectangles)
    this.updateFaceRectangles()
  }
  
  updateFaceRectangles() {
    const showRectangles = this.hasFaceRectangleToggleTarget ? 
                          this.faceRectangleToggleTarget.checked : 
                          localStorage.getItem('showFaceRectangles') === 'true'
    
    const currentImage = this.imageTargets[this.currentIndex]
    if (!currentImage) return
    
    const faceDataStr = currentImage.dataset.faceData
    const overlay = this.faceOverlayTargets[this.currentIndex]
    
    if (!overlay) return
    
    // Clear existing rectangles
    overlay.innerHTML = ''
    
    if (!showRectangles || !faceDataStr) {
      overlay.classList.add('hidden')
      return
    }
    
    try {
      const faceData = JSON.parse(faceDataStr)
      if (!faceData.faces || faceData.faces.length === 0) {
        overlay.classList.add('hidden')
        return
      }
      
      overlay.classList.remove('hidden')
      
      // Get the img element to calculate scaling
      const img = currentImage.querySelector('img')
      if (!img || !img.complete) {
        overlay.classList.add('hidden')
        return
      }
      
      // Wait for next frame to ensure layout is complete
      requestAnimationFrame(() => {
        const containerRect = overlay.getBoundingClientRect()
        const imgRect = img.getBoundingClientRect()
        
        // Calculate the actual displayed image dimensions within the container
        // img uses object-contain so we need to find the actual image boundaries
        const imgNaturalRatio = img.naturalWidth / img.naturalHeight
        const containerRatio = containerRect.width / containerRect.height
        
        let displayedWidth, displayedHeight, offsetX = 0, offsetY = 0
        
        if (imgNaturalRatio > containerRatio) {
          // Image is wider - constrained by container width
          displayedWidth = containerRect.width
          displayedHeight = containerRect.width / imgNaturalRatio
          offsetY = (containerRect.height - displayedHeight) / 2
        } else {
          // Image is taller - constrained by container height  
          displayedHeight = containerRect.height
          displayedWidth = containerRect.height * imgNaturalRatio
          offsetX = (containerRect.width - displayedWidth) / 2
        }
        
        // Draw rectangles for each face
        faceData.faces.forEach(face => {
          const rect = document.createElement('div')
          rect.style.position = 'absolute'
          
          // Convert face coordinates to displayed image coordinates
          let faceX, faceY, faceWidth, faceHeight
          
          if (faceData.image_width && faceData.image_height) {
            // Convert pixel coordinates to normalized coordinates first
            faceX = face.x / faceData.image_width
            faceY = face.y / faceData.image_height
            faceWidth = face.width / faceData.image_width
            faceHeight = face.height / faceData.image_height
          } else {
            // Already normalized coordinates
            faceX = face.x
            faceY = face.y
            faceWidth = face.width
            faceHeight = face.height
          }
          
          // Convert to pixel positions within the displayed image
          const rectLeft = offsetX + (faceX * displayedWidth)
          const rectTop = offsetY + (faceY * displayedHeight)
          const rectWidth = faceWidth * displayedWidth
          const rectHeight = faceHeight * displayedHeight
          
          // Convert to percentages of the container
          rect.style.left = `${(rectLeft / containerRect.width) * 100}%`
          rect.style.top = `${(rectTop / containerRect.height) * 100}%`
          rect.style.width = `${(rectWidth / containerRect.width) * 100}%`
          rect.style.height = `${(rectHeight / containerRect.height) * 100}%`
          
          rect.style.border = '3px solid #fbbf24' // Yellow border
          rect.style.borderRadius = '4px'
          rect.style.pointerEvents = 'none'
          
          // Add confidence label if available
          if (face.confidence) {
            const label = document.createElement('div')
            label.style.position = 'absolute'
            label.style.bottom = '-20px'
            label.style.left = '0'
            label.style.fontSize = '12px'
            label.style.color = '#fbbf24'
            label.style.backgroundColor = 'rgba(0,0,0,0.7)'
            label.style.padding = '2px 4px'
            label.style.borderRadius = '2px'
            label.textContent = `${Math.round(face.confidence * 100)}%`
            rect.appendChild(label)
          }
          
          overlay.appendChild(rect)
        })
      })
    } catch (e) {
      console.error('Error parsing face data:', e)
      overlay.classList.add('hidden')
    }
  }
  
  showEmailForm() {
    if (this.hasEmailFormTarget) {
      this.emailFormTarget.classList.remove("hidden")
    }
  }
  
  hideEmailForm() {
    if (this.hasEmailFormTarget) {
      this.emailFormTarget.classList.add("hidden")
    }
  }
  
  // Method to handle hero selection
  heroSelected() {
    // Update the hero photo ID to current photo
    const currentImage = this.imageTargets[this.currentIndex]
    if (currentImage && this.hasHeroPhotoIdTarget) {
      const photoId = currentImage.querySelector("img").dataset.photoId
      if (photoId) {
        this.heroPhotoIdTarget.value = photoId
        // Refresh display to show new hero state
        this.updateDisplay()
      }
    }
  }
  
  // Method to handle photo rejection
  photoRejected() {
    // Toggle rejected state on current thumbnail
    const currentThumbnail = this.thumbnailTargets[this.currentIndex]
    if (currentThumbnail) {
      const isCurrentlyRejected = currentThumbnail.dataset.rejected === 'true'
      currentThumbnail.dataset.rejected = isCurrentlyRejected ? 'false' : 'true'
      
      // Refresh display to show new reject state
      this.updateDisplay()
    }
  }
  
  // Method to handle session split
  confirmSplit() {
    // Don't allow splitting at the first photo
    if (this.currentIndex === 0) {
      alert("Cannot split at the first photo of a session")
      return
    }
    
    // Get current photo info
    const currentImage = this.imageTargets[this.currentIndex]
    if (!currentImage) return
    
    const photoId = currentImage.querySelector("img").dataset.photoId
    if (!photoId) return
    
    // Confirmation dialog with details
    const photoNumber = this.currentIndex + 1
    const remainingPhotos = this.totalValue - this.currentIndex
    const message = `Split this session at photo ${photoNumber}?\n\n` +
                   `This will create a new session with ${remainingPhotos} photos ` +
                   `(photos ${photoNumber}-${this.totalValue}).\n\n` +
                   `The current session will keep the first ${this.currentIndex} photos.`
    
    if (!confirm(message)) {
      return
    }
    
    // Disable button and show loading state
    if (this.hasSplitButtonTarget) {
      this.splitButtonTarget.disabled = true
      this.splitButtonTarget.innerHTML = '⏳ Splitting...'
    }
    
    // Prepare CSRF token for Rails
    const token = document.querySelector('meta[name="csrf-token"]').content
    
    // Make AJAX request to split the session
    fetch(`/gallery/${this.sessionIdValue}/split_session`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': token,
        'Accept': 'application/json'
      },
      body: JSON.stringify({ photo_id: photoId })
    })
    .then(response => {
      if (!response.ok) {
        return response.json().then(data => {
          throw new Error(data.error || 'Failed to split session')
        })
      }
      return response.json()
    })
    .then(data => {
      // Redirect to the new session
      if (data.redirect_url) {
        window.location.href = data.redirect_url
      } else if (data.new_session_id) {
        window.location.href = `/gallery/${data.new_session_id}`
      } else {
        // Fallback: reload current page
        window.location.reload()
      }
    })
    .catch(error => {
      console.error('Split error:', error)
      alert(`Failed to split session: ${error.message}`)
      
      // Re-enable button on error
      if (this.hasSplitButtonTarget) {
        this.splitButtonTarget.disabled = false
        this.splitButtonTarget.innerHTML = '✂️ Split Session Here'
      }
    })
  }
  
  // Update page title with current photo information
  updatePageTitle() {
    // Get session info from data attributes or page
    const sessionId = this.sessionIdValue
    const photoPosition = this.currentIndex + 1
    const totalPhotos = this.totalValue

    // Extract session number from burst_id if available
    const burstIdElement = document.querySelector('[data-image-viewer-burst-id-value]')
    const burstId = burstIdElement?.getAttribute('data-image-viewer-burst-id-value') || ''
    const sessionMatch = burstId.match(/burst_(\d+)/)
    const sessionNumber = sessionMatch ? sessionMatch[1] : sessionId

    // Try to get day name from the page
    const dayNameElement = document.querySelector('h2')
    const dayMatch = dayNameElement?.textContent.match(/^(\w+),/)
    const dayName = dayMatch ? dayMatch[1] : null

    // Build title parts
    const titleParts = []
    if (dayName) titleParts.push(dayName)
    titleParts.push(`Session ${sessionNumber}`)
    titleParts.push(`Photo ${photoPosition}/${totalPhotos}`)

    // Update page title
    document.title = titleParts.join(' - ')
  }

  // Update URL with current image position
  updateURL() {
    const currentPath = window.location.pathname
    const sessionId = this.sessionIdValue
    const photoPosition = this.currentIndex + 1 // Use 1-based index for user-friendly URLs

    let newPath
    // Check if we're already on the new URL format
    if (currentPath.includes('/session/')) {
      // Update existing session URL
      newPath = `/session/${sessionId}/photo/${photoPosition}`
    } else {
      // Keep old format for backward compatibility
      const url = new URL(window.location)
      url.searchParams.set('image', photoPosition)

      // Preserve existing parameters like show_rejected
      if (this.showRejectedValue) {
        url.searchParams.set('show_rejected', 'true')
      }

      // Update URL without causing page reload
      window.history.replaceState({}, '', url)
      return
    }

    // Build URL with query params if needed
    const url = new URL(newPath, window.location.origin)
    if (this.showRejectedValue) {
      url.searchParams.set('show_rejected', 'true')
    }

    // Update URL without causing page reload
    window.history.replaceState({}, '', url)
  }

  // Download current photo
  downloadCurrentPhoto(event) {
    event.preventDefault()
    
    // Get the current photo ID
    const currentImage = this.imageTargets[this.currentIndex]
    if (!currentImage) return
    
    const img = currentImage.querySelector('img')
    if (!img) return
    
    const photoId = img.dataset.photoId
    if (!photoId) return
    
    // Create download URL
    const downloadUrl = `/gallery/${this.sessionIdValue}/download_photo?photo_id=${photoId}`
    
    // Trigger download
    window.location.href = downloadUrl
  }

  // Confirm hide session with detailed dialog
  confirmHideSession(event) {
    event.preventDefault()
    
    const sessionNumber = event.currentTarget.dataset.sessionNumber
    const photoCount = event.currentTarget.dataset.photoCount
    
    const message = `Hide Session ${sessionNumber}?\n\n` +
                   `This session contains ${photoCount} photos and will be removed from the gallery.\n\n` +
                   `This action cannot be easily undone. Continue?`
    
    if (confirm(message)) {
      // Submit the form
      event.currentTarget.closest('form').submit()
    }
  }

  // Preload session thumbnails for caching
  preloadSessionThumbnails() {
    if (!navigator.serviceWorker || !navigator.serviceWorker.controller) {
      return
    }

    // Get all thumbnail URLs from current session
    const thumbnailUrls = []
    
    // Get main image URLs (medium size)
    this.imageTargets.forEach((container) => {
      const img = container.querySelector('img')
      if (img && img.src) {
        thumbnailUrls.push(img.src)
      }
    })
    
    // Get thumbnail strip URLs
    this.thumbnailTargets.forEach((thumb) => {
      const img = thumb.querySelector('img')
      if (img && img.src) {
        thumbnailUrls.push(img.src)
      }
    })
    
    if (thumbnailUrls.length > 0) {
      console.log(`Requesting cache for ${thumbnailUrls.length} session images`)
      navigator.serviceWorker.controller.postMessage({
        type: 'CACHE_THUMBNAILS',
        data: { urls: [...new Set(thumbnailUrls)] } // Remove duplicates
      })
    }
  }

  // Get cache status (for debugging)
  getCacheStatus() {
    if (!navigator.serviceWorker || !navigator.serviceWorker.controller) {
      console.log('Service Worker not available')
      return
    }

    navigator.serviceWorker.controller.postMessage({
      type: 'GET_CACHE_STATUS'
    })
  }

  // Clear thumbnail cache (for debugging)
  clearThumbnailCache() {
    if (!navigator.serviceWorker || !navigator.serviceWorker.controller) {
      console.log('Service Worker not available')
      return
    }

    navigator.serviceWorker.controller.postMessage({
      type: 'CLEAR_CACHE'
    })
    
    console.log('Thumbnail cache clear requested')
  }
  
  // Load image for a specific index
  loadImageForIndex(index) {
    const container = this.imageTargets[index]
    if (!container) return
    
    // Check if image is already loaded
    const existingImg = container.querySelector('img')
    if (existingImg && existingImg.src && !existingImg.src.includes('data:')) {
      return // Image already loaded
    }
    
    // Get image URL from data attributes
    const largeUrl = container.dataset.largeUrl
    const fallbackUrl = container.dataset.fallbackUrl
    const photoId = container.dataset.photoId
    
    if (!largeUrl && !fallbackUrl) return
    
    // Create wrapper if it doesn't exist
    let wrapper = container.querySelector('[data-image-viewer-target="imageWrapper"]')
    if (!wrapper) {
      wrapper = container.querySelector('.relative')
    }
    
    if (!wrapper) return
    
    // Clear existing content
    const placeholder = wrapper.querySelector('[data-image-viewer-placeholder]')
    if (placeholder) {
      placeholder.remove()
    }

    const currentImg = wrapper.querySelector('img')
    if (currentImg) {
      currentImg.remove()
    }

    // Create and insert the image
    const img = document.createElement('img')
    img.alt = `Photo ${index + 1}`
    img.className = 'w-full h-full object-contain cursor-pointer'
    img.dataset.action = 'click->image-viewer#next'
    img.dataset.photoId = photoId

    this.attachImageLoader(img, container)

    img.src = largeUrl || fallbackUrl

    wrapper.appendChild(img)
    
    // Preload adjacent images for smoother navigation
    this.preloadAdjacentImages(index)
  }
  
  // Preload images before and after current index
  preloadAdjacentImages(index) {
    // Preload next image
    if (index < this.totalValue - 1) {
      this.preloadImage(index + 1)
    }
    
    // Preload previous image
    if (index > 0) {
      this.preloadImage(index - 1)
    }
  }
  
  // Preload a single image without displaying it
  preloadImage(index) {
    const container = this.imageTargets[index]
    if (!container) return

    // Check if already loaded
    const existingImg = container.querySelector('img')
    if (existingImg && existingImg.src && !existingImg.src.includes('data:')) {
      return
    }

    const largeUrl = container.dataset.largeUrl
    const fallbackUrl = container.dataset.fallbackUrl

    if (!largeUrl && !fallbackUrl) return

    // Create a hidden image to trigger download
    const preloadImg = new Image()
    preloadImg.src = largeUrl || fallbackUrl
  }

  attachImageLoader(img, container) {
    if (!img || !container) return

    const loader = this.findLoader(container)
    if (!loader) return

    if (img.dataset.loaderBound === 'true') {
      if (!(img.complete && img.naturalWidth > 0)) {
        this.queueLoader(container)
      } else {
        this.resetLoader(container)
      }
      return
    }

    const handleLoad = () => {
      this.completeLoader(container)
      if (container.dataset.imageViewerTarget === 'image') {
        this.updateFaceRectangles()
      }
      img.removeEventListener('load', handleLoad)
      img.removeEventListener('error', handleError)
      delete img.dataset.loaderBound
    }

    const handleError = () => {
      this.resetLoader(container)
      img.removeEventListener('load', handleLoad)
      img.removeEventListener('error', handleError)
      delete img.dataset.loaderBound
    }

    img.addEventListener('load', handleLoad)
    img.addEventListener('error', handleError)
    img.dataset.loaderBound = 'true'

    if (!(img.complete && img.naturalWidth > 0)) {
      this.queueLoader(container)
    } else {
      this.resetLoader(container)
    }
  }

  findLoader(container) {
    return container.querySelector('.thumbnail-loader')
  }

  loaderState(container) {
    if (!this.loaderStates) {
      this.loaderStates = new WeakMap()
    }

    let state = this.loaderStates.get(container)
    if (!state) {
      state = { shown: false, delayTimeout: null, completeTimeout: null }
      this.loaderStates.set(container, state)
    }

    return state
  }

  queueLoader(container) {
    const loader = this.findLoader(container)
    if (!loader) return

    const state = this.loaderState(container)

    if (state.completeTimeout) {
      clearTimeout(state.completeTimeout)
      state.completeTimeout = null
    }

    if (state.shown) {
      loader.classList.remove('thumbnail-loader--complete', 'thumbnail-loader--fading')
      loader.classList.add('thumbnail-loader--active')
      return
    }

    if (state.delayTimeout) {
      clearTimeout(state.delayTimeout)
    }

    state.delayTimeout = setTimeout(() => {
      loader.classList.remove('thumbnail-loader--complete', 'thumbnail-loader--fading')
      loader.classList.add('thumbnail-loader--active')
      state.shown = true
    }, 1000)
  }

  completeLoader(container) {
    const loader = this.findLoader(container)
    if (!loader) return

    const state = this.loaderState(container)

    if (state.delayTimeout) {
      clearTimeout(state.delayTimeout)
      state.delayTimeout = null
    }

    if (!state.shown) {
      this.startFadeOut(container, loader, state)
      return
    }

    loader.classList.add('thumbnail-loader--complete')
    this.startFadeOut(container, loader, state)
  }

  resetLoader(container) {
    const loader = this.findLoader(container)
    if (!loader) return

    const state = this.loaderState(container)

    if (state.delayTimeout) {
      clearTimeout(state.delayTimeout)
      state.delayTimeout = null
    }

    if (state.completeTimeout) {
      clearTimeout(state.completeTimeout)
      state.completeTimeout = null
    }

    loader.classList.remove('thumbnail-loader--active', 'thumbnail-loader--complete', 'thumbnail-loader--fading')
    state.shown = false
  }

  startFadeOut(container, loader, state) {
    loader.classList.remove('thumbnail-loader--active')
    loader.classList.add('thumbnail-loader--fading')
    state.shown = false

    if (state.completeTimeout) {
      clearTimeout(state.completeTimeout)
    }

    state.completeTimeout = setTimeout(() => {
      this.resetLoader(container)
    }, 900)
  }

  // Toggle EXIF panel visibility
  toggleExifPanel() {
    if (this.exifPanelOpen) {
      this.hideExifPanel()
    } else {
      this.showExifPanel()
    }
  }

  // Show EXIF panel
  showExifPanel() {
    if (this.hasExifPanelTarget) {
      this.exifPanelTarget.classList.remove("hidden")
      this.exifPanelOpen = true
      localStorage.setItem('exifPanelOpen', 'true')
      this.loadExifData()
    }
  }

  // Hide EXIF panel
  hideExifPanel() {
    if (this.hasExifPanelTarget) {
      this.exifPanelTarget.classList.add("hidden")
      this.exifPanelOpen = false
      localStorage.setItem('exifPanelOpen', 'false')
    }
  }

  // Load and display EXIF data for current photo
  loadExifData() {
    if (!this.hasExifContentTarget) return

    const currentImage = this.imageTargets[this.currentIndex]
    if (!currentImage) return

    const photoId = currentImage.dataset.photoId
    const originalPath = currentImage.dataset.originalPath
    const exifData = currentImage.dataset.exifData

    // Start with loading message
    this.exifContentTarget.innerHTML = '<div class="text-gray-500">Loading EXIF data...</div>'

    // Display basic info immediately
    let html = ''

    // Original filename
    if (originalPath) {
      const filename = originalPath.split('/').pop()
      html += this.createExifRow('Original File', filename)
    }

    // Photo ID for reference
    html += this.createExifRow('Photo ID', photoId)

    // Check if we have comprehensive EXIF data already
    if (exifData && exifData !== 'null') {
      try {
        const data = JSON.parse(exifData)

        // Check if we have organized category data (Camera, Exposure, Image, etc.)
        const hasCategories = ['Camera', 'Exposure', 'Image', 'Other'].some(category => data[category])

        if (hasCategories) {
          // Display the full organized data
          this.displayFullExifData(data)
          return // Don't make API call
        } else {
          // Just basic data like DateTimeOriginal - show it and then load full data
          if (data.DateTimeOriginal) {
            html += this.createExifRow('Taken', data.DateTimeOriginal)
          }
        }
      } catch (e) {
        console.warn('Failed to parse EXIF data:', e)
      }
    }

    // Show basic data while loading full data
    if (html) {
      this.exifContentTarget.innerHTML = html
    } else {
      this.exifContentTarget.innerHTML = '<div class="text-gray-500">Loading EXIF data...</div>'
    }

    // Load full EXIF data via API if not already comprehensive
    this.loadFullExifData(photoId)
  }

  // Create a formatted EXIF row
  createExifRow(label, value) {
    return `
      <div class="flex justify-between py-2 border-b border-gray-800/30 last:border-0">
        <span class="text-red-400 font-medium text-sm">${label}:</span>
        <span class="text-yellow-500 text-right ml-4 break-all text-sm font-mono">${value}</span>
      </div>
    `
  }

  // Load full EXIF data via API
  loadFullExifData(photoId) {
    // Check if we already have comprehensive EXIF data
    const currentImage = this.imageTargets[this.currentIndex]
    const existingExifData = currentImage.dataset.exifData

    // Skip if we already have comprehensive data (organized categories like Camera, Exposure, etc.)
    if (existingExifData && existingExifData !== 'null') {
      try {
        const data = JSON.parse(existingExifData)
        // Check if we have organized category data (Camera, Exposure, Image, etc.)
        const hasCategories = ['Camera', 'Exposure', 'Image', 'Other'].some(category => data[category])
        if (hasCategories) {
          return // Already have full organized data
        }
      } catch (e) {
        // Continue with API call if parsing fails
      }
    }

    // Add loading indicator
    this.showExifLoading()

    // Get CSRF token
    const token = document.querySelector('meta[name="csrf-token"]').content

    // Make API request for full EXIF extraction
    fetch(`/api/photos/${photoId}/extract_exif`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': token,
        'Accept': 'application/json'
      }
    })
    .then(response => response.json())
    .then(data => {
      if (data.status === 'success') {
        // Update the data attribute with the new comprehensive EXIF data
        const currentImage = this.imageTargets[this.currentIndex]
        const existingData = currentImage.dataset.exifData ? JSON.parse(currentImage.dataset.exifData) : {}
        const mergedData = { ...existingData, ...data.exif_data }
        currentImage.dataset.exifData = JSON.stringify(mergedData)

        this.displayFullExifData(data.exif_data)
      } else {
        this.showExifError(data.message || 'Failed to extract EXIF data')
      }
    })
    .catch(error => {
      console.error('Failed to load EXIF data:', error)
      this.showExifError('Network error while loading EXIF data')
    })
  }

  // Show loading indicator in EXIF panel
  showExifLoading() {
    if (!this.hasExifContentTarget) return

    const existingContent = this.exifContentTarget.innerHTML
    this.exifContentTarget.innerHTML = `
      ${existingContent}
      <div class="mt-4 flex items-center gap-3 text-yellow-500">
        <div class="animate-spin rounded-full h-4 w-4 border-2 border-yellow-500 border-t-transparent"></div>
        <span class="text-sm">Extracting full EXIF data...</span>
      </div>
    `
  }

  // Load EXIF field configuration from API
  loadExifConfiguration() {
    this.exifVisibleFields = null // Initialize

    fetch('/api/photos/exif_config')
      .then(response => response.json())
      .then(data => {
        if (data.status === 'success') {
          this.exifVisibleFields = data.visible_fields
          console.log('Loaded EXIF field configuration:', this.exifVisibleFields)
        }
      })
      .catch(error => {
        console.warn('Failed to load EXIF configuration:', error)
        // Fall back to showing all fields if config can't be loaded
        this.exifVisibleFields = null
      })
  }

  // Display comprehensive EXIF data (filtered by configuration)
  displayFullExifData(exifData) {
    if (!this.hasExifContentTarget) return

    // Get current basic data
    const currentImage = this.imageTargets[this.currentIndex]
    const photoId = currentImage.dataset.photoId
    const originalPath = currentImage.dataset.originalPath

    // Start fresh with all data
    let html = ''

    // Original filename (always show first)
    if (originalPath) {
      const filename = originalPath.split('/').pop()
      html += this.createExifRow('Original File', filename)
    }

    // Photo ID
    html += this.createExifRow('Photo ID', photoId)

    // Organize and display filtered EXIF data by category
    if (exifData && typeof exifData === 'object') {
      Object.keys(exifData).forEach(category => {
        const categoryData = exifData[category]
        const visibleFields = this.getVisibleFieldsForCategory(category, categoryData)

        if (categoryData && Object.keys(categoryData).length > 0 && visibleFields.length > 0) {
          // Filter category data to only show visible fields
          const filteredData = {}
          visibleFields.forEach(field => {
            if (categoryData[field] !== undefined) {
              filteredData[field] = categoryData[field]
            }
          })

          // Only show category if it has visible fields with data
          if (Object.keys(filteredData).length > 0) {
            // Add category header
            html += `
              <div class="mt-4 mb-2">
                <h4 class="text-red-400 font-bold text-xs uppercase tracking-wide border-b border-red-700/30 pb-1">
                  ${category}
                </h4>
              </div>
            `

            // Add filtered category items
            Object.keys(filteredData).forEach(key => {
              const value = filteredData[key]
              if (value !== null && value !== '' && value !== 'undef') {
                html += this.createExifRow(this.humanizeExifKey(key), value)
              }
            })
          }
        }
      })
    }

    this.exifContentTarget.innerHTML = html || '<div class="text-gray-500">No EXIF data available</div>'
  }

  // Get visible fields for a specific category
  getVisibleFieldsForCategory(category, availableFields = {}) {
    // If configuration not loaded yet, return all available fields as fallback
    if (!this.exifVisibleFields) {
      return Object.keys(availableFields)
    }

    return this.exifVisibleFields[category] || []
  }

  // Show error in EXIF panel
  showExifError(message) {
    if (!this.hasExifContentTarget) return

    // Keep existing basic data and add error message
    const currentImage = this.imageTargets[this.currentIndex]
    const photoId = currentImage.dataset.photoId
    const originalPath = currentImage.dataset.originalPath

    let html = ''

    if (originalPath) {
      const filename = originalPath.split('/').pop()
      html += this.createExifRow('Original File', filename)
    }

    html += this.createExifRow('Photo ID', photoId)

    html += `
      <div class="mt-4 p-3 bg-red-900/20 border border-red-700/50 rounded text-red-400 text-sm">
        <strong>EXIF extraction failed:</strong><br>
        ${message}
      </div>
    `

    this.exifContentTarget.innerHTML = html
  }

  // Convert technical EXIF keys to human readable labels
  humanizeExifKey(key) {
    const mappings = {
      'Make': 'Camera Make',
      'Model': 'Camera Model',
      'LensModel': 'Lens',
      'ExposureTime': 'Shutter Speed',
      'FNumber': 'Aperture',
      'ISO': 'ISO',
      'FocalLength': 'Focal Length',
      'DateTime': 'Date Modified',
      'DateTimeOriginal': 'Taken',
      'ImageWidth': 'Width',
      'ImageHeight': 'Height',
      'Orientation': 'Orientation',
      'WhiteBalance': 'White Balance',
      'Flash': 'Flash',
      'ExposureProgram': 'Exposure Mode',
      'MeteringMode': 'Metering',
      'ColorSpace': 'Color Space'
    }

    return mappings[key] || key.replace(/([A-Z])/g, ' $1').trim()
  }
}
