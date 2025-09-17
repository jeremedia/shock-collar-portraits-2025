import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

export default class extends Controller {
  static values = {
    nextUrl: String,
    prevUrl: String,
    indexUrl: String
  }

  connect() {
    // Only enable on touch devices
    if (!('ontouchstart' in window)) {
      return
    }

    this.touchStartX = 0
    this.touchStartY = 0
    this.touchEndX = 0
    this.touchEndY = 0
    this.minSwipeDistance = 50 // Minimum distance for a swipe
    this.verticalThreshold = 100 // Minimum vertical distance for down swipe

    // Bind touch event handlers
    this.handleTouchStart = this.onTouchStart.bind(this)
    this.handleTouchMove = this.onTouchMove.bind(this)
    this.handleTouchEnd = this.onTouchEnd.bind(this)

    // Add event listeners
    this.element.addEventListener('touchstart', this.handleTouchStart, { passive: true })
    this.element.addEventListener('touchmove', this.handleTouchMove, { passive: false })
    this.element.addEventListener('touchend', this.handleTouchEnd, { passive: true })

    // Add visual feedback element
    this.createSwipeFeedback()
  }

  disconnect() {
    // Clean up event listeners
    if (this.handleTouchStart) {
      this.element.removeEventListener('touchstart', this.handleTouchStart)
      this.element.removeEventListener('touchmove', this.handleTouchMove)
      this.element.removeEventListener('touchend', this.handleTouchEnd)
    }

    // Remove feedback element
    if (this.swipeFeedback) {
      this.swipeFeedback.remove()
    }
  }

  createSwipeFeedback() {
    // Create a visual feedback element for swipe actions
    this.swipeFeedback = document.createElement('div')
    this.swipeFeedback.className = 'fixed top-1/2 left-1/2 transform -translate-x-1/2 -translate-y-1/2 pointer-events-none z-50 opacity-0 transition-opacity duration-200'
    this.swipeFeedback.innerHTML = `
      <div class="bg-black/80 text-yellow-500 px-6 py-3 rounded-full text-lg font-bold">
        <span class="swipe-text"></span>
      </div>
    `
    document.body.appendChild(this.swipeFeedback)
  }

  showFeedback(text, icon = '') {
    const textElement = this.swipeFeedback.querySelector('.swipe-text')
    textElement.textContent = `${icon} ${text}`
    this.swipeFeedback.style.opacity = '1'

    setTimeout(() => {
      this.swipeFeedback.style.opacity = '0'
    }, 500)
  }

  onTouchStart(e) {
    this.touchStartX = e.touches[0].clientX
    this.touchStartY = e.touches[0].clientY
    this.isSwiping = false
  }

  onTouchMove(e) {
    if (!this.touchStartX || !this.touchStartY) {
      return
    }

    const currentX = e.touches[0].clientX
    const currentY = e.touches[0].clientY
    const diffX = this.touchStartX - currentX
    const diffY = this.touchStartY - currentY

    // If we're swiping horizontally, prevent vertical scrolling
    if (Math.abs(diffX) > Math.abs(diffY) && Math.abs(diffX) > 10) {
      e.preventDefault()
      this.isSwiping = true
    }

    // If we're swiping down from near the top, prevent default
    if (diffY < -30 && this.touchStartY < 200) {
      e.preventDefault()
      this.isSwiping = true
    }
  }

  onTouchEnd(e) {
    if (!this.touchStartX || !this.touchStartY) {
      return
    }

    this.touchEndX = e.changedTouches[0].clientX
    this.touchEndY = e.changedTouches[0].clientY

    this.handleSwipe()

    // Reset values
    this.touchStartX = 0
    this.touchStartY = 0
    this.touchEndX = 0
    this.touchEndY = 0
  }

  handleSwipe() {
    const diffX = this.touchStartX - this.touchEndX
    const diffY = this.touchStartY - this.touchEndY
    const absDiffX = Math.abs(diffX)
    const absDiffY = Math.abs(diffY)

    // Horizontal swipes (left/right for navigation)
    if (absDiffX > absDiffY && absDiffX > this.minSwipeDistance) {
      if (diffX > 0) {
        // Swipe left - go to next hero
        this.navigateNext()
      } else {
        // Swipe right - go to previous hero
        this.navigatePrev()
      }
    }
    // Vertical swipe down (to return to index)
    else if (diffY < -this.verticalThreshold && this.touchStartY < 200) {
      // Swipe down from top area - go back to index
      this.navigateToIndex()
    }
  }

  navigateNext() {
    if (this.nextUrlValue) {
      this.showFeedback('Next', '→')
      setTimeout(() => {
        Turbo.visit(this.nextUrlValue)
      }, 200)
    } else {
      this.showFeedback('Last Hero', '⚡')
    }
  }

  navigatePrev() {
    if (this.prevUrlValue) {
      this.showFeedback('Previous', '←')
      setTimeout(() => {
        Turbo.visit(this.prevUrlValue)
      }, 200)
    } else {
      this.showFeedback('First Hero', '⚡')
    }
  }

  navigateToIndex() {
    if (this.indexUrlValue) {
      this.showFeedback('All Heroes', '↑')
      setTimeout(() => {
        Turbo.visit(this.indexUrlValue)
      }, 200)
    }
  }
}