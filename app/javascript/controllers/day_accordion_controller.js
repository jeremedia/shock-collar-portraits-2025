import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["day", "content", "icon", "grid"]
  static values = { day: String }

  connect() {
    // Get saved open day (only one allowed)
    const savedOpenDay = localStorage.getItem('heroOpenDay')

    // Hide all icons initially to prevent flash
    this.iconTargets.forEach(icon => {
      icon.style.visibility = 'hidden'
    })

    // Find all day sections and set initial state
    this.dayTargets.forEach(dayElement => {
      const dayName = dayElement.dataset.dayName
      const content = dayElement.querySelector('[data-day-accordion-target="content"]')
      const icon = dayElement.querySelector('[data-day-accordion-target="icon"]')
      const grid = dayElement.querySelector('[data-day-accordion-target="grid"]')

      // Only the saved day should be open
      const shouldBeOpen = dayName === savedOpenDay

      if (shouldBeOpen) {
        // Open without animation on initial load
        content.classList.remove('hidden')
        icon.textContent = '▼'
        if (grid) {
          grid.classList.remove('hidden')
          grid.dataset.loaded = 'true'
        }
      } else {
        // Ensure closed
        content.classList.add('hidden')
        icon.textContent = '▶'
      }

      // Now show the icon
      icon.style.visibility = 'visible'
    })
  }

  toggle(event) {
    // Find the clicked day section
    const dayElement = event.currentTarget.closest('[data-day-accordion-target="day"]')
    const dayName = dayElement.dataset.dayName
    const content = dayElement.querySelector('[data-day-accordion-target="content"]')
    const icon = dayElement.querySelector('[data-day-accordion-target="icon"]')
    const grid = dayElement.querySelector('[data-day-accordion-target="grid"]')

    // Check if this day is currently open
    const isOpen = !content.classList.contains('hidden')

    if (isOpen) {
      // Close this day
      this.closeDay(content, icon)
      // Clear saved state
      localStorage.removeItem('heroOpenDay')
    } else {
      // Close all other days first (only one open at a time)
      this.dayTargets.forEach(otherDay => {
        if (otherDay !== dayElement) {
          const otherContent = otherDay.querySelector('[data-day-accordion-target="content"]')
          const otherIcon = otherDay.querySelector('[data-day-accordion-target="icon"]')
          this.closeDay(otherContent, otherIcon)
        }
      })

      // Open this day
      this.openDay(dayElement, content, icon, grid)
      // Save the open day
      localStorage.setItem('heroOpenDay', dayName)
    }
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

      // Trigger lazy loading for the grid
      // The grid itself should have the lazy-images controller
      if (grid.dataset.controller && grid.dataset.controller.includes('lazy-images')) {
        const controller = this.application.getControllerForElementAndIdentifier(grid, 'lazy-images')
        if (controller) {
          // Start observing images now that the grid is visible
          controller.observeImages()
        }
      }
    }
  }

  closeDay(content, icon) {
    // Hide the content
    content.classList.add('hidden')

    // Update icon to right arrow
    if (icon) {
      icon.textContent = '▶'
    }

    // Stop observing images in the grid when closed
    const grid = content.querySelector('[data-day-accordion-target="grid"]')
    if (grid && grid.dataset.controller && grid.dataset.controller.includes('lazy-images')) {
      const controller = this.application.getControllerForElementAndIdentifier(grid, 'lazy-images')
      if (controller) {
        controller.unobserveImages()
      }
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
}