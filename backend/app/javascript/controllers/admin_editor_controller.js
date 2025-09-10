import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

export default class extends Controller {
  static targets = ["overlay", "image", "info", "thumbnail", "heroButton", "rejectButton", "splitButton", "loading"]
  static values = { 
    currentIndex: Number,
    photos: Array
  }
  
  connect() {
    // Build photos array from all thumbnails on page
    this.buildPhotosArray()
    
    // Add keyboard listener
    this.handleKeyPress = this.handleKeyPress.bind(this)
    
    // Listen for session updates
    this.handleSessionUpdate = this.handleSessionUpdate.bind(this)
    document.addEventListener('sessions:updated', this.handleSessionUpdate)
    
    // Listen for Turbo Stream updates
    this.handleTurboLoad = this.handleTurboLoad.bind(this)
    document.addEventListener('turbo:load', this.handleTurboLoad)
    document.addEventListener('turbo:frame-load', this.handleTurboLoad)
  }
  
  disconnect() {
    document.removeEventListener("keydown", this.handleKeyPress)
    document.removeEventListener('sessions:updated', this.handleSessionUpdate)
    document.removeEventListener('turbo:load', this.handleTurboLoad)
    document.removeEventListener('turbo:frame-load', this.handleTurboLoad)
  }
  
  handleSessionUpdate(event) {
    console.log('Sessions updated:', event.detail)
    // Rebuild the photos array after DOM update
    setTimeout(() => {
      this.buildPhotosArray()
      // If overlay is open, update the current photo's data
      if (!this.overlayTarget.classList.contains('hidden')) {
        const currentPhoto = this.photosValue[this.currentIndexValue]
        if (currentPhoto) {
          this.updateOverlayContent(currentPhoto)
        }
      }
    }, 100)
  }
  
  handleTurboLoad() {
    // Rebuild photos array after Turbo updates the DOM
    this.buildPhotosArray()
  }
  
  buildPhotosArray() {
    const photos = []
    this.thumbnailTargets.forEach((thumb) => {
      const globalIndex = parseInt(thumb.dataset.index)
      photos[globalIndex] = {
        index: globalIndex,
        photoId: thumb.dataset.photoId,
        sessionId: thumb.dataset.sessionId,
        sessionNumber: thumb.dataset.sessionNumber,
        filename: thumb.dataset.filename,
        position: thumb.dataset.position,
        imageUrl: thumb.dataset.imageUrl,
        largeUrl: thumb.dataset.largeUrl,
        rejected: thumb.dataset.rejected === 'true',
        isHero: thumb.dataset.isHero === 'true',
        dayName: thumb.dataset.dayName,
        sessionTime: thumb.dataset.sessionTime,
        faceCount: parseInt(thumb.dataset.faceCount || 0)
      }
    })
    this.photosValue = photos
    console.log(`Built photos array with ${photos.length} photos`)
  }
  
  selectPhoto(event) {
    event.preventDefault()
    const thumbnail = event.currentTarget
    const index = parseInt(thumbnail.dataset.index)
    this.showOverlay(index)
  }
  
  showOverlay(index) {
    this.currentIndexValue = index
    const photo = this.photosValue[index]
    
    if (!photo) return
    
    // Update overlay content
    this.updateOverlayContent(photo)
    
    // Show overlay
    this.overlayTarget.classList.remove('hidden')
    
    // Add keyboard listener
    document.addEventListener("keydown", this.handleKeyPress)
    
    // Update button states
    this.updateButtonStates(photo)
    
    // Highlight current thumbnail
    this.highlightThumbnail(index)
  }
  
  updateOverlayContent(photo) {
    // Show loading state
    this.showImageLoading()
    
    // Create new image to preload
    const img = new Image()
    img.onload = () => {
      // Hide loading and show image
      this.hideImageLoading()
      this.imageTarget.src = img.src
      this.imageTarget.alt = photo.filename
      this.imageTarget.classList.remove('opacity-0')
    }
    img.onerror = () => {
      // Hide loading and show fallback
      this.hideImageLoading()
      this.imageTarget.src = photo.imageUrl || ''
      this.imageTarget.alt = photo.filename
      this.imageTarget.classList.remove('opacity-0')
    }
    
    // Start loading the image
    img.src = photo.largeUrl || photo.imageUrl
    
    // Update info text immediately
    const infoText = `
      <div class="text-white">
        <div class="text-lg font-bold">${photo.dayName} - Session ${photo.sessionNumber}</div>
        <div class="text-sm text-gray-300">${photo.sessionTime} • Photo ${parseInt(photo.position) + 1} • ${photo.filename}</div>
        <div class="text-xs text-gray-400 mt-1">
          ${photo.isHero ? '<span class="text-yellow-500">★ Hero</span>' : ''}
          ${photo.rejected ? '<span class="text-red-500">✗ Rejected</span>' : ''}
          ${photo.faceCount > 0 ? `<span class="text-blue-400">👤 ${photo.faceCount} face${photo.faceCount > 1 ? 's' : ''}</span>` : ''}
        </div>
      </div>
    `
    this.infoTarget.innerHTML = infoText
    
    // Update button states
    this.heroButtonTarget.textContent = photo.isHero ? '★ Hero Selected' : '☆ Set as Hero'
    this.heroButtonTarget.classList.toggle('bg-yellow-600', photo.isHero)
    this.heroButtonTarget.classList.toggle('bg-gray-600', !photo.isHero)
    
    this.rejectButtonTarget.textContent = photo.rejected ? '✅ Rejected' : '🗑️ Reject'
    this.rejectButtonTarget.classList.toggle('bg-red-600', photo.rejected)
    this.rejectButtonTarget.classList.toggle('bg-gray-600', !photo.rejected)
  }
  
  updateButtonStates(photo) {
    // Enable/disable split button based on position
    const canSplit = parseInt(photo.position) > 0
    this.splitButtonTarget.disabled = !canSplit
    this.splitButtonTarget.classList.toggle('opacity-50', !canSplit)
    this.splitButtonTarget.classList.toggle('cursor-not-allowed', !canSplit)
  }
  
  highlightThumbnail(index) {
    // Remove previous highlight
    this.thumbnailTargets.forEach(thumb => {
      thumb.classList.remove('ring-4', 'ring-yellow-500')
    })
    
    // Add highlight to current
    if (this.thumbnailTargets[index]) {
      this.thumbnailTargets[index].classList.add('ring-4', 'ring-yellow-500')
      
      // Scroll into view if needed, but only if not visible
      const rect = this.thumbnailTargets[index].getBoundingClientRect()
      const isVisible = rect.top >= 0 && rect.bottom <= window.innerHeight
      if (!isVisible) {
        this.thumbnailTargets[index].scrollIntoView({ behavior: 'smooth', block: 'center' })
      }
    }
  }
  
  closeOverlay() {
    this.overlayTarget.classList.add('hidden')
    document.removeEventListener("keydown", this.handleKeyPress)
    
    // Remove thumbnail highlight
    this.thumbnailTargets.forEach(thumb => {
      thumb.classList.remove('ring-4', 'ring-yellow-500')
    })
  }
  
  handleKeyPress(event) {
    switch(event.key) {
      case 'Escape':
        this.closeOverlay()
        break
      case 'ArrowLeft':
        event.preventDefault()
        this.previousPhoto()
        break
      case 'ArrowRight':
        event.preventDefault()
        this.nextPhoto()
        break
      case 'h':
      case 'H':
        event.preventDefault()
        this.setHero()
        break
      case 'r':
      case 'R':
        event.preventDefault()
        this.toggleReject()
        break
      case 's':
      case 'S':
        event.preventDefault()
        if (!this.splitButtonTarget.disabled) {
          this.splitSession()
        }
        break
    }
  }
  
  previousPhoto() {
    if (this.currentIndexValue > 0) {
      this.showOverlay(this.currentIndexValue - 1)
    }
  }
  
  nextPhoto() {
    if (this.currentIndexValue < this.photosValue.length - 1) {
      this.showOverlay(this.currentIndexValue + 1)
    }
  }
  
  async setHero() {
    const photo = this.photosValue[this.currentIndexValue]
    if (!photo) return
    
    this.showLoading()
    
    try {
      const response = await fetch(`/gallery/${photo.sessionId}/update_hero`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
        },
        body: JSON.stringify({ photo_id: photo.photoId })
      })
      
      if (response.ok) {
        // Update local state
        this.photosValue.forEach(p => {
          if (p.sessionId === photo.sessionId) {
            p.isHero = p.photoId === photo.photoId
          }
        })
        
        // Update thumbnail indicators
        this.updateThumbnailIndicators(photo.sessionId, photo.photoId)
        
        // Update overlay
        this.updateOverlayContent(this.photosValue[this.currentIndexValue])
      }
    } catch (error) {
      console.error('Error setting hero:', error)
    } finally {
      this.hideLoading()
    }
  }
  
  async toggleReject() {
    const photo = this.photosValue[this.currentIndexValue]
    if (!photo) return
    
    this.showLoading()
    
    try {
      const response = await fetch(`/gallery/${photo.sessionId}/reject_photo`, {
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
        },
        body: JSON.stringify({ photo_id: photo.photoId })
      })
      
      if (response.ok) {
        // Toggle local state
        photo.rejected = !photo.rejected
        
        // Update thumbnail indicator
        const thumb = this.thumbnailTargets[this.currentIndexValue]
        const rejectDot = thumb.querySelector('.reject-indicator')
        if (photo.rejected) {
          if (!rejectDot) {
            // Find the image element to insert the indicator after it
            const img = thumb.querySelector('img')
            if (img) {
              img.insertAdjacentHTML('afterend', '<div class="reject-indicator absolute top-1 left-1 w-2 h-2 bg-red-500 rounded-full pointer-events-none z-10"></div>')
            }
          }
        } else {
          if (rejectDot) rejectDot.remove()
        }
        
        // Update overlay
        this.updateOverlayContent(photo)
      }
    } catch (error) {
      console.error('Error toggling reject:', error)
    } finally {
      this.hideLoading()
    }
  }
  
  async splitSession() {
    const photo = this.photosValue[this.currentIndexValue]
    if (!photo || parseInt(photo.position) === 0) return
    
    if (!confirm(`Split session ${photo.sessionNumber} at photo ${parseInt(photo.position) + 1}?`)) {
      return
    }
    
    this.showLoading()
    
    try {
      const response = await fetch(`/gallery/${photo.sessionId}/split_session`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'text/vnd.turbo-stream.html, application/json',
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
        },
        body: JSON.stringify({ photo_id: photo.photoId, turbo: true })
      })
      
      if (response.ok) {
        const contentType = response.headers.get('content-type')
        
        if (contentType && contentType.includes('text/vnd.turbo-stream.html')) {
          // Turbo Stream response - apply the updates
          const html = await response.text()
          Turbo.renderStreamMessage(html)
          
          // The sessions:updated event will be triggered by the Turbo Stream
          // which will rebuild the photos array automatically
          
          // Keep the overlay open but don't change the current photo
          // The user can continue navigating
        } else {
          // JSON response fallback
          const data = await response.json()
          if (data.success) {
            if (data.turbo_streams) {
              // Apply Turbo Stream updates from JSON
              Turbo.renderStreamMessage(data.turbo_streams)
            } else {
              // Fallback to reload
              window.location.reload()
            }
          } else {
            alert(data.error || 'Failed to split session')
          }
        }
      } else {
        const data = await response.json()
        alert(data.error || 'Failed to split session')
      }
    } catch (error) {
      console.error('Error splitting session:', error)
      alert('Error splitting session')
    } finally {
      this.hideLoading()
    }
  }
  
  updateThumbnailIndicators(sessionId, heroPhotoId) {
    // Remove all hero indicators for this session
    this.thumbnailTargets.forEach(thumb => {
      if (thumb.dataset.sessionId === sessionId) {
        const heroDot = thumb.querySelector('.hero-indicator')
        if (heroDot) heroDot.remove()
      }
    })
    
    // Add hero indicator to new hero
    const heroThumb = this.thumbnailTargets.find(t => t.dataset.photoId === heroPhotoId)
    if (heroThumb) {
      const img = heroThumb.querySelector('img')
      if (img) {
        img.insertAdjacentHTML('afterend', '<div class="hero-indicator absolute top-1 right-1 w-2 h-2 bg-yellow-500 rounded-full pointer-events-none z-10"></div>')
      }
    }
  }
  
  showLoading() {
    if (this.hasLoadingTarget) {
      this.loadingTarget.classList.remove('hidden')
    }
  }
  
  hideLoading() {
    if (this.hasLoadingTarget) {
      this.loadingTarget.classList.add('hidden')
    }
  }
  
  showImageLoading() {
    // Hide current image and show loader
    this.imageTarget.classList.add('opacity-0')
    if (this.hasLoadingTarget) {
      this.loadingTarget.classList.remove('hidden')
    }
  }
  
  hideImageLoading() {
    // Hide loader
    if (this.hasLoadingTarget) {
      this.loadingTarget.classList.add('hidden')
    }
  }
}