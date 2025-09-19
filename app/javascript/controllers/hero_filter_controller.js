import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["filterButton", "heroCard", "stats", "daySection", "noResults", "filterPanel", "expandButton", "expandText", "activeFiltersDisplay", "filterLogicHint"]

  connect() {
    console.log("Hero filter controller connected")
    this.activeFilters = {
      gender: new Set(),
      quality: new Set(),
      expression: new Set(),
      appearance: new Set(),
      accessory: new Set()
    }

    // Load filters from localStorage
    this.loadFiltersFromStorage()

    // Apply loaded filters if any
    if (this.hasActiveFilters()) {
      this.applyFilters()
      this.updateActiveFiltersDisplay()
      // Update button states
      this.updateButtonStates()
    } else {
      this.updateStats()
      this.saveVisibleHeroOrder()
    }
  }

  loadFiltersFromStorage() {
    const stored = localStorage.getItem('heroFilters')
    if (stored) {
      try {
        const filters = JSON.parse(stored)
        Object.keys(filters).forEach(key => {
          if (this.activeFilters[key]) {
            this.activeFilters[key] = new Set(filters[key])
          }
        })
      } catch (e) {
        console.error('Failed to load filters from storage:', e)
      }
    }
  }

  saveFiltersToStorage() {
    const filters = {}
    Object.keys(this.activeFilters).forEach(key => {
      filters[key] = Array.from(this.activeFilters[key])
    })
    localStorage.setItem('heroFilters', JSON.stringify(filters))
  }

  updateButtonStates() {
    // Update all filter buttons based on active filters
    this.filterButtonTargets.forEach(button => {
      const filterType = button.dataset.filterType
      const filterValue = button.dataset.filterValue

      if (filterType === "all") {
        if (!this.hasActiveFilters()) {
          button.classList.add("bg-yellow-500", "text-black", "border-yellow-500")
          button.classList.remove("bg-gray-800", "text-gray-400", "border-gray-700")
        } else {
          button.classList.remove("bg-yellow-500", "text-black", "border-yellow-500")
          button.classList.add("bg-gray-800", "text-gray-400", "border-gray-700")
        }
      } else if (this.activeFilters[filterType] && this.activeFilters[filterType].has(filterValue)) {
        button.classList.add("bg-yellow-500", "text-black", "border-yellow-500")
        button.classList.remove("bg-gray-800", "text-gray-400", "border-gray-700", "hover:border-red-600")
      } else {
        button.classList.remove("bg-yellow-500", "text-black", "border-yellow-500")
        button.classList.add("bg-gray-800", "text-gray-400", "border-gray-700", "hover:border-red-600")
      }
    })
  }

  toggleFilterPanel(event) {
    if (this.hasFilterPanelTarget) {
      const isHidden = this.filterPanelTarget.classList.contains("hidden")

      if (isHidden) {
        this.filterPanelTarget.classList.remove("hidden")
        this.expandTextTarget.textContent = "🔼 Hide Filters"
        this.expandButtonTarget.classList.add("bg-yellow-500", "text-black", "border-yellow-500")
        this.expandButtonTarget.classList.remove("bg-gray-800", "text-gray-400", "border-gray-700")
      } else {
        this.filterPanelTarget.classList.add("hidden")
        this.expandTextTarget.textContent = "🔽 Show Filters"
        this.expandButtonTarget.classList.remove("bg-yellow-500", "text-black", "border-yellow-500")
        this.expandButtonTarget.classList.add("bg-gray-800", "text-gray-400", "border-gray-700")
      }
    }
  }

  toggleFilter(event) {
    const button = event.currentTarget
    const filterType = button.dataset.filterType
    const filterValue = button.dataset.filterValue

    // Toggle the filter in the appropriate set
    if (this.activeFilters[filterType].has(filterValue)) {
      this.activeFilters[filterType].delete(filterValue)
      button.classList.remove("bg-yellow-500", "text-black", "border-yellow-500")
      button.classList.add("bg-gray-800", "text-gray-400", "border-gray-700", "hover:border-red-600")
    } else {
      this.activeFilters[filterType].add(filterValue)
      button.classList.add("bg-yellow-500", "text-black", "border-yellow-500")
      button.classList.remove("bg-gray-800", "text-gray-400", "border-gray-700", "hover:border-red-600")
    }

    // Update the "Show All" button state
    if (this.hasActiveFilters()) {
      this.filterButtonTargets.forEach(btn => {
        if (btn.dataset.filterType === "all") {
          btn.classList.remove("bg-yellow-500", "text-black", "border-yellow-500")
          btn.classList.add("bg-gray-800", "text-gray-400", "border-gray-700")
        }
      })
    } else {
      this.clearAllFilters()
      return
    }

    this.applyFilters()
    this.updateActiveFiltersDisplay()
    this.saveFiltersToStorage()
  }

  clearAllFilters() {
    // Clear all filter sets
    Object.keys(this.activeFilters).forEach(key => {
      this.activeFilters[key].clear()
    })

    // Clear localStorage
    localStorage.removeItem('heroFilters')

    // Reset all filter buttons
    this.filterButtonTargets.forEach(button => {
      if (button.dataset.filterType === "all") {
        button.classList.add("bg-yellow-500", "text-black", "border-yellow-500")
        button.classList.remove("bg-gray-800", "text-gray-400", "border-gray-700")
      } else {
        button.classList.remove("bg-yellow-500", "text-black", "border-yellow-500")
        button.classList.add("bg-gray-800", "text-gray-400", "border-gray-700", "hover:border-red-600")
      }
    })

    // Show all cards
    this.heroCardTargets.forEach(card => {
      card.classList.remove("hidden")
      card.classList.add("block")
    })

    // Show all day sections
    this.daySectionTargets.forEach(section => {
      section.classList.remove("hidden")
    })

    this.updateStats()
    this.updateActiveFiltersDisplay()
    this.saveVisibleHeroOrder()
  }

  hasActiveFilters() {
    return Object.values(this.activeFilters).some(set => set.size > 0)
  }

  applyFilters() {
    let visibleCount = 0
    const visibleDays = new Set()
    const visibleOrder = []

    // Hide/show cards based on filters
    this.heroCardTargets.forEach(card => {
      const isVisible = this.cardMatchesFilters(card)

      if (isVisible) {
        card.classList.remove("hidden")
        card.classList.add("block")
        visibleCount++

        // Track which days have visible cards
        const daySection = card.closest("[data-day-section]")
        if (daySection) {
          visibleDays.add(daySection)
        }

        const heroId = parseInt(card.dataset.heroId, 10)
        const heroLink = card.querySelector('a[href]')
        if (heroId && heroLink) {
          visibleOrder.push({ id: heroId, url: heroLink.href })
        }
      } else {
        card.classList.add("hidden")
        card.classList.remove("block")
      }
    })

    // Hide/show day sections based on whether they have visible cards
    this.daySectionTargets.forEach(section => {
      const hasVisibleCards = section.querySelectorAll('[data-hero-filter-target="heroCard"]:not(.hidden)').length > 0

      if (hasVisibleCards) {
        section.classList.remove("hidden")

        // Update the count in the day header
        const countElement = section.querySelector('[data-day-count]')
        if (countElement) {
          const visibleInDay = section.querySelectorAll('[data-hero-filter-target="heroCard"]:not(.hidden)').length
          countElement.textContent = `${visibleInDay} ${visibleInDay === 1 ? 'hero' : 'heroes'}`
        }
      } else {
        section.classList.add("hidden")
      }
    })

    this.updateStats(visibleCount)
    this.saveVisibleHeroOrder(visibleOrder)

    // Show/hide no results message
    if (this.hasNoResultsTarget) {
      if (visibleCount === 0) {
        this.noResultsTarget.classList.remove("hidden")
      } else {
        this.noResultsTarget.classList.add("hidden")
      }
    }
  }

  cardMatchesFilters(card) {
    // If no filters active, show everything
    if (!this.hasActiveFilters()) {
      return true
    }

    // Check gender filter
    if (this.activeFilters.gender.size > 0) {
      const gender = card.dataset.gender || "not-set"
      if (!this.activeFilters.gender.has(gender)) {
        return false
      }
    }

    // Check quality filter
    if (this.activeFilters.quality.size > 0) {
      const quality = card.dataset.quality || "ok"
      if (!this.activeFilters.quality.has(quality)) {
        return false
      }
    }

    // Check expression tags
    if (this.activeFilters.expression.size > 0) {
      const expressionTags = (card.dataset.expressionTags || "").split('|').filter(t => t.length > 0)
      const hasMatchingExpression = Array.from(this.activeFilters.expression).some(filter =>
        expressionTags.includes(filter)
      )
      if (!hasMatchingExpression) {
        return false
      }
    }

    // Check appearance tags
    if (this.activeFilters.appearance.size > 0) {
      const appearanceTags = (card.dataset.appearanceTags || "").split('|').filter(t => t.length > 0)
      const hasMatchingAppearance = Array.from(this.activeFilters.appearance).some(filter =>
        appearanceTags.includes(filter)
      )
      if (!hasMatchingAppearance) {
        return false
      }
    }

    // Check accessory tags
    if (this.activeFilters.accessory.size > 0) {
      const accessoryTags = (card.dataset.accessoryTags || "").split('|').filter(t => t.length > 0)
      const hasMatchingAccessory = Array.from(this.activeFilters.accessory).some(filter =>
        accessoryTags.includes(filter)
      )
      if (!hasMatchingAccessory) {
        return false
      }
    }

    return true
  }

  updateStats(visibleCount = null) {
    if (visibleCount === null) {
      visibleCount = this.heroCardTargets.length
    }

    // Update the stats display
    if (this.hasStatsTarget) {
      const totalCount = this.heroCardTargets.length

      if (visibleCount === totalCount) {
        this.statsTarget.textContent = `Showing all ${totalCount} heroes`
      } else {
        this.statsTarget.textContent = `Showing ${visibleCount} of ${totalCount} heroes`
      }
    }

    // Add animation when stats update
    if (this.hasStatsTarget) {
      this.statsTarget.classList.add("animate-pulse")
      setTimeout(() => {
        this.statsTarget.classList.remove("animate-pulse")
      }, 500)
    }
  }

  updateActiveFiltersDisplay() {
    if (!this.hasActiveFiltersDisplayTarget) return

    // Clear existing chips in all display targets (mobile and desktop)
    this.activeFiltersDisplayTargets.forEach(display => {
      display.innerHTML = ""
    })

    // Create chips for active filters
    const filterTypes = {
      gender: { emoji: "👤", label: "Gender" },
      quality: { emoji: "⭐", label: "Quality" },
      expression: { emoji: "😊", label: "Expression" },
      appearance: { emoji: "👁", label: "Appearance" },
      accessory: { emoji: "🎩", label: "Accessories" }
    }

    Object.keys(this.activeFilters).forEach(filterType => {
      this.activeFilters[filterType].forEach(filterValue => {
        const chip = document.createElement("span")
        chip.className = "inline-flex items-center gap-1 px-3 py-1 bg-yellow-500/20 text-yellow-500 border border-yellow-500/50 rounded-full text-xs"

        const displayValue = filterValue.split(' ').map(word =>
          word.charAt(0).toUpperCase() + word.slice(1)
        ).join(' ')

        chip.innerHTML = `
          <span>${filterTypes[filterType].emoji}</span>
          <span>${displayValue}</span>
          <button data-filter-type="${filterType}"
                  data-filter-value="${filterValue}"
                  data-action="click->hero-filter#removeFilter"
                  class="ml-1 text-red-400 hover:text-red-300">✕</button>
        `
        // Add to all display targets (mobile and desktop)
        this.activeFiltersDisplayTargets.forEach(display => {
          display.appendChild(chip.cloneNode(true))
        })
      })
    })

    // Show/hide the display and logic hint based on whether there are active filters
    if (this.hasActiveFilters()) {
      this.activeFiltersDisplayTargets.forEach(display => {
        display.classList.remove("hidden")
      })
      if (this.hasFilterLogicHintTarget) {
        // Show hint if there are filters from multiple categories
        const activeCategories = Object.keys(this.activeFilters).filter(key =>
          this.activeFilters[key].size > 0
        ).length
        if (activeCategories > 1) {
          this.filterLogicHintTarget.classList.remove("hidden")
        } else {
          this.filterLogicHintTarget.classList.add("hidden")
        }
      }
    } else {
      this.activeFiltersDisplayTargets.forEach(display => {
        display.classList.add("hidden")
      })
      if (this.hasFilterLogicHintTarget) {
        this.filterLogicHintTarget.classList.add("hidden")
      }
    }
  }

  saveVisibleHeroOrder(visibleOrder = null) {
    try {
      let order = visibleOrder
      if (!order) {
        order = []
        this.heroCardTargets.forEach(card => {
          if (card.classList.contains('hidden')) return
          const heroId = parseInt(card.dataset.heroId, 10)
          const heroLink = card.querySelector('a[href]')
          if (heroId && heroLink) {
            order.push({ id: heroId, url: heroLink.href })
          }
        })
      }

      localStorage.setItem('heroVisibleHeroes', JSON.stringify(order))
    } catch (error) {
      console.warn('Failed to save visible hero order', error)
    }
  }

  removeFilter(event) {
    const button = event.currentTarget
    const filterType = button.dataset.filterType
    const filterValue = button.dataset.filterValue

    // Remove from active filters
    this.activeFilters[filterType].delete(filterValue)

    // Update the corresponding filter button
    this.filterButtonTargets.forEach(btn => {
      if (btn.dataset.filterType === filterType && btn.dataset.filterValue === filterValue) {
        btn.classList.remove("bg-yellow-500", "text-black", "border-yellow-500")
        btn.classList.add("bg-gray-800", "text-gray-400", "border-gray-700", "hover:border-red-600")
      }
    })

    // If no filters remain, show all
    if (!this.hasActiveFilters()) {
      this.clearAllFilters()
    } else {
      this.applyFilters()
      this.updateActiveFiltersDisplay()
      this.saveFiltersToStorage()
    }
  }
}
