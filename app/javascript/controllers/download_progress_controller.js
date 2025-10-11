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

  connect() {
    console.log("Download progress controller connected")
    console.log("Session ID:", this.sessionIdValue)
    console.log("Photo count:", this.photoCountValue)

    // Auto-start the download process when page loads
    this.startDownloadProcess()
  }

  async startDownloadProcess() {
    try {
      // Start the download_all process which will stream updates
      const response = await fetch(this.downloadUrlValue, {
        method: 'GET',
        headers: {
          'Accept': 'text/vnd.turbo-stream.html',
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
        }
      })

      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`)
      }

      // The response will be turbo stream updates that will be processed automatically
      // We just need to handle the final download redirect
      console.log("Download process started, watching for Turbo Stream updates...")

    } catch (error) {
      console.error("Failed to start download:", error)
      this.showError("Failed to start download process. Please try again.")
    }
  }

  // Called by Turbo Stream to show progress for a specific photo
  updatePhotoProgress(event) {
    const photoId = event.detail.photoId
    const progress = event.detail.progress

    console.log(`Photo ${photoId} progress: ${progress}%`)

    // Find the progress bar for this photo
    const progressBarContainers = this.progressBarContainerTargets.filter(
      el => el.dataset.photoId === photoId.toString()
    )
    const progressBars = this.progressBarTargets.filter(
      el => el.dataset.photoId === photoId.toString()
    )

    if (progressBarContainers.length > 0) {
      progressBarContainers[0].classList.remove('hidden')
    }

    if (progressBars.length > 0) {
      progressBars[0].style.width = `${progress}%`
    }
  }

  // Called by Turbo Stream when a photo download completes
  markPhotoComplete(event) {
    const photoId = event.detail.photoId

    console.log(`Photo ${photoId} complete!`)

    // Find and show the checkmark for this photo
    const checkmarks = this.checkmarkTargets.filter(
      el => el.dataset.photoId === photoId.toString()
    )

    if (checkmarks.length > 0) {
      checkmarks[0].classList.remove('hidden')
      checkmarks[0].classList.add('flex')
    }
  }

  // Called by Turbo Stream when ZIP creation starts
  showZipProgress() {
    console.log("Showing ZIP progress...")

    if (this.hasZipSectionTarget) {
      this.zipSectionTarget.classList.remove('hidden')
    }

    if (this.hasStatusTextTarget) {
      this.statusTextTarget.textContent = "Creating ZIP..."
    }
  }

  // Called by Turbo Stream when download is ready
  enableDownload(event) {
    const size = event.detail.size
    const count = event.detail.count

    console.log(`Download ready! ${count} photos, ${size} bytes`)

    // Format size
    const formattedSize = this.formatBytes(size)

    if (this.hasDownloadButtonTarget) {
      this.downloadButtonTarget.disabled = false
      this.downloadButtonTarget.classList.remove('bg-gray-700', 'text-gray-500', 'cursor-not-allowed')
      this.downloadButtonTarget.classList.add('bg-yellow-500', 'text-black', 'hover:bg-yellow-400', 'cursor-pointer')
    }

    if (this.hasDownloadButtonTextTarget) {
      this.downloadButtonTextTarget.textContent = `Download ${count} photos (${formattedSize})`
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
  }

  // Handle the final download button click
  async startDownload() {
    try {
      // Download the file normally (without Turbo Stream)
      window.location.href = this.downloadUrlValue
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
