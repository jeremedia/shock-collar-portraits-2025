import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["slider", "grid", "count", "faceMode", "faceStatus"]
  
  connect() {
    // Load saved preferences
    const savedSize = localStorage.getItem('thumbnailSize')
    if (savedSize) {
      this.sliderTarget.value = savedSize
    }
    
    const savedFaceMode = localStorage.getItem('faceMode') === 'true'
    if (this.hasFaceModeTarget) {
      this.faceModeTarget.checked = savedFaceMode
    }
    
    // Set initial value and update display
    this.updateSize()
    this.updateFaceMode()
    
    // Show grids after size is set
    this.gridTargets.forEach(grid => {
      grid.classList.remove('hidden')
    })
  }
  
  updateSize() {
    const size = parseInt(this.sliderTarget.value)
    
    // Update all grids on the page
    this.gridTargets.forEach(grid => {
      // Remove all grid-cols-* classes and compact mode class
      grid.className = grid.className.replace(/grid-cols-\d+/g, '')
      grid.classList.remove('compact-thumbnails')
      
      // Add new grid-cols class
      grid.classList.add(`grid-cols-${size}`)
      
      // Add compact mode for 5+ columns
      if (size >= 5) {
        grid.classList.add('compact-thumbnails')
      }
    })
    
    // Update the count display
    this.countTarget.textContent = `(${size} per row)`
    
    // Update slider background to show position
    const min = parseInt(this.sliderTarget.min)
    const max = parseInt(this.sliderTarget.max)
    const percentage = ((size - min) / (max - min)) * 100
    
    this.sliderTarget.style.background = `linear-gradient(to right, #dc2626 0%, #dc2626 ${percentage}%, #374151 ${percentage}%, #374151 100%)`
    
    // Store preference in localStorage
    localStorage.setItem('thumbnailSize', size)
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
}