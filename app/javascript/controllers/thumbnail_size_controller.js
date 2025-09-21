import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["slider", "grid", "count", "faceMode", "faceStatus", "variant"]
  
  connect() {
    // Load saved preferences
    const savedSize = localStorage.getItem('thumbnailSize')
    if (savedSize) {
      this.sliderTarget.value = savedSize
    }

    if (this.hasFaceModeTarget) {
      const savedFaceMode = localStorage.getItem('faceMode') === 'true'
      this.faceModeTarget.checked = savedFaceMode
    }

    if (this.hasVariantTarget) {
      const savedVariant = localStorage.getItem('heroThumbnailVariant') || 'face'
      this.variantTarget.value = savedVariant
    }

    // Set initial value and update display
    this.updateSize()
    if (this.hasFaceModeTarget) {
      this.updateFaceMode()
    }
    if (this.hasVariantTarget) {
      this.updateVariant()
    }

    // Show grids after size is set
    this.gridTargets.forEach(grid => {
      grid.classList.remove('hidden')
    })

    // Force load visible images on initial page load
    // This handles cases where lazy-images controller doesn't trigger properly
    setTimeout(() => {
      const faceMode = this.hasFaceModeTarget && this.faceModeTarget.checked
      const containerClass = faceMode ? '.face-thumbnail' : '.regular-thumbnail'
      const containers = document.querySelectorAll(containerClass)

      containers.forEach(container => {
        const img = container.querySelector('img[data-src]')
        if (img && img.dataset.src && !img.src.includes(img.dataset.src)) {
          // Load the image
          img.src = img.dataset.src
          img.removeAttribute('data-src')
          img.classList.add('loaded')
          img.style.opacity = '1'
        }
      })
    }, 100) // Small delay to ensure everything is initialized
  }
  
  updateSize() {
    let size = parseInt(this.sliderTarget.value)

    // Check if mobile
    const isMobile = window.innerWidth < 640 // sm breakpoint

    // On mobile, snap to 3 discrete positions
    if (isMobile) {
      const min = parseInt(this.sliderTarget.min)
      const max = parseInt(this.sliderTarget.max)
      const range = max - min

      // Map slider range to 3 positions
      if (size <= min + range * 0.33) {
        size = min  // Snap to minimum (1 column)
      } else if (size <= min + range * 0.67) {
        size = Math.round(min + range * 0.5)  // Snap to middle (2 columns)
      } else {
        size = max  // Snap to maximum (3 columns)
      }

      // Update slider to snapped position
      this.sliderTarget.value = size
    }

    // Update all grids on the page
    this.gridTargets.forEach(grid => {
      // Remove all grid-cols-* and sm:grid-cols-* classes and compact mode class
      grid.className = grid.className.replace(/(?:sm:)?grid-cols-\d+/g, '')
      grid.classList.remove('compact-thumbnails')

      if (isMobile) {
        // On mobile, map slider values to 1-3 columns
        let mobileColumns
        if (size <= 3) {
          mobileColumns = 1  // Small size = 1 column
        } else if (size <= 5) {
          mobileColumns = 2  // Medium size = 2 columns
        } else {
          mobileColumns = 3  // Large size = 3 columns
        }
        grid.classList.add(`grid-cols-${mobileColumns}`)

        // For desktop fallback
        grid.classList.add(`sm:grid-cols-${size}`)
      } else {
        // Desktop uses slider value directly
        grid.classList.add('grid-cols-3')  // Default mobile
        grid.classList.add(`sm:grid-cols-${size}`)  // Desktop from slider
      }

      // Add compact mode for 5+ columns (desktop only)
      if (!isMobile && size >= 5) {
        grid.classList.add('compact-thumbnails')
      }
    })

    // Update the count display based on actual columns shown
    if (isMobile) {
      let mobileColumns
      if (size <= 3) {
        mobileColumns = 1
      } else if (size <= 5) {
        mobileColumns = 2
      } else {
        mobileColumns = 3
      }
      this.countTarget.textContent = `(${mobileColumns} per row)`
    } else {
      this.countTarget.textContent = `(${size} per row)`
    }

    // Update slider background to show position
    const min = parseInt(this.sliderTarget.min)
    const max = parseInt(this.sliderTarget.max)
    const percentage = ((size - min) / (max - min)) * 100

    this.sliderTarget.style.background = `linear-gradient(to right, #dc2626 0%, #dc2626 ${percentage}%, #374151 ${percentage}%, #374151 100%)`
    
    // Store preference in localStorage
    localStorage.setItem('thumbnailSize', size)

    if (this.hasVariantTarget) {
      this.updateVariant()
    }
  }
  
  toggleFaceMode() {
    this.updateFaceMode()
  }
  
  updateFaceMode() {
    if (!this.hasFaceModeTarget) return

    const faceMode = this.faceModeTarget.checked

    // Update all session cards to show face crops or regular thumbnails
    this.gridTargets.forEach(grid => {
      if (faceMode) {
        grid.classList.add('face-mode')
      } else {
        grid.classList.remove('face-mode')
      }
    })

    // After toggling face mode, we need to load images that are now visible
    // The lazy-images controller doesn't handle display:none -> display:block changes
    setTimeout(() => {
      // Find the container type that should now be visible
      const containerClass = faceMode ? '.face-thumbnail' : '.regular-thumbnail'
      const containers = document.querySelectorAll(containerClass)

      containers.forEach(container => {
        // Find unloaded images (those with data-src attribute)
        const img = container.querySelector('img[data-src]')
        if (img && img.dataset.src) {
          // Simply load the image directly
          img.src = img.dataset.src
          img.removeAttribute('data-src')
          img.classList.add('loaded')
          img.style.transition = 'opacity 0.3s ease-in-out'
          img.style.opacity = '1'
        }
      })
    }, 50) // Small delay to ensure CSS has applied

    // Update status text
    if (this.hasFaceStatusTarget) {
      if (faceMode) {
        // Count how many sessions have face data
        const sessionCards = document.querySelectorAll('[data-has-faces]')
        const withFaces = Array.from(sessionCards).filter(card => card.dataset.hasFaces === 'true').length
        this.faceStatusTarget.textContent = withFaces > 0 ? `(${withFaces} with faces)` : '(processing...)'
      } else {
        this.faceStatusTarget.textContent = ''
      }
    }

    // Store preference
    localStorage.setItem('faceMode', faceMode)
  }

  updateVariant() {
    if (!this.hasVariantTarget) return

    const selected = this.variantTarget.value
    const allowed = ['thumb', 'face', 'portrait']
    const variant = allowed.includes(selected) ? selected : 'face'

    this.gridTargets.forEach(grid => {
      const images = grid.querySelectorAll('img[data-hero-thumb-src]')

      images.forEach(img => {
        const thumbSrc = img.dataset.heroThumbSrc
        const faceSrc = img.dataset.heroFaceSrc
        const portraitSrc = img.dataset.heroPortraitSrc

        let targetSrc
        let appliedVariant = variant

        switch (variant) {
          case 'thumb':
            targetSrc = thumbSrc || faceSrc || portraitSrc
            break
          case 'portrait':
            targetSrc = portraitSrc || faceSrc || thumbSrc
            break
          case 'face':
          default:
            targetSrc = faceSrc || thumbSrc || portraitSrc
            break
        }

        const currentSrc = img.dataset.heroCurrentSrc
        const needsLoad = targetSrc && targetSrc !== currentSrc

        if (needsLoad && targetSrc) {
          this.notifyLoading(img)
          img.style.opacity = '0'
          if (img.dataset.src !== undefined) {
            img.dataset.src = targetSrc
            if (img.classList.contains('loaded')) {
              this.swapImageSource(img, targetSrc)
            }
          } else if (img.src !== targetSrc) {
            this.swapImageSource(img, targetSrc)
          }
        } else if (targetSrc) {
          img.style.opacity = '1'
        }

        if (targetSrc === thumbSrc && thumbSrc) {
          appliedVariant = 'thumb'
        } else if (targetSrc === faceSrc && faceSrc) {
          appliedVariant = 'face'
        } else if (targetSrc === portraitSrc && portraitSrc) {
          appliedVariant = 'portrait'
        }

        img.dataset.heroVariant = appliedVariant

        const card = img.closest('[data-hero-filter-target="heroCard"]') || img.closest('[data-thumbnail-card]')
        if (card) {
          card.classList.remove('hero-variant-thumb', 'hero-variant-face', 'hero-variant-portrait', 'hero-card--portrait-missing')
          card.classList.add(`hero-variant-${appliedVariant}`)
          if (variant === 'portrait' && !portraitSrc) {
            card.classList.add('hero-card--portrait-missing')
          }
        }
      })
    })

    localStorage.setItem('heroThumbnailVariant', variant)
  }

  swapImageSource(img, targetSrc) {
    const loader = new Image()
    loader.onload = () => {
      img.src = targetSrc
      img.style.opacity = '1'
      img.classList.add('loaded')
      img.dataset.heroCurrentSrc = targetSrc
      this.notifyLoaded(img)
    }
    loader.onerror = () => {
      img.src = targetSrc
      this.notifyLoaded(img)
    }
    loader.src = targetSrc
  }

  notifyLoading(img) {
    img.dispatchEvent(new CustomEvent('thumbnail:loading', { bubbles: true }))
  }

  notifyLoaded(img) {
    img.dispatchEvent(new CustomEvent('thumbnail:loaded', { bubbles: true }))
  }
}
