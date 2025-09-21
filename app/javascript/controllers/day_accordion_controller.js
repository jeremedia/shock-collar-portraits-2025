import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["day", "content", "icon", "grid"]
  static values = { day: String }
  
  connect() {
    // Get saved states for each day
    const savedStates = this.getSavedStates()

    // Find all day sections and apply saved state (default to collapsed)
    this.dayTargets.forEach(dayElement => {
      const dayName = dayElement.dataset.dayName
      const content = dayElement.querySelector('[data-day-accordion-target="content"]')
      const icon = dayElement.querySelector('[data-day-accordion-target="icon"]')
      const grid = dayElement.querySelector('[data-day-accordion-target="grid"]')

      // Check saved state - default to collapsed (false)
      const isExpanded = savedStates[dayName] === true

      if (isExpanded) {
        this.openDay(dayElement, content, icon, grid)
      } else {
        this.closeDay(content, icon)
      }
    })
  }
  
  toggle(event) {
    // Find the clicked day section
    const dayElement = event.currentTarget.closest('[data-day-accordion-target="day"]')
    const dayName = dayElement.dataset.dayName
    const content = dayElement.querySelector('[data-day-accordion-target="content"]')
    const icon = dayElement.querySelector('[data-day-accordion-target="icon"]')
    const grid = dayElement.querySelector('[data-day-accordion-target="grid"]')

    // Check if this day is currently open (using hidden class)
    const isOpen = !content.classList.contains('hidden')

    // Toggle this day's state
    if (isOpen) {
      this.closeDay(content, icon)
    } else {
      this.openDay(dayElement, content, icon, grid)
    }

    // Save the new state
    this.saveState(dayName, !isOpen)
  }
  
  openDay(dayElement, content, icon, grid) {
    // Show the content
    content.classList.remove('hidden')

    // Update icon to down arrow
    if (icon) {
      icon.textContent = '▼'
    }

    // Make grid visible (sessions are pre-rendered server-side)
    if (grid) {
      grid.classList.remove('hidden')
      // Mark as loaded since content is pre-rendered
      grid.dataset.loaded = 'true'
    }
  }

  closeDay(content, icon) {
    // Hide the content
    content.classList.add('hidden')

    // Update icon to right arrow
    if (icon) {
      icon.textContent = '▶'
    }
  }
  
  loadSessions(dayElement, grid) {
    const dayName = dayElement.dataset.dayName
    
    // Mark as loading
    grid.innerHTML = '<div class="col-span-full text-center text-yellow-500 py-8">Loading sessions...</div>'
    
    // Fetch the sessions for this day
    fetch(`/gallery/day_sessions?day=${dayName}`, {
      headers: {
        'Accept': 'text/html',
        'X-Requested-With': 'XMLHttpRequest'
      }
    })
    .then(response => response.text())
    .then(html => {
      grid.innerHTML = html
      grid.dataset.loaded = 'true'
      
      // Trigger any Stimulus controllers in the loaded content
      const event = new CustomEvent('turbo:load', { bubbles: true })
      grid.dispatchEvent(event)
    })
    .catch(error => {
      console.error('Error loading sessions:', error)
      grid.innerHTML = '<div class="col-span-full text-center text-red-500 py-8">Error loading sessions</div>'
    })
  }

  saveState(dayName, isExpanded) {
    const savedStates = this.getSavedStates()
    savedStates[dayName] = isExpanded
    localStorage.setItem('herosDayAccordionStates', JSON.stringify(savedStates))
  }

  getSavedStates() {
    try {
      return JSON.parse(localStorage.getItem('herosDayAccordionStates')) || {}
    } catch {
      return {}
    }
  }
}