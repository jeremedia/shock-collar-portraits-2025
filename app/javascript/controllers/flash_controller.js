import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    // Auto-dismiss after 10 seconds
    this.timeout = setTimeout(() => {
      this.dismiss()
    }, 10000)
  }

  disconnect() {
    // Clear timeout if element is removed before timeout
    if (this.timeout) {
      clearTimeout(this.timeout)
    }
  }

  dismiss() {
    // Fade out animation
    this.element.style.transition = "opacity 0.3s ease-out"
    this.element.style.opacity = "0"

    // Remove element after animation completes
    setTimeout(() => {
      this.element.remove()
    }, 300)
  }
}