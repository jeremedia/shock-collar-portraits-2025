import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["image", "counter", "thumbnail", "heroInput", "heroButton", "heroPhotoId", "emailForm", "rejectInput", "rejectButton", "splitButton", "imageWrapper", "faceOverlay", "faceRectangleToggle", "downloadButton"]
  static values = { total: Number, sessionId: String, showRejected: Boolean, prevSession: String, nextSession: String }
  
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
        this.currentIndex = 0
      }
    } else {
      this.currentIndex = 0
    }
    
    // Load face rectangle preference
    if (this.hasFaceRectangleToggleTarget) {
      const showRectangles = localStorage.getItem('showFaceRectangles') === 'true'
      this.faceRectangleToggleTarget.checked = showRectangles
    }
    
    this.setupImageLoading()
    this.updateDisplay()
    
    // Add keyboard navigation
    document.addEventListener("keydown", this.handleKeyPress.bind(this))
    
    // Preload session thumbnails in service worker cache
    this.preloadSessionThumbnails()
  }
  
  setupImageLoading() {
    // Add loading states to main images
    this.imageTargets.forEach((container) => {
      this.addLoadingOverlay(container, 'loading-spinner')
    })
    
    // Add loading states to thumbnails
    this.thumbnailTargets.forEach((thumb) => {
      this.addLoadingOverlay(thumb, 'loading-spinner loading-spinner-small')
    })
  }
  
  addLoadingOverlay(container, spinnerClass) {
    const img = container.querySelector('img')
    if (!img) return
    
    // Create loading overlay
    const overlay = document.createElement('div')
    overlay.className = 'loading-overlay'
    
    // Create spinner
    const spinner = document.createElement('div')
    spinner.className = spinnerClass
    overlay.appendChild(spinner)
    
    // Add overlay to container
    container.appendChild(overlay)
    
    // Remove overlay when image loads
    const removeOverlay = () => {
      if (overlay && overlay.parentNode) {
        overlay.remove()
      }
    }
    
    // Check if image is already loaded
    if (img.complete && img.naturalHeight > 0) {
      removeOverlay()
    } else {
      img.addEventListener('load', () => {
        removeOverlay()
        // Update face rectangles after image loads
        this.updateFaceRectangles()
      }, { once: true })
      img.addEventListener('error', removeOverlay, { once: true })
    }
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
      case " ":
        event.preventDefault()
        this.heroButtonTarget.click()
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
      // Add parameter to start at first photo (default)
      const url = new URL(this.nextSessionValue, window.location.origin)
      if (this.showRejectedValue) {
        url.searchParams.set('show_rejected', 'true')
      }
      window.location.href = url.href
    }
  }
  
  updateDisplay() {
    // Update URL with current image position
    this.updateURL()
    
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
        button.classList.add("bg-green-600", "text-white")
        button.classList.remove("bg-yellow-600/90", "text-black")
      } else {
        button.value = button.dataset.selectText || "☆ Select as Hero"
        button.classList.add("bg-yellow-600/90", "text-black")
        button.classList.remove("bg-green-600", "text-white")
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
  
  // Update URL with current image position
  updateURL() {
    const url = new URL(window.location)
    url.searchParams.set('image', this.currentIndex + 1) // Use 1-based index for user-friendly URLs
    
    // Preserve existing parameters like show_rejected
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
}