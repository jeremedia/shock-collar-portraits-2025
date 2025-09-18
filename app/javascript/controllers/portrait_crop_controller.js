import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "imageWrapper",
    "overlay",
    "window",
    "handleTop",
    "handleBottom",
    "status",
    "saveButton"
  ]

  static values = {
    photoId: Number
  }

  connect() {
    this.aspectRatio = 9 / 16
    this.rect = null
    this.imageWidth = null
    this.imageHeight = null
    this.isDirty = false
    this.frameCache = null
    this.pointerListenersAttached = false
    this.autoSaveTimer = null
    this.overlayVisible = false
    console.log('[portrait-crop] connect photo', this.photoIdValue)

    if (!this.hasImageWrapperTarget || !this.photoIdValue) {
      return
    }

    this.imageElement = this.imageWrapperTarget.querySelector('[data-hero-image-target="image"]')
    if (!this.imageElement) {
      console.warn('[portrait-crop] no hero image target found')
      return
    }

    this.handleImageLoad = this.onImageLoad.bind(this)
    this.imageElement.addEventListener('load', this.handleImageLoad)

    this.handleResize = this.renderOverlay.bind(this)
    window.addEventListener('resize', this.handleResize)

    this.handleHeroImageWillChange = this.onHeroImageWillChange.bind(this)
    this.handleHeroImageDidChange = this.onHeroImageDidChange.bind(this)
    this.element.addEventListener('hero-image:will-change', this.handleHeroImageWillChange)
    this.element.addEventListener('hero-image:did-change', this.handleHeroImageDidChange)

    if (this.imageElement.complete && this.imageElement.naturalWidth > 0) {
      this.onImageLoad()
    }

    this.attachInteractionListeners()
  }

  disconnect() {
    window.removeEventListener('resize', this.handleResize)

    if (this.imageElement && this.handleImageLoad) {
      this.imageElement.removeEventListener('load', this.handleImageLoad)
    }

    if (this.pointerListenersAttached && this.hasWindowTarget) {
      this.windowTarget.removeEventListener('pointerdown', this.startMove)
      if (this.hasHandleTopTarget) {
        this.handleTopTarget.removeEventListener('pointerdown', this.startResizeTop)
      }
      if (this.hasHandleBottomTarget) {
        this.handleBottomTarget.removeEventListener('pointerdown', this.startResizeBottom)
      }
      this.pointerListenersAttached = false
    }

    this.element.removeEventListener('hero-image:will-change', this.handleHeroImageWillChange)
    this.element.removeEventListener('hero-image:did-change', this.handleHeroImageDidChange)
    this.cancelAutoSave()
    this.removeGlobalListeners()
  }

  attachInteractionListeners() {
    if (!this.hasWindowTarget) {
      return
    }

    this.startMove = this.startMove.bind(this)
    this.startResizeTop = this.startResizeTop.bind(this)
    this.startResizeBottom = this.startResizeBottom.bind(this)
    this.pointerMove = this.pointerMove.bind(this)
    this.endInteraction = this.endInteraction.bind(this)

    this.windowTarget.addEventListener('pointerdown', this.startMove)
    if (this.hasHandleTopTarget) {
      this.handleTopTarget.addEventListener('pointerdown', this.startResizeTop)
    }
    if (this.hasHandleBottomTarget) {
      this.handleBottomTarget.addEventListener('pointerdown', this.startResizeBottom)
    }
    this.pointerListenersAttached = true
  }

  onImageLoad() {
    this.imageNaturalWidth = this.imageElement.naturalWidth
    this.imageNaturalHeight = this.imageElement.naturalHeight
    console.log('[portrait-crop] image load natural', this.imageNaturalWidth, this.imageNaturalHeight)

    if (!this.imageNaturalWidth || !this.imageNaturalHeight) {
      return
    }

    this.fetchCrop()
  }

  async fetchCrop() {
    this.setStatus('Loading…')
    this.fadeOverlayOut()
    console.log('[portrait-crop] fetching crop')

    try {
      const response = await fetch(`/api/photos/${this.photoIdValue}/portrait_crop`, {
        headers: { 'Accept': 'application/json' }
      })

      if (!response.ok) {
        throw new Error(`HTTP ${response.status}`)
      }

      const data = await response.json()
      this.imageWidth = data.image_width || this.imageNaturalWidth
      this.imageHeight = data.image_height || this.imageNaturalHeight
      this.rect = this.coerceRect(data.rect) || this.buildFallbackRect()
      console.log('[portrait-crop] fetched rect', this.rect)
      this.isDirty = false
      this.renderOverlay()
      this.showDetails()
      this.fadeOverlayIn()
    } catch (error) {
      console.error('Failed to load portrait crop', error)
      this.setStatus('Unable to load portrait crop', true)
      this.fadeOverlayIn()
    }
  }

  buildFallbackRect() {
    if (!this.imageWidth || !this.imageHeight) {
      return null
    }

    let height = this.imageHeight
    let width = height * this.aspectRatio

    if (width > this.imageWidth) {
      width = this.imageWidth
      height = width / this.aspectRatio
    }

    const left = (this.imageWidth - width) / 2
    const top = (this.imageHeight - height) / 2

    return {
      left: Math.round(left),
      top: Math.round(top),
      width: Math.round(width),
      height: Math.round(height),
      source: 'fallback'
    }
  }

  renderOverlay() {
    if (!this.rect || !this.imageWidth || !this.hasOverlayTarget || !this.hasWindowTarget) {
      return
    }

    if (this.viewerInPortraitMode()) {
      console.log('[portrait-crop] viewer in portrait mode – overlay hidden')
      this.fadeOverlayOut()
      return
    }

    const frame = this.calculateFrame()
    if (!frame) {
      console.log('[portrait-crop] no frame for overlay')
      return
    }

    this.overlayTarget.classList.remove('hidden')
    this.overlayTarget.style.left = `${frame.left}px`
    this.overlayTarget.style.top = `${frame.top}px`
    this.overlayTarget.style.width = `${frame.width}px`
    this.overlayTarget.style.height = `${frame.height}px`

    this.windowTarget.style.transform = `translate(${this.rect.left * frame.scaleX}px, ${this.rect.top * frame.scaleY}px)`
    this.windowTarget.style.width = `${this.rect.width * frame.scaleX}px`
    this.windowTarget.style.height = `${this.rect.height * frame.scaleY}px`

    this.frameCache = frame
    if (!this.overlayTarget.classList.contains('portrait-crop-overlay--hidden')) {
      this.overlayVisible = true
    }
    this.showDetails()
  }

  calculateFrame() {
    if (!this.imageElement) {
      return null
    }

    const containerRect = this.imageWrapperTarget.getBoundingClientRect()
    const imageRect = this.imageElement.getBoundingClientRect()

    if (imageRect.width === 0 || imageRect.height === 0) {
      return null
    }

    return {
      left: imageRect.left - containerRect.left,
      top: imageRect.top - containerRect.top,
      width: imageRect.width,
      height: imageRect.height,
      scaleX: imageRect.width / this.imageWidth,
      scaleY: imageRect.height / this.imageHeight
    }
  }

  ensureFrame() {
    if (this.viewerInPortraitMode()) {
      return null
    }
    const frame = this.calculateFrame()
    if (frame) {
      this.frameCache = frame
    }
    return this.frameCache
  }

  startMove(event) {
    const topHandle = this.hasHandleTopTarget ? this.handleTopTarget : null
    const bottomHandle = this.hasHandleBottomTarget ? this.handleBottomTarget : null

    if (event.target === topHandle || event.target === bottomHandle) {
      return
    }

    event.preventDefault()
    this.beginInteraction(event, 'move')
  }

  startResizeTop(event) {
    event.preventDefault()
    event.stopPropagation()
    this.beginInteraction(event, 'resize-top')
  }

  startResizeBottom(event) {
    event.preventDefault()
    event.stopPropagation()
    this.beginInteraction(event, 'resize-bottom')
  }

  beginInteraction(event, mode) {
    if (!this.rect) {
      return
    }

    const frame = this.ensureFrame()
    if (!frame) {
      return
    }

    this.cancelAutoSave()

    this.interaction = {
      mode,
      pointerId: event.pointerId,
      startClientX: event.clientX,
      startClientY: event.clientY,
      startRect: { ...this.rect },
      centerX: this.rect.left + this.rect.width / 2
    }

    event.target.setPointerCapture(event.pointerId)

    window.addEventListener('pointermove', this.pointerMove)
    window.addEventListener('pointerup', this.endInteraction)
  }

  pointerMove(event) {
    if (!this.interaction) {
      return
    }

    const frame = this.ensureFrame()
    if (!frame) {
      return
    }

    const deltaX = (event.clientX - this.interaction.startClientX) / frame.scaleX
    const deltaY = (event.clientY - this.interaction.startClientY) / frame.scaleY

    let nextRect = { ...this.interaction.startRect }

    if (this.interaction.mode === 'move') {
      nextRect.left = this.clamp(nextRect.left + deltaX, 0, this.imageWidth - nextRect.width)
      nextRect.top = this.clamp(nextRect.top + deltaY, 0, this.imageHeight - nextRect.height)
    } else if (this.interaction.mode === 'resize-top') {
      const bottom = this.interaction.startRect.top + this.interaction.startRect.height
      const newTop = this.clamp(
        this.interaction.startRect.top + deltaY,
        0,
        bottom - this.minHeight()
      )
      let newHeight = bottom - newTop
      let newWidth = newHeight * this.aspectRatio

      if (newWidth > this.imageWidth) {
        newWidth = this.imageWidth
        newHeight = newWidth / this.aspectRatio
      }

      const newLeft = this.clamp(
        this.interaction.centerX - newWidth / 2,
        0,
        this.imageWidth - newWidth
      )

      nextRect = {
        left: newLeft,
        top: bottom - newHeight,
        width: newWidth,
        height: newHeight
      }
    } else if (this.interaction.mode === 'resize-bottom') {
      const newBottom = this.clamp(
        this.interaction.startRect.top + this.interaction.startRect.height + deltaY,
        this.interaction.startRect.top + this.minHeight(),
        this.imageHeight
      )
      let newHeight = newBottom - this.interaction.startRect.top
      let newWidth = newHeight * this.aspectRatio

      if (newWidth > this.imageWidth) {
        newWidth = this.imageWidth
        newHeight = newWidth / this.aspectRatio
      }

      const newLeft = this.clamp(
        this.interaction.centerX - newWidth / 2,
        0,
        this.imageWidth - newWidth
      )

      nextRect = {
        left: newLeft,
        top: this.interaction.startRect.top,
        width: newWidth,
        height: newHeight
      }
    }

    this.rect = this.normalizeRect(nextRect)
    this.renderOverlay()
    this.markDirty()
  }

  endInteraction(event) {
    if (this.interaction && event.target.releasePointerCapture) {
      try {
        event.target.releasePointerCapture(this.interaction.pointerId)
      } catch (e) {
        // ignore if capture already released
      }
    }

    this.interaction = null
    this.removeGlobalListeners()
    this.scheduleAutoSave()
  }

  removeGlobalListeners() {
    window.removeEventListener('pointermove', this.pointerMove)
    window.removeEventListener('pointerup', this.endInteraction)
  }

  minHeight() {
    if (!this.imageHeight) {
      return 50
    }
    const tenPercent = this.imageHeight * 0.1
    return Math.min(this.imageHeight, Math.max(tenPercent, 50))
  }

  clamp(value, min, max) {
    if (Number.isNaN(value)) {
      return min
    }
    return Math.max(min, Math.min(max, value))
  }

  normalizeRect(rect) {
    const safeLeft = this.clamp(rect.left, 0, this.imageWidth - rect.width)
    const safeTop = this.clamp(rect.top, 0, this.imageHeight - rect.height)
    const width = Math.min(rect.width, this.imageWidth)
    const height = Math.min(rect.height, this.imageHeight)

    return {
      left: safeLeft,
      top: safeTop,
      width,
      height,
      source: rect.source || 'manual'
    }
  }

  markDirty() {
    if (!this.isDirty) {
      this.isDirty = true
      this.updateSaveState()
    }
    this.showDetails()
  }

  updateSaveState() {
    if (this.hasSaveButtonTarget) {
      this.saveButtonTargets.forEach((button) => {
        button.disabled = !this.isDirty
      })
    }
  }

  async save(event) {
    if (event) {
      event.preventDefault()
    }

    await this.submitRect()
  }

  async reset(event) {
    if (event) {
      event.preventDefault()
    }

    this.setStatus('Resetting…')
    this.cancelAutoSave()

    try {
      const response = await fetch(`/api/photos/${this.photoIdValue}/portrait_crop`, {
        method: 'DELETE',
        headers: {
          'Accept': 'application/json',
          'X-CSRF-Token': this.csrfToken()
        }
      })

      if (!response.ok) {
        throw new Error(`HTTP ${response.status}`)
      }

      const data = await response.json()
      this.rect = this.coerceRect(data.rect) || this.buildFallbackRect()
      this.isDirty = false
      this.updateSaveState()
      this.renderOverlay()
      this.showDetails('Reset to default')
      this.fadeOverlayIn()
    } catch (error) {
      console.error('Failed to reset portrait crop', error)
      this.setStatus('Reset failed', true)
      this.fadeOverlayIn()
    }
  }

  serializedRect() {
    return {
      left: Math.round(this.rect.left),
      top: Math.round(this.rect.top),
      width: Math.round(this.rect.width),
      height: Math.round(this.rect.height),
      image_width: Math.round(this.imageWidth || this.imageNaturalWidth || 0),
      image_height: Math.round(this.imageHeight || this.imageNaturalHeight || 0)
    }
  }

  coerceRect(raw) {
    if (!raw) {
      return null
    }

    const left = Number(raw.left)
    const top = Number(raw.top)
    const width = Number(raw.width)
    const height = Number(raw.height)

    if ([left, top, width, height].some((value) => Number.isNaN(value))) {
      return null
    }

    return {
      left,
      top,
      width,
      height,
      source: raw.source
    }
  }

  showDetails(prefix = null) {
    if (!this.hasStatusTarget || !this.rect) {
      return
    }

    const width = Math.round(this.rect.width)
    const height = Math.round(this.rect.height)
    const left = Math.round(this.rect.left)
    const top = Math.round(this.rect.top)
    const parts = []

    if (prefix) {
      parts.push(prefix)
    }

    parts.push(`${width}×${height}`)
    parts.push(`x:${left} y:${top}`)
    parts.push(this.isDirty ? 'Unsaved changes' : 'Saved')

    this.statusTargets.forEach((element) => {
      element.textContent = parts.join(' • ')
      element.classList.toggle('text-yellow-400', this.isDirty)
      element.classList.toggle('text-emerald-400', !this.isDirty)
      element.classList.remove('text-red-400')
    })
  }

  setStatus(message, isError = false) {
    if (!this.hasStatusTarget) {
      return
    }

    this.statusTargets.forEach((element) => {
      element.textContent = message
      element.classList.toggle('text-red-400', isError)
      if (!isError) {
        element.classList.remove('text-yellow-400', 'text-emerald-400')
      }
    })
  }

  scheduleAutoSave(delay = 400) {
    if (!this.isDirty) {
      return
    }
    if (this.viewerInPortraitMode()) {
      this.cancelAutoSave()
      console.log('[portrait-crop] autosave skipped (portrait mode)')
      return
    }
    this.cancelAutoSave()
    this.autoSaveTimer = setTimeout(() => {
      this.submitRect(true)
    }, delay)
  }

  cancelAutoSave() {
    if (this.autoSaveTimer) {
      clearTimeout(this.autoSaveTimer)
      this.autoSaveTimer = null
    }
  }

  async submitRect(auto = false) {
    if (!this.rect) {
      return
    }
    if (!this.isDirty && !auto) {
      this.showDetails()
      return
    }
    if (auto && (!this.isDirty || this.viewerInPortraitMode())) {
      console.log('[portrait-crop] autosave aborted: dirty?', this.isDirty, 'portrait?', this.viewerInPortraitMode())
      return
    }

    this.cancelAutoSave()
    this.setStatus('Saving…')
    console.log('[portrait-crop] submitting rect', this.serializedRect(), 'auto?', auto)

    try {
      const response = await fetch(`/api/photos/${this.photoIdValue}/portrait_crop`, {
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'X-CSRF-Token': this.csrfToken()
        },
        body: JSON.stringify({ portrait_crop: this.serializedRect() })
      })

      if (!response.ok) {
        throw new Error(`HTTP ${response.status}`)
      }

      const data = await response.json()
      this.imageWidth = data.image_width || this.imageWidth
      this.imageHeight = data.image_height || this.imageHeight
      this.rect = this.coerceRect(data.rect) || this.rect
      this.isDirty = false
      this.updateSaveState()
      this.renderOverlay()
      if (auto) {
        this.showDetails()
      } else {
        this.showDetails('Saved')
      }
      this.fadeOverlayIn()
      console.log('[portrait-crop] save complete')
    } catch (error) {
      console.error('Failed to save portrait crop', error)
      this.setStatus('Save failed', true)
    }
  }

  onHeroImageWillChange() {
    this.cancelAutoSave()
    this.frameCache = null
    this.fadeOverlayOut()
  }

  onHeroImageDidChange() {
    this.frameCache = null
    this.renderOverlay()
    this.fadeOverlayIn()
  }

  fadeOverlayOut() {
    if (!this.hasOverlayTarget) return
    this.overlayTarget.classList.remove('hidden')
    this.overlayTarget.classList.add('portrait-crop-overlay--hidden')
    if (this.hasWindowTarget) {
      this.windowTarget.classList.add('portrait-crop-window--disabled')
    }
    this.overlayVisible = false
    requestAnimationFrame(() => {
      this.overlayTarget.classList.add('hidden')
    })
  }

  fadeOverlayIn() {
    if (!this.hasOverlayTarget) return
    if (this.viewerInPortraitMode()) {
      this.fadeOverlayOut()
      return
    }
    if (this.overlayVisible) return
    this.overlayTarget.classList.remove('hidden')
    requestAnimationFrame(() => {
      this.overlayTarget.classList.remove('portrait-crop-overlay--hidden')
      if (this.hasWindowTarget) {
        this.windowTarget.classList.remove('portrait-crop-window--disabled')
      }
      this.overlayVisible = true
    })
  }
  
  viewerInPortraitMode() {
    let mode = this.element.getAttribute('data-hero-image-mode')
    if (!mode) {
      const heroContainer = this.element.querySelector('[data-hero-image-mode]')
      mode = heroContainer ? heroContainer.getAttribute('data-hero-image-mode') : null
    }
    const portrait = mode === 'portrait'
    if (portrait) {
      console.log('[portrait-crop] detected portrait mode attribute')
    }
    return portrait
  }

  csrfToken() {
    const element = document.querySelector('meta[name="csrf-token"]')
    return element ? element.content : ''
  }
}
