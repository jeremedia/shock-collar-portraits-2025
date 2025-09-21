import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["prevLink", "nextLink"]
  static values = {
    currentId: Number,
    defaultPrevUrl: String,
    defaultNextUrl: String
  }

  connect() {
    this.updateNavigation()
    this.isNavigating = false

    // Initialize history state for current page
    this.initializeHistoryState()

    // Handle browser back/forward buttons
    this.handlePopstate = this.onPopstate.bind(this)
    window.addEventListener('popstate', this.handlePopstate)

    // Handle keyboard navigation
    this.handleKeydown = this.onKeydown.bind(this)
    document.addEventListener('keydown', this.handleKeydown)
  }

  initializeHistoryState() {
    // Create initial state from current page data
    const heroController = document.querySelector('[data-controller="hero-image"]')
    if (!heroController) return

    const state = {
      photo: {
        id: this.currentIdValue,
        full_url: heroController.dataset.heroImageFullSrcValue,
        portrait_url: heroController.dataset.heroImagePortraitSrcValue
      },
      navigation: {
        prev_url: this.defaultPrevUrlValue,
        next_url: this.defaultNextUrlValue,
        prev_full_url: heroController.dataset.heroImagePrevSrcValue,
        next_full_url: heroController.dataset.heroImageNextSrcValue,
        prev_portrait_url: heroController.dataset.heroImagePrevPortraitSrcValue,
        next_portrait_url: heroController.dataset.heroImageNextPortraitSrcValue
      }
    }

    // Replace current state
    history.replaceState(state, '', window.location.href)
  }

  disconnect() {
    window.removeEventListener('popstate', this.handlePopstate)
    document.removeEventListener('keydown', this.handleKeydown)
  }

  onKeydown(event) {
    // Don't navigate if user is typing in an input
    if (event.target.tagName === 'INPUT' || event.target.tagName === 'TEXTAREA') return

    // Prevent double navigation
    if (this.isNavigating) return

    if (event.key === 'ArrowLeft' && this.defaultPrevUrlValue) {
      event.preventDefault()
      this.navigateToHero(this.defaultPrevUrlValue)
    } else if (event.key === 'ArrowRight' && this.defaultNextUrlValue) {
      event.preventDefault()
      this.navigateToHero(this.defaultNextUrlValue)
    }
  }

  onPopstate(event) {
    if (event.state && event.state.photo) {
      // Update page content from history state
      this.updatePageContent(event.state)
    }
  }

  updateNavigation() {
    let order

    try {
      order = JSON.parse(localStorage.getItem('heroVisibleHeroes') || '[]')
    } catch (error) {
      console.warn('[hero-navigation] failed to parse stored hero list', error)
      order = []
    }

    if (!Array.isArray(order) || order.length === 0) {
      this.applyDefaults()
      return
    }

    const index = order.findIndex(item => item && Number(item.id) === this.currentIdValue)
    if (index === -1) {
      this.applyDefaults()
      return
    }

    const prev = index > 0 ? order[index - 1] : null
    const next = index < order.length - 1 ? order[index + 1] : null

    this.applyLink(this.prevLinkTarget, prev, this.defaultPrevUrlValue, 'prev')
    this.applyLink(this.nextLinkTarget, next, this.defaultNextUrlValue, 'next')

    this.updateSwipeNavigation(prev, next)
  }

  applyDefaults() {
    this.applyLink(this.prevLinkTarget, null, this.defaultPrevUrlValue, 'prev')
    this.applyLink(this.nextLinkTarget, null, this.defaultNextUrlValue, 'next')
    this.updateSwipeNavigation(null, null)
  }

  applyLink(linkElement, target, fallbackUrl, direction) {
    const hasTarget = target && target.url

    if (hasTarget) {
      linkElement.href = target.url
      linkElement.classList.remove('nav-link--disabled')
      linkElement.classList.add('nav-link--active')
      linkElement.removeAttribute('aria-disabled')
      linkElement.removeAttribute('tabindex')
    } else if (fallbackUrl) {
      linkElement.href = fallbackUrl
      linkElement.classList.remove('nav-link--disabled')
      linkElement.classList.add('nav-link--active')
      linkElement.removeAttribute('aria-disabled')
      linkElement.removeAttribute('tabindex')
    } else {
      linkElement.href = '#'
      linkElement.classList.remove('nav-link--active')
      linkElement.classList.add('nav-link--disabled')
      linkElement.setAttribute('aria-disabled', 'true')
      linkElement.setAttribute('tabindex', '-1')
    }
  }

  updateSwipeNavigation(prev, next) {
    const container = document.querySelector('[data-controller~="swipe-navigation"]')
    if (!container) return

    const prevUrl = (prev && prev.url) || this.defaultPrevUrlValue || ''
    const nextUrl = (next && next.url) || this.defaultNextUrlValue || ''

    container.dataset.swipeNavigationPrevUrlValue = prevUrl
    container.dataset.swipeNavigationNextUrlValue = nextUrl
  }

  handleClick(event) {
    event.preventDefault()

    const link = event.currentTarget
    if (link.classList.contains('nav-link--disabled') || link.getAttribute('aria-disabled') === 'true' || link.getAttribute('href') === '#') {
      return
    }

    // Prevent double navigation
    if (this.isNavigating) return
    this.isNavigating = true

    const url = link.href
    this.navigateToHero(url)
  }

  async navigateToHero(url) {
    // Immediately fade out current image
    this.fadeOutCurrentImage()

    try {
      // Fetch JSON data for the new hero
      const response = await fetch(url, {
        headers: {
          'Accept': 'application/json'
        }
      })

      if (!response.ok) throw new Error('Failed to fetch hero data')

      const data = await response.json()

      // Update browser URL without page reload
      history.pushState(data, '', url)

      // Update the page content
      this.updatePageContent(data)

    } catch (error) {
      console.error('Navigation failed:', error)
      // Fallback to normal navigation
      window.location.href = url
    } finally {
      this.isNavigating = false
    }
  }

  updatePageContent(data) {
    // Update current ID for next navigation
    this.currentIdValue = data.photo.id

    // Update hero image controller data attributes
    const heroController = document.querySelector('[data-controller="hero-image"]')
    if (heroController) {
      heroController.dataset.heroImageFullSrcValue = data.photo.full_url || ''
      heroController.dataset.heroImagePortraitSrcValue = data.photo.portrait_url || ''
      heroController.dataset.heroImageNextSrcValue = data.navigation.next_full_url || ''
      heroController.dataset.heroImageNextPortraitSrcValue = data.navigation.next_portrait_url || ''
      heroController.dataset.heroImagePrevSrcValue = data.navigation.prev_full_url || ''
      heroController.dataset.heroImagePrevPortraitSrcValue = data.navigation.prev_portrait_url || ''

      // Trigger image load
      const imageController = this.application.getControllerForElementAndIdentifier(heroController, 'hero-image')
      if (imageController) {
        imageController.preloadAdjacentImages()
        imageController.loadFullImage()
      }
    }

    // Update navigation links
    this.defaultPrevUrlValue = data.navigation.prev_url || ''
    this.defaultNextUrlValue = data.navigation.next_url || ''
    this.updateNavigation()

    // Update metadata displays
    this.updateMetadata(data)
  }

  updateMetadata(data) {
    // Update session link and number
    const sessionLink = document.querySelector('a[href*="/session/"]')
    if (sessionLink) {
      sessionLink.href = `/session/${data.session.id}`

      // Update session number in both mobile and desktop views
      const sessionNumber = String(data.session.session_number).padStart(3, '0')
      const spans = sessionLink.querySelectorAll('span')
      spans.forEach(span => {
        if (span.textContent.includes('#')) {
          if (span.classList.contains('sm:hidden')) {
            span.textContent = `#${sessionNumber}`
          } else {
            span.textContent = `Session #${sessionNumber}`
          }
        }
      })
    }

    // Update metadata more precisely by targeting specific elements
    const navBar = document.querySelector('[data-controller="hero-navigation"]')
    if (navBar && data.session) {
      // The metadata is in the flex container after the session link
      const metadataContainer = sessionLink?.nextElementSibling
      if (metadataContainer) {
        // Get the three metadata sections
        const metaSections = metadataContainer.querySelectorAll('.flex.items-center.gap-1')

        // First section: Date (day_name only on desktop, date always)
        if (metaSections[0]) {
          const dateSpan = metaSections[0].querySelector('span')
          if (dateSpan) {
            // Check if there's already a desktop-only span
            let desktopSpan = dateSpan.querySelector('.hidden.sm\\:inline')

            if (!desktopSpan) {
              // Create the structure if it doesn't exist
              desktopSpan = document.createElement('span')
              desktopSpan.className = 'hidden sm:inline'
              dateSpan.insertBefore(desktopSpan, dateSpan.firstChild)
            }

            // Update desktop span with day name
            desktopSpan.textContent = data.session.day_name ? `${data.session.day_name}, ` : ''

            // Update the remaining text content (the date)
            // Remove all text nodes and add the new one
            const textNodes = Array.from(dateSpan.childNodes).filter(node => node.nodeType === Node.TEXT_NODE)
            textNodes.forEach(node => node.remove())
            dateSpan.appendChild(document.createTextNode(data.session.date))
          }
        }

        // Second section: Time
        if (metaSections[1]) {
          const timeSpan = metaSections[1].querySelector('span')
          if (timeSpan) {
            timeSpan.textContent = data.session.time
          }
        }

        // Third section: Photo position
        if (metaSections[2]) {
          const positionSpan = metaSections[2].querySelector('span')
          if (positionSpan) {
            positionSpan.textContent = `#${data.photo.position} of ${data.session.photo_count}`
          }
        }
      }
    }

    // Update page title
    if (data.session) {
      const titleParts = ['Hero']
      if (data.session.day_name) {
        titleParts.push(data.session.day_name.charAt(0).toUpperCase() + data.session.day_name.slice(1))
      }
      titleParts.push(`Session ${String(data.session.session_number).padStart(3, '0')}`)
      document.title = titleParts.join(' - ')
    }
  }

  fadeOutCurrentImage() {
    const heroImage = document.querySelector('[data-controller="hero-image"] img')
    if (heroImage) {
      heroImage.style.transition = 'opacity 0.1s ease-out'
      heroImage.style.opacity = '0'
    }
  }
}
