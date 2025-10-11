import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "photoCard",
    "progressBarContainer",
    "progressBar",
    "checkmark",
    "zipSection",
    "downloadButton",
    "downloadButtonText",
    "statusIndicator",
    "statusText"
  ]

  static values = {
    sessionId: String,
    photoCount: Number,
    downloadUrl: String
  }

  zipId = null

  connect() {
    console.log("Download progress controller connected")
    console.log("Session ID:", this.sessionIdValue)
    console.log("Photo count:", this.photoCountValue)

    // Auto-start the download process when page loads
    this.startDownloadProcess()
  }

  disconnect() {
    // Clean up EventSource if it exists
    if (this.eventSource) {
      this.eventSource.close()
    }
  }

  async startDownloadProcess() {
    try {
      // Connect to Server-Sent Events stream
      const streamUrl = `${this.downloadUrlValue}?stream=true`
      console.log("Connecting to SSE stream:", streamUrl)

      this.eventSource = new EventSource(streamUrl)

      this.eventSource.onmessage = (event) => {
        const data = JSON.parse(event.data)
        console.log("SSE event:", data)

        switch (data.type) {
          case 'photo_start':
            this.handlePhotoStart(data)
            break
          case 'photo_progress':
            this.handlePhotoProgress(data)
            break
          case 'photo_complete':
            this.handlePhotoComplete(data)
            break
          case 'zip_start':
            this.handleZipStart(data)
            break
          case 'complete':
            this.handleComplete(data)
            break
          case 'error':
            this.handleError(data)
            break
        }
      }

      this.eventSource.onerror = (error) => {
        console.error("SSE error:", error)
        this.eventSource.close()
        this.showError("Connection lost. Please refresh and try again.")
      }

    } catch (error) {
      console.error("Failed to start download:", error)
      this.showError("Failed to start download process. Please try again.")
    }
  }

  handlePhotoStart(data) {
    console.log(`Starting photo ${data.photo_id} (${data.index + 1}/${data.total})`)

    // Show progress bar for this photo
    const progressBarContainers = this.progressBarContainerTargets.filter(
      el => el.dataset.photoId === data.photo_id.toString()
    )

    if (progressBarContainers.length > 0) {
      progressBarContainers[0].classList.remove('hidden')
    }

    // Set progress to 0% initially
    const progressBars = this.progressBarTargets.filter(
      el => el.dataset.photoId === data.photo_id.toString()
    )

    if (progressBars.length > 0) {
      progressBars[0].style.width = '0%'
    }
  }

  handlePhotoProgress(data) {
    console.log(`Photo ${data.photo_id} progress: ${data.progress}%`)

    // Update progress bar
    const progressBars = this.progressBarTargets.filter(
      el => el.dataset.photoId === data.photo_id.toString()
    )

    if (progressBars.length > 0) {
      progressBars[0].style.width = `${data.progress}%`
    }
  }

  handlePhotoComplete(data) {
    console.log(`Completed photo ${data.photo_id} (${data.index + 1}/${data.total})`)

    // Set progress to 100%
    const progressBars = this.progressBarTargets.filter(
      el => el.dataset.photoId === data.photo_id.toString()
    )

    if (progressBars.length > 0) {
      progressBars[0].style.width = '100%'
    }

    // Show checkmark
    const checkmarks = this.checkmarkTargets.filter(
      el => el.dataset.photoId === data.photo_id.toString()
    )

    if (checkmarks.length > 0) {
      checkmarks[0].classList.remove('hidden')
      checkmarks[0].classList.add('flex')
    }
  }

  handleZipStart(data) {
    console.log("Starting ZIP creation...")

    if (this.hasZipSectionTarget) {
      this.zipSectionTarget.classList.remove('hidden')
    }

    if (this.hasStatusTextTarget) {
      this.statusTextTarget.textContent = "Creating ZIP..."
    }
  }

  handleComplete(data) {
    console.log(`Download complete! ${data.photo_count} photos, ${data.size} bytes`)

    // Store the ZIP ID for download
    this.zipId = data.zip_id

    const formattedSize = this.formatBytes(data.size)

    if (this.hasDownloadButtonTarget) {
      this.downloadButtonTarget.disabled = false
      this.downloadButtonTarget.classList.remove('bg-gray-700', 'text-gray-500', 'cursor-not-allowed')
      this.downloadButtonTarget.classList.add('bg-yellow-500', 'text-black', 'hover:bg-yellow-400', 'cursor-pointer')
    }

    if (this.hasDownloadButtonTextTarget) {
      this.downloadButtonTextTarget.textContent = `Download ${data.photo_count} photos (${formattedSize})`
    }

    if (this.hasStatusTextTarget) {
      this.statusTextTarget.textContent = "Ready to download!"
    }

    if (this.hasStatusIndicatorTarget) {
      this.statusIndicatorTarget.classList.remove('bg-yellow-500', 'animate-pulse')
      this.statusIndicatorTarget.classList.add('bg-green-500')
    }

    // Hide ZIP section
    if (this.hasZipSectionTarget) {
      this.zipSectionTarget.classList.add('hidden')
    }

    // Close EventSource
    if (this.eventSource) {
      this.eventSource.close()
    }
  }

  handleError(data) {
    console.error("Server error:", data.message)
    this.showError(data.message || "An error occurred during download preparation")

    if (this.eventSource) {
      this.eventSource.close()
    }
  }


  // Handle the final download button click
  async startDownload() {
    try {
      if (!this.zipId) {
        this.showError("Download not ready. Please wait for preparation to complete.")
        return
      }

      // Download the pre-built ZIP file using the zip_id
      window.location.href = `${this.downloadUrlValue}?zip_id=${this.zipId}`
    } catch (error) {
      console.error("Failed to download:", error)
      this.showError("Failed to download file. Please try again.")
    }
  }

  showError(message) {
    if (this.hasStatusTextTarget) {
      this.statusTextTarget.textContent = message
      this.statusTextTarget.classList.add('text-red-500')
    }

    if (this.hasStatusIndicatorTarget) {
      this.statusIndicatorTarget.classList.remove('bg-yellow-500', 'bg-green-500')
      this.statusIndicatorTarget.classList.add('bg-red-500')
    }

    // Show alert
    alert(message)
  }

  formatBytes(bytes) {
    if (bytes === 0) return '0 Bytes'

    const k = 1024
    const sizes = ['Bytes', 'KB', 'MB', 'GB']
    const i = Math.floor(Math.log(bytes) / Math.log(k))

    return Math.round(bytes / Math.pow(k, i) * 100) / 100 + ' ' + sizes[i]
  }
}
