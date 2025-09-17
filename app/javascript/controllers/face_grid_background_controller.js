import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    opacity: { type: Number, default: 50 },
    interval: { type: Number, default: 5000 },
    gridSize: { type: Number, default: 6 }
  }

  connect() {
    this.faces = []
    this.usedFaceIds = new Set()
    this.gridCells = []

    this.createGrid()
    this.loadFaces()

    // Start animation interval
    this.startAnimation()

    // Add resize handler
    window.addEventListener('resize', this.handleResize)
  }

  disconnect() {
    if (this.animationInterval) {
      clearInterval(this.animationInterval)
    }

    if (this.resizeTimeout) {
      clearTimeout(this.resizeTimeout)
    }

    window.removeEventListener('resize', this.handleResize)
  }

  createGrid() {
    // Create background container
    this.backgroundContainer = document.createElement('div')
    this.backgroundContainer.className = 'fixed inset-0 overflow-hidden pointer-events-none'
    this.backgroundContainer.style.zIndex = '0'

    // Create grid
    this.grid = document.createElement('div')
    this.grid.className = 'absolute inset-0 grid gap-1'
    this.grid.style.opacity = `${this.opacityValue / 100}`

    // Calculate grid dimensions based on viewport
    const viewportWidth = window.innerWidth
    const viewportHeight = window.innerHeight

    // Target cell size (square cells for square face crops)
    const targetCellSize = window.innerWidth < 640 ? 100 : 150

    // Calculate how many columns and rows we need to fill the viewport
    const gridCols = Math.ceil(viewportWidth / targetCellSize)
    const gridRows = Math.ceil(viewportHeight / targetCellSize)

    // Set actual cell size to perfectly fill viewport
    const actualCellWidth = viewportWidth / gridCols
    const actualCellHeight = viewportHeight / gridRows
    const actualCellSize = Math.min(actualCellWidth, actualCellHeight)

    this.grid.style.gridTemplateColumns = `repeat(${gridCols}, ${actualCellSize}px)`
    this.grid.style.gridTemplateRows = `repeat(${gridRows}, ${actualCellSize}px)`
    this.grid.style.justifyContent = 'center'
    this.grid.style.alignContent = 'center'

    this.backgroundContainer.appendChild(this.grid)

    // Insert at beginning of element
    this.element.style.position = 'relative'
    this.element.insertBefore(this.backgroundContainer, this.element.firstChild)

    // Make sure form content is above background
    const content = this.element.querySelector('.max-w-md')
    if (content) {
      content.style.position = 'relative'
      content.style.zIndex = '10'
    }

    // Calculate number of cells needed to fill viewport
    const cellCount = gridCols * gridRows

    // Create grid cells
    for (let i = 0; i < cellCount; i++) {
      const cell = document.createElement('div')
      cell.className = 'relative overflow-hidden'
      cell.style.backgroundColor = 'rgba(0, 0, 0, 0.3)'
      cell.style.width = `${actualCellSize}px`
      cell.style.height = `${actualCellSize}px`

      const img = document.createElement('img')
      img.className = 'absolute inset-0 w-full h-full object-cover transition-opacity duration-1000'
      img.style.opacity = '0'

      cell.appendChild(img)
      this.grid.appendChild(cell)
      this.gridCells.push({ cell, img, currentFaceId: null })
    }
  }

  async loadFaces() {
    try {
      const response = await fetch('/api/photos/random_hero_faces')
      const data = await response.json()

      if (data.status === 'success' && data.faces) {
        this.faces = data.faces

        // Initially populate all cells, cycling through available faces
        this.gridCells.forEach((cellData) => {
          const face = this.getRandomUnusedFace()
          if (face) {
            this.updateCell(cellData, face)
          }
        })
      }
    } catch (error) {
      console.error('Failed to load hero faces:', error)
    }
  }

  getRandomUnusedFace() {
    if (this.faces.length === 0) return null

    // If we need more faces than available, allow reuse
    if (this.usedFaceIds.size >= this.faces.length) {
      this.usedFaceIds.clear()
    }

    // Filter out already used faces
    const availableFaces = this.faces.filter(face => !this.usedFaceIds.has(face.id))

    if (availableFaces.length === 0) {
      // All faces used, pick any random face
      return this.faces[Math.floor(Math.random() * this.faces.length)]
    }

    const face = availableFaces[Math.floor(Math.random() * availableFaces.length)]
    this.usedFaceIds.add(face.id)
    return face
  }

  updateCell(cellData, face) {
    if (!face || !face.url) return

    // Remove old face from used set if it exists
    if (cellData.currentFaceId) {
      this.usedFaceIds.delete(cellData.currentFaceId)
    }

    // Create new image element for smooth transition
    const newImg = document.createElement('img')
    newImg.className = 'absolute inset-0 w-full h-full object-cover transition-opacity duration-1000'
    newImg.style.opacity = '0'

    newImg.onload = () => {
      // Fade in new image
      requestAnimationFrame(() => {
        newImg.style.opacity = '1'
      })

      // After transition, remove old image
      setTimeout(() => {
        if (cellData.img && cellData.img !== newImg) {
          cellData.img.remove()
        }
        cellData.img = newImg
      }, 1000)
    }

    newImg.src = face.url
    cellData.cell.appendChild(newImg)
    cellData.currentFaceId = face.id
  }

  startAnimation() {
    this.animationInterval = setInterval(() => {
      // Pick a random cell to update
      const randomIndex = Math.floor(Math.random() * this.gridCells.length)
      const cellData = this.gridCells[randomIndex]

      // Fade out current image
      if (cellData.img) {
        cellData.img.style.opacity = '0'
      }

      // After fade out, update with new face
      setTimeout(() => {
        const newFace = this.getRandomUnusedFace()
        if (newFace) {
          this.updateCell(cellData, newFace)
        }
      }, 1000)
    }, this.intervalValue)
  }

  // Handle window resize
  handleResize = () => {
    if (this.resizeTimeout) {
      clearTimeout(this.resizeTimeout)
    }

    this.resizeTimeout = setTimeout(() => {
      // Recreate grid with new dimensions
      if (this.animationInterval) {
        clearInterval(this.animationInterval)
      }

      this.backgroundContainer?.remove()
      this.gridCells = []
      this.usedFaceIds.clear()

      this.createGrid()
      this.loadFaces()
      this.startAnimation()
    }, 250)
  }
}