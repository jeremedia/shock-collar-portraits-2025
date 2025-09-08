import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["day", "content", "icon", "grid"]
  static values = { day: String }
  
  connect() {
    // Get the saved open day from localStorage
    const savedDay = localStorage.getItem('openDay')
    
    // Find all day sections
    this.dayTargets.forEach(dayElement => {
      const dayName = dayElement.dataset.dayName
      const content = dayElement.querySelector('[data-day-accordion-target="content"]')
      const icon = dayElement.querySelector('[data-day-accordion-target="icon"]')
      const grid = dayElement.querySelector('[data-day-accordion-target="grid"]')
      
      if (dayName === savedDay) {
        // Open the saved day
        this.openDay(dayElement, content, icon, grid)
      } else {
        // Close all other days
        this.closeDay(content, icon)
      }
    })
    
    // If no saved day, open the first day with sessions
    if (!savedDay && this.dayTargets.length > 0) {
      const firstDay = this.dayTargets[0]
      const content = firstDay.querySelector('[data-day-accordion-target="content"]')
      const icon = firstDay.querySelector('[data-day-accordion-target="icon"]')
      const grid = firstDay.querySelector('[data-day-accordion-target="grid"]')
      this.openDay(firstDay, content, icon, grid)
    }
  }
  
  toggle(event) {
    // Find the clicked day section
    const dayElement = event.currentTarget.closest('[data-day-accordion-target="day"]')
    const dayName = dayElement.dataset.dayName
    const content = dayElement.querySelector('[data-day-accordion-target="content"]')
    const icon = dayElement.querySelector('[data-day-accordion-target="icon"]')
    const grid = dayElement.querySelector('[data-day-accordion-target="grid"]')
    
    // Check if this day is currently open
    const isOpen = content.style.display !== "none" && content.style.display !== ""
    
    // Close all days
    this.dayTargets.forEach(otherDay => {
      const otherContent = otherDay.querySelector('[data-day-accordion-target="content"]')
      const otherIcon = otherDay.querySelector('[data-day-accordion-target="icon"]')
      this.closeDay(otherContent, otherIcon)
    })
    
    // If the clicked day was closed, open it
    if (!isOpen) {
      this.openDay(dayElement, content, icon, grid)
      localStorage.setItem('openDay', dayName)
    } else {
      // Clear saved state if closing the only open day
      localStorage.removeItem('openDay')
    }
  }
  
  openDay(dayElement, content, icon, grid) {
    // Show the content
    content.style.display = "block"
    content.classList.remove('hidden')
    
    // Rotate icon
    if (icon) {
      icon.style.transform = "rotate(0deg)"
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
    content.style.display = "none"
    
    // Rotate icon
    if (icon) {
      icon.style.transform = "rotate(-90deg)"
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