import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "rate", "totalPending", "completion", "queues", "progressBar", 
    "lastUpdated", "indicator"
  ]
  static values = { url: String }

  connect() {
    this.startAutoRefresh()
  }

  disconnect() {
    this.stopAutoRefresh()
  }

  startAutoRefresh() {
    this.refreshInterval = setInterval(() => {
      this.updateStats()
    }, 5000) // Update every 5 seconds
    
    // Initial load
    this.updateStats()
  }

  stopAutoRefresh() {
    if (this.refreshInterval) {
      clearInterval(this.refreshInterval)
    }
  }

  async updateStats() {
    try {
      // Flash indicator
      this.indicatorTarget.classList.remove("bg-green-500")
      this.indicatorTarget.classList.add("bg-yellow-500")
      
      const response = await fetch(this.urlValue)
      const data = await response.json()
      
      // Update overall stats
      if (this.hasRateTarget) {
        this.rateTarget.textContent = `${data.rate} jobs/min`
      }
      
      if (this.hasTotalPendingTarget) {
        const totalPending = Object.values(data.queues).reduce((sum, queue) => sum + queue.pending, 0)
        this.totalPendingTarget.textContent = totalPending
      }
      
      if (this.hasCompletionTarget && data.completion) {
        const completionTime = new Date(data.completion)
        const now = new Date()
        const diffMs = completionTime - now
        const diffMins = Math.round(diffMs / (1000 * 60))
        
        if (diffMins > 0) {
          if (diffMins < 60) {
            this.completionTarget.textContent = `${diffMins} minutes`
          } else {
            const hours = Math.round(diffMins / 60)
            this.completionTarget.textContent = `${hours} hours`
          }
        } else {
          this.completionTarget.textContent = "Complete!"
        }
      }
      
      // Update progress bars and queue stats
      this.progressBarTargets.forEach(bar => {
        const queueName = bar.dataset.queue
        const queueData = data.queues[queueName]
        
        if (queueData) {
          // Animate progress bar
          bar.style.width = `${queueData.progress}%`
          
          // Update stats text
          const pendingEl = document.querySelector(`[data-queue="${queueName}-pending"]`)
          const completedEl = document.querySelector(`[data-queue="${queueName}-completed"]`)
          const rateEl = document.querySelector(`[data-queue="${queueName}-rate"]`)
          const totalEl = document.querySelector(`[data-queue="${queueName}-total"]`)
          
          if (pendingEl) pendingEl.textContent = queueData.pending
          if (completedEl) completedEl.textContent = queueData.completed
          if (rateEl) rateEl.textContent = queueData.rate_per_hour
          if (totalEl) totalEl.textContent = queueData.total
        }
      })
      
      // Update timestamp
      if (this.hasLastUpdatedTarget) {
        const now = new Date()
        this.lastUpdatedTarget.textContent = `Last updated: ${now.toLocaleTimeString()}`
      }
      
      // Success indicator
      this.indicatorTarget.classList.remove("bg-yellow-500", "bg-red-500")
      this.indicatorTarget.classList.add("bg-green-500")
      
    } catch (error) {
      console.error("Failed to update queue status:", error)
      
      // Error indicator
      this.indicatorTarget.classList.remove("bg-green-500", "bg-yellow-500")
      this.indicatorTarget.classList.add("bg-red-500")
    }
  }

  // Manual refresh button
  refresh() {
    this.updateStats()
  }
}