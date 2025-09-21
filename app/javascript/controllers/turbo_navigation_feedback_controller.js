import { Controller } from "@hotwired/stimulus"

// This controller provides immediate visual feedback when navigating between hero pages
export default class extends Controller {
  connect() {
    // Listen for Turbo navigation events
    document.addEventListener('turbo:before-visit', this.handleBeforeVisit.bind(this))
    document.addEventListener('turbo:before-fetch-request', this.handleBeforeFetch.bind(this))
  }

  disconnect() {
    document.removeEventListener('turbo:before-visit', this.handleBeforeVisit)
    document.removeEventListener('turbo:before-fetch-request', this.handleBeforeFetch)
  }

  handleBeforeVisit(event) {
    // Only provide feedback if we're on a hero page navigating to another hero page
    const currentPath = window.location.pathname
    const newPath = new URL(event.detail.url).pathname

    if (currentPath.includes('/heroes/') && newPath.includes('/heroes/')) {
      this.fadeOutCurrentImage()
      this.showLoadingState()
    }
  }

  handleBeforeFetch(event) {
    // Additional feedback for fetch requests
    const currentPath = window.location.pathname
    if (currentPath.includes('/heroes/')) {
      this.fadeOutCurrentImage()
    }
  }

  fadeOutCurrentImage() {
    // Find the hero image element and fade it out immediately
    const heroImage = document.querySelector('[data-controller="hero-image"] img')
    if (heroImage && heroImage.style.opacity !== '0') {
      heroImage.style.transition = 'opacity 0.15s ease-out'
      heroImage.style.opacity = '0'
    }
  }

  showLoadingState() {
    // Find the spinner element and show it
    const spinner = document.querySelector('[data-hero-image-target="spinner"]')
    if (spinner) {
      spinner.style.display = 'flex'
      spinner.style.opacity = '1'
    }
  }
}