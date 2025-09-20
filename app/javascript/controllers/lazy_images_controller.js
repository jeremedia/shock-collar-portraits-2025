import { Controller } from "@hotwired/stimulus"

// Lazy Images Controller
// Uses Intersection Observer for efficient lazy loading of thumbnails
export default class extends Controller {
  static targets = ["image", "loader"]
  
  connect() {
    // Prevent multiple connections
    if (this.isConnected) return
    this.isConnected = true

    this.completeTimeout = null
    this.loaderDelayTimeout = null
    this.loaderShown = false

    this.startLoadingListener = (event) => {
      if (this.imageTargets.includes(event.target)) {
        this.queueLoader()
      }
    }

    this.finishLoadingListener = (event) => {
      if (this.imageTargets.includes(event.target)) {
        this.completeLoader()
      }
    }

    this.element.addEventListener('thumbnail:loading', this.startLoadingListener)
    this.element.addEventListener('thumbnail:loaded', this.finishLoadingListener)
    
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
    this.element.removeEventListener('thumbnail:loading', this.startLoadingListener)
    this.element.removeEventListener('thumbnail:loaded', this.finishLoadingListener)
    this.clearLoaderDelay()
    this.clearCompletionTimeout()
  }
  
  loadImage(img) {
    const src = img.dataset.src
    if (!src) return
    
    // console.log('🔄 Starting load:', src.substring(0, 80) + '...')
    
    // Create a new image to preload
    const imageLoader = new Image()

    this.queueLoader()
    
    imageLoader.onload = () => {
      // console.log('✅ SUCCESS:', src.substring(0, 80) + '...')
      img.src = src
      img.classList.add('loaded')
      img.removeAttribute('data-src')
      img.dataset.heroCurrentSrc = src
      
      // Fade in effect
      img.style.transition = 'opacity 0.3s ease-in-out'
      img.style.opacity = '1'

      img.dispatchEvent(new CustomEvent('thumbnail:loaded', { bubbles: true }))
    }

    imageLoader.onerror = () => {
      // console.error('❌ FAILED:', src.substring(0, 80) + '...')
      img.classList.add('error')
      
      // Show error state visually
      img.style.backgroundColor = '#dc2626'
      img.style.opacity = '0.5'

      this.resetLoader()
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

  queueLoader() {
    if (!this.hasLoaderTarget) return
    const loader = this.loaderTarget
    this.clearCompletionTimeout()
    if (this.loaderShown) {
      loader.classList.remove('thumbnail-loader--complete')
      loader.classList.remove('thumbnail-loader--fading')
      loader.classList.add('thumbnail-loader--active')
      return
    }
    this.clearLoaderDelay()
    this.loaderDelayTimeout = setTimeout(() => {
      this.activateLoader()
    }, 1000)
  }

  completeLoader() {
    if (!this.hasLoaderTarget) return
    this.clearLoaderDelay()
    this.clearCompletionTimeout()
    const loader = this.loaderTarget
    if (!this.loaderShown) {
      this.startFadeOut(loader)
      return
    }
    loader.classList.add('thumbnail-loader--complete')
    this.startFadeOut(loader)
  }

  resetLoader() {
    if (!this.hasLoaderTarget) return
    const loader = this.loaderTarget
    loader.classList.remove('thumbnail-loader--active', 'thumbnail-loader--complete', 'thumbnail-loader--fading')
    this.clearLoaderDelay()
    this.clearCompletionTimeout()
    this.loaderShown = false
  }

  activateLoader() {
    if (!this.hasLoaderTarget) return
    this.loaderShown = true
    const loader = this.loaderTarget
    loader.classList.remove('thumbnail-loader--complete')
    loader.classList.remove('thumbnail-loader--fading')
    loader.classList.add('thumbnail-loader--active')
  }

  clearLoaderDelay() {
    if (this.loaderDelayTimeout) {
      clearTimeout(this.loaderDelayTimeout)
      this.loaderDelayTimeout = null
    }
  }

  clearCompletionTimeout() {
    if (this.completeTimeout) {
      clearTimeout(this.completeTimeout)
      this.completeTimeout = null
    }
  }

  startFadeOut(loader) {
    if (!loader) return
    this.clearCompletionTimeout()
    loader.classList.remove('thumbnail-loader--active')
    loader.classList.add('thumbnail-loader--fading')
    this.loaderShown = false
    this.completeTimeout = setTimeout(() => {
      this.resetLoader()
    }, 900)
  }
}
