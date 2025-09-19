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

    // Trigger initial image loading for visible thumbnails
    // This ensures images load even if lazy-images controller connected before elements were visible
    setTimeout(() => {
      this.triggerVisibleImageLoading()
    }, 200)
  }

  triggerVisibleImageLoading() {
    // Determine which thumbnails should be visible
    const faceMode = this.hasFaceModeTarget && this.faceModeTarget.checked
    const selector = faceMode ? '.face-thumbnail' : '.regular-thumbnail'
    const visibleContainers = document.querySelectorAll(selector)

    visibleContainers.forEach(container => {
      const img = container.querySelector('img[data-src]')
      if (img && img.dataset.src) {
        // Try to find and use the lazy-images controller
        const lazyElement = container.closest('[data-controller*="lazy-images"]')
        if (lazyElement) {
          const lazyController = this.application.getControllerForElementAndIdentifier(lazyElement, 'lazy-images')
          if (lazyController && lazyController.loadImage) {
            lazyController.loadImage(img)
          } else {
            // Fallback: create an observer for this image
            const observer = new IntersectionObserver((entries) => {
              entries.forEach(entry => {
                if (entry.isIntersecting) {
                  const targetImg = entry.target
                  if (targetImg.dataset.src) {
                    targetImg.src = targetImg.dataset.src
                    targetImg.removeAttribute('data-src')
                    targetImg.style.opacity = '1'
                    observer.unobserve(targetImg)
                  }
                }
              })
            }, { rootMargin: '100px', threshold: 0.1 })
            observer.observe(img)
          }
        } else {
          // Direct fallback: just load the image
          img.src = img.dataset.src
          img.removeAttribute('data-src')
          img.style.opacity = '1'
        }
      }
    })
  }
  
  updateSize() {
    const size = parseInt(this.sliderTarget.value)

    // Check if mobile
    const isMobile = window.innerWidth < 640 // sm breakpoint

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

    // Trigger lazy loading for newly visible images
    // Wait for CSS transition to complete
    setTimeout(() => {
      this.triggerVisibleImageLoading()
    }, 100) // Small delay to ensure CSS has applied

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

        if (targetSrc && img.src !== targetSrc) {
          img.src = targetSrc
        }

        const card = img.closest('[data-hero-filter-target="heroCard"]')
        if (card) {
          card.classList.remove('hero-variant-thumb', 'hero-variant-face', 'hero-variant-portrait', 'hero-card--portrait-missing')
          card.classList.add(`hero-variant-${variant}`)
          if (variant === 'portrait' && !portraitSrc) {
            card.classList.add('hero-card--portrait-missing')
          }
          img.dataset.heroVariant = variant
        }
      })
    })

    localStorage.setItem('heroThumbnailVariant', variant)
  }
}
