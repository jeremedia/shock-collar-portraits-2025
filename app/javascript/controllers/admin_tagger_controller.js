import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["sessionCard", "tagButton", "genderButton", "qualityButton", "panel", "mobilePanel"]
  static values = { sessionId: Number }

  connect() {
    console.log("Admin tagger controller connected")
    this.loadCurrentTags()
    this.setupSidebarToggle()
  }

  setupSidebarToggle() {
    // Only apply toggle on desktop (sm breakpoint = 640px)
    if (!this.hasPanelTarget || window.innerWidth < 640) {
      return
    }

    // Load saved state from localStorage (default to shown)
    const savedState = localStorage.getItem('adminTaggerVisible')
    const isVisible = savedState === null ? true : savedState === 'true'

    if (!isVisible) {
      this.panelTarget.classList.add('hidden')
      this.panelTarget.classList.remove('sm:block')
    }

    // Add keyboard listener for 't' key (desktop only)
    this.handleKeypress = (event) => {
      // Skip on mobile
      if (window.innerWidth < 640) return

      if (event.key === 't' || event.key === 'T') {
        // Don't toggle if user is typing in an input
        if (event.target.tagName === 'INPUT' || event.target.tagName === 'TEXTAREA') {
          return
        }
        this.toggleSidebar()
      }
    }

    document.addEventListener('keydown', this.handleKeypress)
  }

  disconnect() {
    // Clean up event listener
    if (this.handleKeypress) {
      document.removeEventListener('keydown', this.handleKeypress)
    }
  }

  toggleSidebar() {
    if (!this.hasPanelTarget || window.innerWidth < 640) return

    const isHidden = this.panelTarget.classList.contains('hidden')

    if (isHidden) {
      // Show sidebar
      this.panelTarget.classList.remove('hidden')
      this.panelTarget.classList.add('sm:block')
    } else {
      // Hide sidebar
      this.panelTarget.classList.add('hidden')
      this.panelTarget.classList.remove('sm:block')
    }

    // Save state to localStorage
    localStorage.setItem('adminTaggerVisible', !this.panelTarget.classList.contains('hidden'))
  }

  // Load current tags, gender, and quality for the session
  loadCurrentTags() {
    // Get current tags from data attributes
    const sessionCard = this.element.querySelector('[data-hero-filter-target="heroCard"]')
    if (!sessionCard) return

    const currentGender = sessionCard.dataset.gender || "not-set"
    const currentQuality = sessionCard.dataset.quality || "ok"
    const currentTags = sessionCard.dataset.tags ? sessionCard.dataset.tags.split('|').filter(t => t.length > 0) : []
    const appearanceTags = sessionCard.dataset.appearanceTags ? sessionCard.dataset.appearanceTags.split('|').filter(t => t.length > 0) : []
    const expressionTags = sessionCard.dataset.expressionTags ? sessionCard.dataset.expressionTags.split('|').filter(t => t.length > 0) : []
    const accessoryTags = sessionCard.dataset.accessoryTags ? sessionCard.dataset.accessoryTags.split('|').filter(t => t.length > 0) : []

    // Combine all tags
    const allActiveTags = [...currentTags, ...appearanceTags, ...expressionTags, ...accessoryTags]

    // Update button states
    this.tagButtonTargets.forEach(button => {
      const tag = button.dataset.tag
      if (allActiveTags.includes(tag)) {
        this.activateButton(button)
      }
    })

    // Update gender button states
    this.genderButtonTargets.forEach(button => {
      if (button.dataset.gender === currentGender) {
        this.activateButton(button)
      }
    })

    // Update quality button states
    this.qualityButtonTargets.forEach(button => {
      if (button.dataset.quality === currentQuality) {
        this.activateButton(button)
      }
    })
  }

  // Toggle a tag on/off
  async toggleTag(event) {
    const button = event.currentTarget
    const tag = button.dataset.tag
    const context = button.dataset.context || "tags"  // Will be "appearance", "expression", "accessory", or undefined for general tags
    const isActive = button.classList.contains("bg-yellow-500")

    // Toggle button state immediately for responsive feel
    if (isActive) {
      this.deactivateButton(button)
    } else {
      this.activateButton(button)
    }

    // Send update to server
    try {
      const response = await fetch(`/api/photo_sessions/${this.sessionIdValue}/tags`, {
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
        },
        body: JSON.stringify({
          tag: tag,
          context: context,
          tag_action: isActive ? 'remove' : 'add'
        })
      })

      if (!response.ok) {
        throw new Error('Failed to update tag')
      }

      const data = await response.json()

      // Update the hero card's data attributes
      this.updateCardData(data)

      // Show feedback
      this.showFeedback(isActive ? `Removed: ${tag}` : `Added: ${tag}`)

    } catch (error) {
      console.error('Error updating tag:', error)
      // Revert button state on error
      if (isActive) {
        this.activateButton(button)
      } else {
        this.deactivateButton(button)
      }
      this.showFeedback('Error updating tag', true)
    }
  }

  // Set gender (exclusive selection)
  async setGender(event) {
    const button = event.currentTarget
    const gender = button.dataset.gender

    // Deactivate all gender buttons
    this.genderButtonTargets.forEach(btn => this.deactivateButton(btn))

    // Activate clicked button
    this.activateButton(button)

    // Send update to server
    try {
      const response = await fetch(`/api/photo_sessions/${this.sessionIdValue}/gender`, {
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
        },
        body: JSON.stringify({ gender: gender })
      })

      if (!response.ok) {
        throw new Error('Failed to update gender')
      }

      const data = await response.json()

      // Update the hero card's data attributes
      this.updateCardData(data)

      // Show feedback
      this.showFeedback(`Gender set to: ${gender}`)

    } catch (error) {
      console.error('Error updating gender:', error)
      this.showFeedback('Error updating gender', true)
    }
  }

  // Set quality (exclusive selection)
  async setQuality(event) {
    const button = event.currentTarget
    const quality = button.dataset.quality

    // Deactivate all quality buttons
    this.qualityButtonTargets.forEach(btn => this.deactivateButton(btn))

    // Activate clicked button
    this.activateButton(button)

    // Send update to server
    try {
      const response = await fetch(`/api/photo_sessions/${this.sessionIdValue}/quality`, {
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
        },
        body: JSON.stringify({ quality: quality })
      })

      if (!response.ok) {
        throw new Error('Failed to update quality')
      }

      const data = await response.json()

      // Update the hero card's data attributes
      this.updateCardData(data)

      // Show feedback
      const qualityLabel = quality === 'not-ok' ? 'Not OK' : quality.charAt(0).toUpperCase() + quality.slice(1)
      this.showFeedback(`Quality set to: ${qualityLabel}`)

    } catch (error) {
      console.error('Error updating quality:', error)
      this.showFeedback('Error updating quality', true)
    }
  }

  // Clear all tags
  async clearAllTags() {
    if (!confirm('Clear all tags for this session?')) return

    try {
      const response = await fetch(`/api/photo_sessions/${this.sessionIdValue}/tags/clear`, {
        method: 'DELETE',
        headers: {
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
        }
      })

      if (!response.ok) {
        throw new Error('Failed to clear tags')
      }

      // Deactivate all tag buttons
      this.tagButtonTargets.forEach(button => this.deactivateButton(button))

      const data = await response.json()
      this.updateCardData(data)

      this.showFeedback('All tags cleared')

    } catch (error) {
      console.error('Error clearing tags:', error)
      this.showFeedback('Error clearing tags', true)
    }
  }

  // UI Helper Methods
  activateButton(button) {
    button.classList.add("bg-yellow-500", "text-black", "border-yellow-500")
    button.classList.remove("bg-gray-800", "text-gray-400", "border-gray-700")
  }

  deactivateButton(button) {
    button.classList.remove("bg-yellow-500", "text-black", "border-yellow-500")
    button.classList.add("bg-gray-800", "text-gray-400", "border-gray-700")
  }

  updateCardData(data) {
    const sessionCard = this.element.querySelector('[data-hero-filter-target="heroCard"]')
    if (!sessionCard) return

    // Update data attributes
    sessionCard.dataset.gender = data.gender || "not-set"
    sessionCard.dataset.quality = data.quality || "ok"
    sessionCard.dataset.tags = data.all_tags.join('|')
    sessionCard.dataset.appearanceTags = data.appearance_tags.join('|')
    sessionCard.dataset.expressionTags = data.expression_tags.join('|')
    sessionCard.dataset.accessoryTags = data.accessory_tags.join('|')
  }

  showFeedback(message, isError = false) {
    // Create or update feedback element
    let feedback = this.element.querySelector('.tag-feedback')
    if (!feedback) {
      feedback = document.createElement('div')
      feedback.className = 'tag-feedback fixed top-20 right-4 px-4 py-2 rounded-lg text-white z-50 transition-opacity duration-300'
      document.body.appendChild(feedback)
    }

    feedback.textContent = message
    feedback.className = `tag-feedback fixed top-20 right-4 px-4 py-2 rounded-lg text-white z-50 transition-opacity duration-300 ${isError ? 'bg-red-600' : 'bg-green-600'}`
    feedback.style.opacity = '1'

    // Hide after 2 seconds
    setTimeout(() => {
      feedback.style.opacity = '0'
      setTimeout(() => feedback.remove(), 300)
    }, 2000)
  }
}