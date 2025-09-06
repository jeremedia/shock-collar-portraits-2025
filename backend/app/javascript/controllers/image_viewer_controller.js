import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["image", "counter", "thumbnail", "heroInput", "heroButton", "emailForm"]
  static values = { total: Number, sessionId: String }
  
  connect() {
    this.currentIndex = 0
    this.updateDisplay()
    
    // Add keyboard navigation
    document.addEventListener("keydown", this.handleKeyPress.bind(this))
  }
  
  disconnect() {
    document.removeEventListener("keydown", this.handleKeyPress.bind(this))
  }
  
  handleKeyPress(event) {
    switch(event.key) {
      case "ArrowLeft":
        this.previous()
        break
      case "ArrowRight":
        this.next()
        break
      case " ":
        event.preventDefault()
        this.heroButtonTarget.click()
        break
      case "Escape":
        window.location.href = "/"
        break
    }
  }
  
  next() {
    if (this.currentIndex < this.totalValue - 1) {
      this.currentIndex++
      this.updateDisplay()
    } else {
      this.currentIndex = 0
      this.updateDisplay()
    }
  }
  
  previous() {
    if (this.currentIndex > 0) {
      this.currentIndex--
      this.updateDisplay()
    } else {
      this.currentIndex = this.totalValue - 1
      this.updateDisplay()
    }
  }
  
  goToImage(event) {
    this.currentIndex = parseInt(event.currentTarget.dataset.index)
    this.updateDisplay()
  }
  
  updateDisplay() {
    // Hide all images
    this.imageTargets.forEach((img, index) => {
      if (index === this.currentIndex) {
        img.classList.remove("hidden")
      } else {
        img.classList.add("hidden")
      }
    })
    
    // Update counter
    this.counterTarget.textContent = `${this.currentIndex + 1} / ${this.totalValue}`
    
    // Update thumbnails
    this.thumbnailTargets.forEach((thumb, index) => {
      if (index === this.currentIndex) {
        thumb.classList.remove("border-gray-700")
        thumb.classList.add("border-yellow-500")
      } else {
        thumb.classList.remove("border-yellow-500")
        thumb.classList.add("border-gray-700")
      }
    })
    
    // Update hero input with current photo ID
    const currentImage = this.imageTargets[this.currentIndex]
    if (currentImage && this.hasHeroInputTarget) {
      const photoId = currentImage.querySelector("img").dataset.photoId
      if (photoId) {
        this.heroInputTarget.value = photoId
      }
    }
    
    // Scroll thumbnail into view
    const activeThumbnail = this.thumbnailTargets[this.currentIndex]
    if (activeThumbnail) {
      activeThumbnail.scrollIntoView({ behavior: "smooth", inline: "center", block: "nearest" })
    }
  }
  
  showEmailForm() {
    if (this.hasEmailFormTarget) {
      this.emailFormTarget.classList.remove("hidden")
    }
  }
  
  hideEmailForm() {
    if (this.hasEmailFormTarget) {
      this.emailFormTarget.classList.add("hidden")
    }
  }
}