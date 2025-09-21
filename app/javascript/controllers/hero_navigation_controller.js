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
    const link = event.currentTarget
    if (link.classList.contains('nav-link--disabled') || link.getAttribute('aria-disabled') === 'true' || link.getAttribute('href') === '#') {
      event.preventDefault()
      return
    }

    // Provide immediate visual feedback
    this.fadeOutCurrentImage()
    this.showLoadingState()
  }

  fadeOutCurrentImage() {
    // Find the hero image element and fade it out immediately
    const heroImage = document.querySelector('[data-controller="hero-image"] img')
    if (heroImage) {
      heroImage.style.transition = 'opacity 0.2s ease-out'
      heroImage.style.opacity = '0'
    }
  }

  showLoadingState() {
    // Find or create a spinner element
    const spinner = document.querySelector('[data-hero-image-target="spinner"]')
    if (spinner) {
      spinner.style.display = 'flex'
      spinner.style.opacity = '1'
    }
  }
}
