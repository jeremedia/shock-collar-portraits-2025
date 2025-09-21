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

    // For grid-level controller, find loader in child containers
    this.startLoadingListener = (event) => {
      const container = event.target.closest('[data-thumbnail-container]')
      if (container && this.element.contains(container)) {
        const loader = container.querySelector('[data-lazy-images-target="loader"]')
        if (loader) {
          this.queueLoaderForElement(loader)
        }
      }
    }

    this.finishLoadingListener = (event) => {
      const container = event.target.closest('[data-thumbnail-container]')
      if (container && this.element.contains(container)) {
        const loader = container.querySelector('[data-lazy-images-target="loader"]')
        if (loader) {
          this.completeLoaderForElement(loader)
        }
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

          // Check if the image is actually visible (not in a hidden container)
          if (!this.isElementReallyVisible(img)) {
            // console.log('🚫 Skipping hidden image')
            return
          }

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
    
    // Start observing all images in the grid
    // Don't start observing if we're hidden initially
    // Check if we're inside a hidden accordion content section
    const accordionContent = this.element.closest('[data-day-accordion-target="content"]')
    const isHidden = accordionContent && accordionContent.classList.contains('hidden')

    if (!isHidden) {
      this.observeImages()
    }
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
  
  observeImages() {
    // Find all images in the grid
    const images = this.element.querySelectorAll('img[data-src]')
    images.forEach(img => {
      this.observer.observe(img)
    })
  }

  unobserveImages() {
    // Stop observing all images
    const images = this.element.querySelectorAll('img[data-src]')
    images.forEach(img => {
      this.observer.unobserve(img)
    })
  }

  isElementReallyVisible(element) {
    // Check if element or any parent has display:none or is hidden
    let el = element
    while (el) {
      const style = window.getComputedStyle(el)
      if (style.display === 'none' || style.visibility === 'hidden') {
        return false
      }

      // Check for the hidden class (used by accordion)
      if (el.classList && el.classList.contains('hidden')) {
        return false
      }

      // Check for accordion content target that might be hidden
      if (el.dataset && el.dataset.dayAccordionTarget === 'content') {
        if (el.classList.contains('hidden')) {
          return false
        }
      }

      el = el.parentElement
    }
    return true
  }

  async loadImage(img) {
    const src = img.dataset.src
    if (!src) return

    // Check if image is in cache first
    let cachedResponse = null
    if ('caches' in window) {
      try {
        const cache = await caches.open('thumbnail-cache-v1')
        cachedResponse = await cache.match(src)
      } catch (e) {
        console.warn('Cache check failed:', e)
      }
    }

    // If we have a cached response, use it directly
    if (cachedResponse) {
      try {
        const blob = await cachedResponse.blob()
        const objectURL = URL.createObjectURL(blob)
        img.src = objectURL
        img.classList.add('loaded')
        img.removeAttribute('data-src')
        img.dataset.heroCurrentSrc = src
        img.style.transition = 'opacity 0.3s ease-in-out'
        img.style.opacity = '1'
        img.dispatchEvent(new CustomEvent('thumbnail:loaded', { bubbles: true }))
        return
      } catch (e) {
        console.warn('Failed to use cached image:', e)
        // Fall through to normal loading
      }
    }

    // Not in cache, need to load it
    const container = img.closest('[data-thumbnail-container]')
    const loader = container ? container.querySelector('[data-lazy-images-target="loader"]') : null
    if (loader) {
      this.queueLoaderForElement(loader)
    }

    // Create a new image to preload
    const imageLoader = new Image()

    imageLoader.onload = async () => {
      img.src = src
      img.classList.add('loaded')
      img.removeAttribute('data-src')
      img.dataset.heroCurrentSrc = src

      // Fade in effect
      img.style.transition = 'opacity 0.3s ease-in-out'
      img.style.opacity = '1'

      // Store in cache for future use
      if ('caches' in window) {
        try {
          const cache = await caches.open('thumbnail-cache-v1')
          // Fetch the image to get it as a Response
          const response = await fetch(src)
          if (response.ok) {
            // Clone the response before storing it
            await cache.put(src, response.clone())
          }
        } catch (e) {
          console.warn('Failed to cache image:', e)
        }
      }

      img.dispatchEvent(new CustomEvent('thumbnail:loaded', { bubbles: true }))
    }

    imageLoader.onerror = () => {
      img.classList.add('error')
      img.style.backgroundColor = '#dc2626'
      img.style.opacity = '0.5'

      if (loader) {
        this.resetLoaderElement(loader)
      }
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

  queueLoaderForElement(loader) {
    if (!loader) return
    // Store timeout on the loader element itself
    if (loader.completeTimeout) clearTimeout(loader.completeTimeout)

    if (loader.classList.contains('thumbnail-loader--active')) {
      loader.classList.remove('thumbnail-loader--complete')
      loader.classList.remove('thumbnail-loader--fading')
      return
    }

    if (loader.delayTimeout) clearTimeout(loader.delayTimeout)
    loader.delayTimeout = setTimeout(() => {
      this.activateLoaderElement(loader)
    }, 1000)
  }

  completeLoaderForElement(loader) {
    if (!loader) return
    if (loader.delayTimeout) {
      clearTimeout(loader.delayTimeout)
      loader.delayTimeout = null
    }
    if (loader.completeTimeout) {
      clearTimeout(loader.completeTimeout)
      loader.completeTimeout = null
    }

    if (!loader.classList.contains('thumbnail-loader--active')) {
      this.startFadeOutElement(loader)
      return
    }
    loader.classList.add('thumbnail-loader--complete')
    this.startFadeOutElement(loader)
  }

  resetLoaderElement(loader) {
    if (!loader) return
    loader.classList.remove('thumbnail-loader--active', 'thumbnail-loader--complete', 'thumbnail-loader--fading')
    if (loader.delayTimeout) {
      clearTimeout(loader.delayTimeout)
      loader.delayTimeout = null
    }
    if (loader.completeTimeout) {
      clearTimeout(loader.completeTimeout)
      loader.completeTimeout = null
    }
  }

  activateLoaderElement(loader) {
    if (!loader) return
    loader.classList.remove('thumbnail-loader--complete')
    loader.classList.remove('thumbnail-loader--fading')
    loader.classList.add('thumbnail-loader--active')
  }

  // Legacy methods for compatibility with old views
  queueLoader() {
    // Find first loader in element
    const loader = this.element.querySelector('[data-lazy-images-target="loader"]')
    if (loader) this.queueLoaderForElement(loader)
  }

  completeLoader() {
    // Find first loader in element
    const loader = this.element.querySelector('[data-lazy-images-target="loader"]')
    if (loader) this.completeLoaderForElement(loader)
  }

  startFadeOutElement(loader) {
    if (!loader) return
    if (loader.completeTimeout) clearTimeout(loader.completeTimeout)
    loader.classList.remove('thumbnail-loader--active')
    loader.classList.add('thumbnail-loader--fading')
    loader.completeTimeout = setTimeout(() => {
      this.resetLoaderElement(loader)
    }, 900)
  }
}
