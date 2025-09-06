import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["image", "counter", "thumbnail", "heroInput", "heroButton", "heroPhotoId", "emailForm", "rejectInput", "rejectButton", "splitButton"]
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
    
    this.setupImageLoading()
    this.updateDisplay()
    
    // Add keyboard navigation
    document.addEventListener("keydown", this.handleKeyPress.bind(this))
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
      img.addEventListener('load', removeOverlay, { once: true })
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
}