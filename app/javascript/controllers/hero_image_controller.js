import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["image", "spinner", "portraitToggle"]
  static values = {
    fullSrc: String,
    nextSrc: String,
    prevSrc: String,
    portraitSrc: String,
    nextPortraitSrc: String,
    prevPortraitSrc: String
  }

  connect() {
    this.setupContainerDimensions()
    this.showPortrait = this.initialPortraitPreference()
    // console.log('[hero-image] has portrait toggle target?', this.hasPortraitToggleTarget)
    this.syncPortraitToggle()
    // console.log('[hero-image] connect showPortrait?', this.showPortrait, 'portraitSrc?', this.portraitSrcValue)

    // Debug: Log all preload values
    // console.log('[hero-image] Preload values:', {
    //   nextSrc: this.nextSrcValue,
    //   nextPortraitSrc: this.nextPortraitSrcValue,
    //   prevSrc: this.prevSrcValue,
    //   prevPortraitSrc: this.prevPortraitSrcValue
    // })

    // Start preloading adjacent images immediately, even before loading current image
    // This ensures they're ready when user navigates
    this.preloadAdjacentImages()

    this.loadFullImage()
    this.setupResizeHandler()
    this.setupPortraitCropListener()
  }

  disconnect() {
    // Clean up resize handler
    if (this.resizeHandler) {
      window.removeEventListener('resize', this.resizeHandler)
    }
    // Clean up portrait crop listener
    if (this.portraitCropHandler) {
      document.removeEventListener('portrait-crop:updated', this.portraitCropHandler)
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
    if (!this.hasImageTarget) return

    const src = this.activeImageSrc()
    if (!src) {
      console.warn('[hero-image] no source available, showPortrait?', this.showPortrait)
      return
    }

    // console.log('[hero-image] will change to', src)
    this.dispatch('will-change', { detail: { src, portrait: this.showPortrait } })

    // Create a test image to check if it's cached
    const testImage = new Image()

    // Set up promise-based cache checking
    const checkCache = new Promise((resolve) => {
      testImage.onload = () => resolve(true)
      testImage.onerror = () => resolve(false)
      // Set a timeout - if image doesn't load within 10ms, it's not cached
      setTimeout(() => resolve(false), 10)
    })

    testImage.src = src

    checkCache.then(isCached => {
      if (isCached && testImage.complete && testImage.naturalWidth > 0) {
        // Image is cached, load immediately without spinner
        this.imageTarget.src = src
        this.imageTarget.style.transition = 'opacity 0.2s ease-in'
        this.imageTarget.style.opacity = '1'
        if (this.hasSpinnerTarget) {
          this.spinnerTarget.style.display = 'none'
        }
        // console.log('[hero-image] did change instantly (cached)', src)
        this.dispatch('did-change', { detail: { src, portrait: this.showPortrait } })
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
          this.imageTarget.style.transition = 'opacity 0.3s ease-in'
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

          // console.log('[hero-image] did change after load', src)
          this.dispatch('did-change', { detail: { src, portrait: this.showPortrait } })
        }

        fullImage.onerror = () => {
          // On error, show image anyway
          this.imageTarget.style.opacity = '1'
          if (this.hasSpinnerTarget) {
            this.spinnerTarget.style.display = 'none'
          }
          console.warn('[hero-image] load error, using fallback', src)
          this.dispatch('did-change', { detail: { src, portrait: this.showPortrait } })
        }

        // Start loading the full image
        fullImage.src = src
      }
    })
  }

  preloadAdjacentImages() {
    // Always preload BOTH standard and portrait versions for adjacent images
    // This ensures instant loading regardless of which mode the user chooses

    // Preload next image (both versions)
    if (this.nextSrcValue) {
      const nextImage = new Image()
      nextImage.src = this.nextSrcValue
      // console.log('[hero-image] Preloading next image:', this.nextSrcValue)
    }

    if (this.nextPortraitSrcValue) {
      const nextPortraitImage = new Image()
      nextPortraitImage.src = this.nextPortraitSrcValue
      // console.log('[hero-image] Preloading next portrait:', this.nextPortraitSrcValue)
    }

    // Preload previous image (both versions)
    if (this.prevSrcValue) {
      const prevImage = new Image()
      prevImage.src = this.prevSrcValue
      // console.log('[hero-image] Preloading prev image:', this.prevSrcValue)
    }

    if (this.prevPortraitSrcValue) {
      const prevPortraitImage = new Image()
      prevPortraitImage.src = this.prevPortraitSrcValue
      // console.log('[hero-image] Preloading prev portrait:', this.prevPortraitSrcValue)
    }

    // Also preload the alternate version of current image
    // If showing portrait, preload standard; if showing standard, preload portrait
    if (this.showPortrait && this.fullSrcValue) {
      // Currently showing portrait, so preload the standard version
      const standardImage = new Image()
      standardImage.src = this.fullSrcValue
      // console.log('[hero-image] Preloading current standard (for toggle):', this.fullSrcValue)
    } else if (!this.showPortrait && this.portraitSrcValue) {
      // Currently showing standard, so preload the portrait version
      const portraitImage = new Image()
      portraitImage.src = this.portraitSrcValue
      // console.log('[hero-image] Preloading current portrait (for toggle):', this.portraitSrcValue)
    }
  }

  togglePortraitMode(event) {
    const enabled = event.currentTarget.checked
    // console.log('[hero-image] togglePortraitMode', enabled, 'event type', event.type, 'hasPortrait?', this.hasPortraitVariant())
    if (enabled && !this.hasPortraitVariant()) {
      this.showPortrait = false
      this.persistPortraitPreference()
      this.syncPortraitToggle()
      return
    }

    this.showPortrait = enabled
    this.persistPortraitPreference()
    this.syncPortraitToggle()
    // console.log('[hero-image] mode set to', this.showPortrait ? 'portrait' : 'full')
    this.loadFullImage()
  }

  activeImageSrc() {
    if (this.showPortrait && this.hasPortraitVariant()) {
      console.log('[hero-image] activeImageSrc returning portrait:', this.portraitSrcValue)
      return this.portraitSrcValue
    }
    console.log('[hero-image] activeImageSrc returning full:', this.fullSrcValue)
    return this.fullSrcValue
  }

  hasPortraitVariant() {
    const available = this.hasPortraitSrcValue && this.portraitSrcValue && this.portraitSrcValue.length > 0
    if (!available) {
      // console.log('[hero-image] portrait variant missing')
    }
    return available
  }

  initialPortraitPreference() {
    if (!this.hasPortraitVariant()) return false

    try {
      const savedMode = localStorage.getItem('heroPortraitMode')
      // Default to portrait mode if no preference saved
      return savedMode === null ? true : savedMode === 'portrait'
    } catch (e) {
      return true // Default to portrait on error
    }
  }

  persistPortraitPreference() {
    try {
      if (this.showPortrait) {
        localStorage.setItem('heroPortraitMode', 'portrait')
      } else {
        localStorage.setItem('heroPortraitMode', 'full')
      }
    } catch (e) {
      // Ignore storage errors
    }
  }

  syncPortraitToggle() {
    const hasVariant = this.hasPortraitVariant()
    if (this.hasPortraitToggleTarget) {
      const enabled = this.showPortrait && hasVariant
      this.portraitToggleTarget.checked = enabled
      this.portraitToggleTarget.disabled = !hasVariant
      // console.log('[hero-image] sync toggle => checked:', this.portraitToggleTarget.checked, 'disabled:', this.portraitToggleTarget.disabled)
    } else {
      // console.log('[hero-image] no portrait toggle target found during sync')
    }

    if (hasVariant) {
      this.element.setAttribute('data-hero-image-mode', this.showPortrait ? 'portrait' : 'full')
    } else {
      this.element.removeAttribute('data-hero-image-mode')
    }

    const cropHost = this.element.closest('[data-controller~="portrait-crop"]')
    if (cropHost) {
      if (hasVariant) {
        cropHost.setAttribute('data-hero-image-mode', this.showPortrait ? 'portrait' : 'full')
      } else {
        cropHost.removeAttribute('data-hero-image-mode')
      }
    }
  }

  setupPortraitCropListener() {
    this.portraitCropHandler = (event) => {
      // When portrait crop is updated, force refresh the current image to clear browser cache
      console.log('[hero-image] received portrait-crop:updated event', event.detail)
      this.refreshCurrentImage()
      // Also clear any cached portrait/full URLs by adding cache buster to stored values
      this.bustUrlCache()
    }
    // Listen on document to catch bubbled events from anywhere
    document.addEventListener('portrait-crop:updated', this.portraitCropHandler)
  }

  refreshCurrentImage() {
    if (!this.hasImageTarget) return

    const currentSrc = this.imageTarget.src
    if (!currentSrc) return

    // Add cache-busting timestamp to force browser to reload the image
    const url = new URL(currentSrc)
    url.searchParams.set('t', Date.now())

    // Preload the new URL to avoid flickering
    const preloadImg = new Image()
    preloadImg.onload = () => {
      // Update the displayed image once the new version is loaded
      this.imageTarget.src = url.toString()
      console.log('[hero-image] refreshed image with cache-buster')
    }
    preloadImg.src = url.toString()
  }

  bustUrlCache() {
    // Add cache-busting timestamp to all image URLs that might show portrait crops
    const timestamp = Date.now()

    // Update stored URL values with cache buster
    if (this.fullSrcValue) {
      this.fullSrcValue = this.addCacheBuster(this.fullSrcValue, timestamp)
    }
    if (this.portraitSrcValue) {
      this.portraitSrcValue = this.addCacheBuster(this.portraitSrcValue, timestamp)
    }
    if (this.nextSrcValue) {
      this.nextSrcValue = this.addCacheBuster(this.nextSrcValue, timestamp)
    }
    if (this.nextPortraitSrcValue) {
      this.nextPortraitSrcValue = this.addCacheBuster(this.nextPortraitSrcValue, timestamp)
    }
    if (this.prevSrcValue) {
      this.prevSrcValue = this.addCacheBuster(this.prevSrcValue, timestamp)
    }
    if (this.prevPortraitSrcValue) {
      this.prevPortraitSrcValue = this.addCacheBuster(this.prevPortraitSrcValue, timestamp)
    }

    console.log('[hero-image] busted URL cache for all image variants')
  }

  addCacheBuster(url, timestamp) {
    if (!url) return url

    try {
      const urlObj = new URL(url)
      urlObj.searchParams.set('t', timestamp)
      return urlObj.toString()
    } catch (e) {
      // If URL parsing fails, append as query string
      const separator = url.includes('?') ? '&' : '?'
      return `${url}${separator}t=${timestamp}`
    }
  }
}
