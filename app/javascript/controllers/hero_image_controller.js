import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["image", "spinner"]
  static values = {
    fullSrc: String,
    nextSrc: String,
    prevSrc: String
  }

  connect() {
    this.setupContainerDimensions()
    this.loadFullImage()
    this.setupResizeHandler()
    this.preloadAdjacentImages()
  }

  disconnect() {
    // Clean up resize handler
    if (this.resizeHandler) {
      window.removeEventListener('resize', this.resizeHandler)
    }
  }

  setupContainerDimensions() {
    // Calculate and set fixed dimensions for the container
    const container = this.element

    // Check if we have stored dimensions from a previous navigation
    const storedHeight = sessionStorage.getItem('heroImageContainerHeight')
    const storedWidth = sessionStorage.getItem('heroImageContainerWidth')
    const storedWindowWidth = sessionStorage.getItem('heroImageWindowWidth')
    const storedIsAdmin = sessionStorage.getItem('heroImageIsAdmin')

    // Check if user is admin (presence of admin-tagger controller indicates admin)
    const isAdmin = document.querySelector('[data-controller*="admin-tagger"]') !== null
    const adminChanged = storedIsAdmin !== null && storedIsAdmin !== isAdmin.toString()

    // If window width changed significantly (responsive breakpoint), recalculate
    const currentWindowWidth = window.innerWidth
    const widthChanged = storedWindowWidth && Math.abs(currentWindowWidth - parseInt(storedWindowWidth)) > 50

    // Only use stored dimensions if navigating between photos with same conditions
    if (storedHeight && storedWidth && !widthChanged && !adminChanged && storedIsAdmin !== null) {
      // Use stored dimensions to prevent layout shift during navigation
      container.style.height = storedHeight
      container.style.width = storedWidth
    } else {
      // First load, window size changed, or admin status changed
      // Don't set dimensions initially - let it size naturally
      container.style.height = ''
      container.style.width = ''

      // Wait for natural sizing then store dimensions
      requestAnimationFrame(() => {
        const rect = container.getBoundingClientRect()

        if (rect.height > 0 && rect.width > 0) {
          const height = `${rect.height}px`
          const width = `${rect.width}px`

          // Store for next navigation
          sessionStorage.setItem('heroImageContainerHeight', height)
          sessionStorage.setItem('heroImageContainerWidth', width)
          sessionStorage.setItem('heroImageWindowWidth', currentWindowWidth)
          sessionStorage.setItem('heroImageIsAdmin', isAdmin.toString())

          // Only apply fixed dimensions if we're navigating (not on first load)
          if (storedIsAdmin !== null) {
            container.style.height = height
            container.style.width = width
          }
        }
      })
    }
  }

  setupResizeHandler() {
    this.resizeHandler = () => {
      // On window resize, recalculate container dimensions
      const container = this.element

      // Temporarily remove fixed dimensions to measure available space
      container.style.height = ''
      container.style.width = ''

      // Get new dimensions
      requestAnimationFrame(() => {
        const rect = container.getBoundingClientRect()

        if (rect.height > 0 && rect.width > 0) {
          const height = `${rect.height}px`
          const width = `${rect.width}px`

          // Apply new dimensions
          container.style.height = height
          container.style.width = width

          // Update stored dimensions
          sessionStorage.setItem('heroImageContainerHeight', height)
          sessionStorage.setItem('heroImageContainerWidth', width)
          sessionStorage.setItem('heroImageWindowWidth', window.innerWidth)
        }
      })
    }

    window.addEventListener('resize', this.resizeHandler)
  }

  loadFullImage() {
    if (!this.hasImageTarget || !this.fullSrcValue) return

    // Check if image is already in browser cache by creating a test image
    const testImage = new Image()
    let imageInCache = false

    // Check if already cached
    testImage.onload = () => {
      imageInCache = true
    }
    testImage.src = this.fullSrcValue

    // If image is cached, it will load synchronously
    if (imageInCache) {
      // Image is cached, load immediately without spinner
      this.imageTarget.src = this.fullSrcValue
      this.imageTarget.style.opacity = '1'
      if (this.hasSpinnerTarget) {
        this.spinnerTarget.style.display = 'none'
      }
    } else {
      // Image not cached, show spinner and load
      this.imageTarget.style.opacity = '0'
      if (this.hasSpinnerTarget) {
        this.spinnerTarget.style.display = 'flex'
        this.spinnerTarget.style.opacity = '1'
      }

      // Create a new image to preload the full version
      const fullImage = new Image()

      fullImage.onload = () => {
        // Replace the src with the full resolution image
        this.imageTarget.src = fullImage.src

        // Fade in the image
        this.imageTarget.style.opacity = '1'

        // Hide spinner if it exists
        if (this.hasSpinnerTarget) {
          this.spinnerTarget.style.opacity = '0'
          // Remove spinner after fade out
          setTimeout(() => {
            this.spinnerTarget.style.display = 'none'
          }, 300)
        }

        // Store the container dimensions now that image is loaded
        const container = this.element
        const rect = container.getBoundingClientRect()
        const isAdmin = document.querySelector('[data-controller*="admin-tagger"]') !== null

        if (rect.height > 0 && rect.width > 0) {
          sessionStorage.setItem('heroImageContainerHeight', `${rect.height}px`)
          sessionStorage.setItem('heroImageContainerWidth', `${rect.width}px`)
          sessionStorage.setItem('heroImageWindowWidth', window.innerWidth)
          sessionStorage.setItem('heroImageIsAdmin', isAdmin.toString())
        }
      }

      fullImage.onerror = () => {
        // On error, show image anyway
        this.imageTarget.style.opacity = '1'
        if (this.hasSpinnerTarget) {
          this.spinnerTarget.style.display = 'none'
        }
      }

      // Start loading the full image
      fullImage.src = this.fullSrcValue
    }
  }

  preloadAdjacentImages() {
    // Preload next image if available
    if (this.nextSrcValue) {
      const nextImage = new Image()
      nextImage.src = this.nextSrcValue
    }

    // Preload previous image if available
    if (this.prevSrcValue) {
      const prevImage = new Image()
      prevImage.src = this.prevSrcValue
    }
  }
}