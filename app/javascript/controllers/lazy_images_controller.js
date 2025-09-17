import { Controller } from "@hotwired/stimulus"

// Lazy Images Controller
// Uses Intersection Observer for efficient lazy loading of thumbnails
export default class extends Controller {
  static targets = ["image"]
  
  connect() {
    // Prevent multiple connections
    if (this.isConnected) return
    this.isConnected = true
    
    // console.log('🔍 Lazy Images: Setting up intersection observer for', this.imageTargets.length, 'targets')
    
    // Create intersection observer
    this.observer = new IntersectionObserver((entries) => {
      entries.forEach(entry => {
        if (entry.isIntersecting) {
          const img = entry.target
          if (img.dataset.src) {
            // console.log('🔄 Observer: Loading image', img.dataset.src.substring(0, 80) + '...')
            this.loadImage(img)
            this.observer.unobserve(img) // Stop observing once loaded
          }
        }
      })
    }, {
      rootMargin: '100px', // Load images 100px before they come into view
      threshold: 0.1
    })
    
    // Start observing all image targets
    this.imageTargets.forEach(img => {
      if (img.dataset.src) {
        this.observer.observe(img)
      }
    })
  }
  
  disconnect() {
    this.isConnected = false
    if (this.observer) {
      this.observer.disconnect()
    }
  }
  
  loadImage(img) {
    const src = img.dataset.src
    if (!src) return
    
    // console.log('🔄 Starting load:', src.substring(0, 80) + '...')
    
    // Create a new image to preload
    const imageLoader = new Image()
    
    imageLoader.onload = () => {
      // console.log('✅ SUCCESS:', src.substring(0, 80) + '...')
      img.src = src
      img.classList.add('loaded')
      img.removeAttribute('data-src')
      
      // Fade in effect
      img.style.transition = 'opacity 0.3s ease-in-out'
      img.style.opacity = '1'
    }
    
    imageLoader.onerror = () => {
      // console.error('❌ FAILED:', src.substring(0, 80) + '...')
      img.classList.add('error')
      
      // Show error state visually
      img.style.backgroundColor = '#dc2626'
      img.style.opacity = '0.5'
    }
    
    // Start loading
    imageLoader.src = src
  }
  
  // Method to manually trigger loading (e.g., for images that come into view via user action)
  loadAll() {
    this.imageTargets.forEach(img => {
      if (img.dataset.src) {
        this.loadImage(img)
      }
    })
  }
}