
import { Controller } from "@hotwired/stimulus"

// console.log("Stats controller file loaded!")

// IMPORTANT: Chart.js Plugin Integration with Chartkick
// ======================================================
// When using Chart.js plugins with Chartkick in Rails:
//
// 1. Chartkick bundles Chart.js as "Chart.bundle.js"
// 2. Plugins expect Chart.js and helpers to be available globally
// 3. Must map both "chart.js" and "chart.js/helpers" to Chart.bundle.js in importmap
// 4. Load plugins dynamically AFTER Chart.js is available
//
// To add a new Chart.js plugin:
// a) Download the UMD version to vendor/javascript/
// b) Add to config/importmap.rb: pin "plugin-name", to: "plugin-name.js"
// c) Also ensure these mappings exist in importmap.rb:
//    pin "chart.js/helpers", to: "Chart.bundle.js"
//    pin "chart.js", to: "Chart.bundle.js"
// d) Import dynamically in this controller after Chart is loaded

export default class extends Controller {
  static targets = ["chart"]

  initialize() {
    // console.log("📊 STATS CONTROLLER INITIALIZED!")
    // initialized
  }

  async connect() {
    // console.log("🚀 STATS CONTROLLER CONNECT CALLED!")
    // console.log("Element:", this.element)
    // console.log("Stimulus working:", this.identifier)
    try {
      // console.log("Stats controller connecting...")

      // Chart.js is loaded by Chartkick's Chart.bundle.js
      // This provides the global Chart object with all core functionality
      this.Chart = Chart
      // console.log("Chart.js loaded:", this.Chart)

      // Load annotation plugin after Chart.js is available
      // The plugin self-registers with Chart.js when imported
      if (window.Chart && !window.chartjsPluginAnnotation) {
        await import("chartjs-plugin-annotation")
        // console.log("Annotation plugin loaded and registered")
      }

      // Set OKNOTOK theme defaults
      Chart.defaults.color = '#FACC15' // Gold for text
      Chart.defaults.borderColor = '#DC2626' // Red for borders

      // Get stats data from window object
      const statsData = window.statsData || {}
      // console.log("Stats data:", statsData)

      // Initialize all charts
      this.initializeCharts()
      // console.log("Charts initialized")
    } catch (error) {
      console.error("Error in stats controller connect:", error)
    }
  }

  async loadChart() {
      // const col = await import("@kurkle/color")
      await import( "chartkick")
    const mod = await import("Chart.bundle")

    return mod.default || mod.Chart || mod
  }

  // No-op retained for backward compatibility if needed in future
  loadScript() { return Promise.resolve() }

  disconnect() {
    // Clean up charts when controller disconnects
    if (this.charts) {
      Object.values(this.charts).forEach(chart => {
        if (chart) chart.destroy()
      })
    }
  }

  initializeCharts() {
    this.charts = {}

    // Get data from window object
    const statsData = window.statsData || {}
    // console.log("Initializing charts with data:", statsData)

    try {
      this.createDailyActivityChart(statsData)
      this.createDailyTimelineCharts(statsData)
      this.createCameraChart(statsData)
      this.createHeroGenderChart(statsData)
      this.createCombinedTimelineChart(statsData)
      this.createDistributionChart(statsData)
    } catch (error) {
      console.error("Error creating charts:", error)
    }
  }

  createDailyActivityChart(data) {
    // console.log("Creating daily activity chart...")
    const canvas = document.getElementById('dailyActivityChart')
    // console.log("Canvas found:", canvas)
    // console.log("Daily details:", data.dailyDetails)

    if (!canvas) {
      console.warn("dailyActivityChart canvas not found")
      return
    }

    if (!data.dailyDetails) {
      console.warn("dailyDetails data not found")
      return
    }

    const dailyDetails = data.dailyDetails
    const dailyDates = Object.keys(dailyDetails).sort().slice(0, 5) // Only Mon-Fri

    const dayNames = dailyDates.map(d => {
      const [year, month, day] = d.split('-').map(n => parseInt(n))
      const date = new Date(Date.UTC(year, month - 1, day))
      return date.toLocaleDateString('en-US', { weekday: 'short', month: 'short', day: 'numeric', timeZone: 'UTC' })
    })

    const sessionCounts = dailyDates.map(d => dailyDetails[d].count)
    const photoCounts = dailyDates.map(d => dailyDetails[d].photos)

    this.charts.dailyActivity = new this.Chart(canvas, {
      type: 'bar',
      data: {
        labels: dayNames,
        datasets: [
          {
            label: 'Sessions',
            data: sessionCounts,
            backgroundColor: '#DC2626',
            borderColor: '#DC2626',
            borderWidth: 2,
            yAxisID: 'y'
          },
          {
            label: 'Photos',
            data: photoCounts,
            backgroundColor: '#FACC15',
            borderColor: '#FACC15',
            borderWidth: 2,
            yAxisID: 'y1'
          }
        ]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          title: { display: false }
        },
        scales: {
          y: {
            type: 'linear',
            display: true,
            position: 'left',
            title: { display: true, text: 'Sessions' },
            beginAtZero: true
          },
          y1: {
            type: 'linear',
            display: true,
            position: 'right',
            title: { display: true, text: 'Photos' },
            beginAtZero: true,
            grid: { drawOnChartArea: false }
          }
        }
      }
    })
  }

  createDailyTimelineCharts(data) {
    if (!data.dailySessionTimelines) return

    const days = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday']

    days.forEach(day => {
      const canvas = document.getElementById(`${day}Chart`)
      if (!canvas) return

      // Find the matching date key using UTC to avoid timezone day-shift
      const dayKey = Object.keys(data.dailySessionTimelines).find(key => {
        const date = new Date(`${key}T00:00:00Z`)
        return date.toLocaleDateString('en-US', { weekday: 'long', timeZone: 'UTC' }).toLowerCase() === day
      })

      const dayData = dayKey ? data.dailySessionTimelines[dayKey] : null
      if (!dayData) return

      // Build per-minute buckets across 3:00–5:00 PM for consistent spacing
      const sessions = (dayData.sessions || [])
      const toMinutes = (h, m) => (h * 60) + m
      const startMin = toMinutes(15, 0)
      const endMin   = toMinutes(17, 0) // inclusive
      const minutes = []
      for (let m = startMin; m <= endMin; m++) minutes.push(m)
      const buckets = new Map(minutes.map(m => [m, 0]))
      sessions.forEach(s => {
        const m = toMinutes(s.hour, s.minute)
        if (m >= startMin && m <= endMin) buckets.set(m, (buckets.get(m) || 0) + s.photo_count)
      })
      // Axis labels: show time every 15 minutes, empty string for others
      const labels = minutes.map((m, index) => {
        // Show label at 3:00, 3:15, 3:30, 3:45, 4:00, 4:15, 4:30, 4:45, 5:00
        if (index % 15 === 0) {
          return this.formatTimeNoMeridiem(Math.floor(m / 60), m % 60)
        }
        return '' // Empty label for non-15-minute marks
      })
      const values = minutes.map(m => buckets.get(m) || 0)

      // Rain annotations for affected days
      const annotations = {}

      // Monday: 3:28 PM through 4:46 PM
      if (day === 'monday') {
        annotations.rainBox = {
          type: 'box',
          xMin: 28,  // 3:28 PM is index 28 (28 minutes after 3:00)
          xMax: 106, // 4:46 PM is index 106 (106 minutes after 3:00)
          yMin: 0,
          yMax: 'max',
          backgroundColor: 'rgba(100, 116, 139, 0.2)', // Slate with transparency
          borderColor: 'rgba(100, 116, 139, 0.5)',
          borderWidth: 1,
          label: {
            display: true,
            content: '🌧️ Rain',
            position: 'start',
            color: '#94a3b8',
            font: {
              size: 11
            }
          }
        }
      }

      // Tuesday: 3:00-3:33 PM
      if (day === 'tuesday') {
        annotations.rainBox = {
          type: 'box',
          xMin: 0,  // 3:00 PM is index 0
          xMax: 33, // 3:33 PM is index 33
          yMin: 0,
          yMax: 'max',
          backgroundColor: 'rgba(100, 116, 139, 0.2)',
          borderColor: 'rgba(100, 116, 139, 0.5)',
          borderWidth: 1,
          label: {
            display: true,
            content: '🌧️ Rain',
            position: 'start',
            color: '#94a3b8',
            font: {
              size: 11
            }
          }
        }
      }

      // Wednesday: 4:06-5:33 PM (extends past our 5:00 PM window)
      if (day === 'wednesday') {
        annotations.rainBox = {
          type: 'box',
          xMin: 66,  // 4:06 PM is index 66 (66 minutes after 3:00)
          xMax: 120, // 5:00 PM is index 120 (end of our window, rain continued to 5:33)
          yMin: 0,
          yMax: 'max',
          backgroundColor: 'rgba(100, 116, 139, 0.2)',
          borderColor: 'rgba(100, 116, 139, 0.5)',
          borderWidth: 1,
          label: {
            display: true,
            content: '🌧️ Rain (4:06-5:33)',
            position: 'start',
            color: '#94a3b8',
            font: {
              size: 11
            }
          }
        }
      }

      this.charts[day] = new this.Chart(canvas, {
        type: 'bar',
        data: {
          labels,
          datasets: [{
            label: 'Photos',
            data: values,
            backgroundColor: '#FACC15',
            borderColor: '#DC2626',
            borderWidth: 1,
            barThickness: 4,
            maxBarThickness: 6
          }]
        },
        options: {
          responsive: true,
          maintainAspectRatio: false,
          plugins: {
            title: { display: false },
            legend: { display: false },
            tooltip: {
              callbacks: {
                // Default tooltip title is the label (already formatted time)
              }
            },
            annotation: {
              annotations: annotations
            }
          },
          scales: {
            x: {
              ticks: {
                autoSkip: true,
                maxRotation: 0
              }
            },
            y: {
              beginAtZero: true,
              title: { display: true, text: 'Photos' }
            }
          }
        }
      })
    })
  }

  // Combined smoothed average line chart across all days
  createCombinedTimelineChart(data) {
    if (!data.dailySessionTimelines) return

    const canvas = document.getElementById('combinedTimelineChart')
    if (!canvas) return

    const dayOrder = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday']
    const keysByDay = {}
    Object.keys(data.dailySessionTimelines).forEach(key => {
      const date = new Date(`${key}T00:00:00Z`)
      const name = date.toLocaleDateString('en-US', { weekday: 'long', timeZone: 'UTC' }).toLowerCase()
      keysByDay[name] = key
    })

    // 10-minute bucket labels 3:00–5:00
    const toMinutes = (h, m) => (h * 60) + m
    const startMin = toMinutes(15, 0)
    const endMin   = toMinutes(17, 0)
    const minutes = []
    for (let m = startMin; m <= endMin; m += 10) minutes.push(m)
    // Show labels every 30 minutes for the combined chart (less crowded)
    const labels = minutes.map((m, index) => {
      // Show at 3:00, 3:30, 4:00, 4:30, 5:00
      const minutesFromStart = m - startMin
      if (minutesFromStart % 30 === 0) {
        return this.formatTimeNoMeridiem(Math.floor(m / 60), m % 60)
      }
      return ''
    })

    const colors = {
      // Use non-theme colors for clarity
      monday:    '#22D3EE', // cyan
      tuesday:   '#F472B6', // pink
      wednesday: '#10B981', // emerald
      thursday:  '#3B82F6', // blue
      friday:    '#A855F7'  // purple
    }

    const datasets = []
    dayOrder.forEach(day => {
      const key = keysByDay[day]
      if (!key) return
      const dayData = data.dailySessionTimelines[key]
      const sessions = (dayData.sessions || [])

      // Build sessions-per-10-minute counts
      const cnt = new Map(minutes.map(m => [m, 0]))
      sessions.forEach(s => {
        const m = toMinutes(s.hour, s.minute)
        if (m >= startMin && m <= endMin) {
          // Snap to 10-minute bucket starting at startMin
          const bucket = startMin + Math.floor((m - startMin) / 10) * 10
          cnt.set(bucket, (cnt.get(bucket) || 0) + 1)
        }
      })
      const counts = minutes.map(m => cnt.get(m) || 0)

      // Smooth with a simple moving average
      const smooth = this.movingAverage(counts, 5)

      datasets.push({
        label: day.charAt(0).toUpperCase() + day.slice(1),
        data: smooth,
        borderColor: colors[day],
        backgroundColor: 'transparent',
        borderWidth: 2,
        tension: 0.35,
        pointRadius: 0
      })
    })

    this.charts.combined = new this.Chart(canvas, {
      type: 'line',
      data: { labels, datasets },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          title: { display: false },
          legend: { display: true, labels: { color: '#e5e7eb' } }
        },
        scales: {
          x: {
            ticks: { autoSkip: true, maxRotation: 0 },
            grid: { display: false }
          },
          y: {
            beginAtZero: true,
            title: { display: true, text: 'Sessions per 10 min' },
            grid: { display: false }
          }
        }
      }
    })
  }

  movingAverage(arr, window) {
    if (window <= 1) return arr.slice()
    const out = new Array(arr.length).fill(0)
    let sum = 0
    for (let i = 0; i < arr.length; i++) {
      sum += arr[i]
      if (i >= window) sum -= arr[i - window]
      const denom = Math.min(i + 1, window)
      out[i] = sum / denom
    }
    return out
  }

  formatTime12(hour, minute) {
    const h = ((hour + 11) % 12) + 1 // 0=>12, 13=>1, etc.
    const m = String(minute).padStart(2, '0')
    const ampm = hour >= 12 ? 'PM' : 'AM'
    return `${h}:${m} ${ampm}`
  }

  formatTimeNoMeridiem(hour, minute) {
    const h = ((hour + 11) % 12) + 1 // convert to 12-hour without suffix
    const m = String(minute).padStart(2, '0')
    return `${h}:${m}`
  }

  createCameraChart(data) {
    const canvas = document.getElementById('cameraChart')
    if (!canvas || !data.canonSessions || !data.iphoneSessions) return

    this.charts.camera = new this.Chart(canvas, {
      type: 'doughnut',
      data: {
        labels: ['Canon R5', 'iPhone'],
        datasets: [{
          data: [data.canonSessions, data.iphoneSessions],
          backgroundColor: ['#DC2626', '#FACC15'],
          borderColor: ['#DC2626', '#FACC15'],
          borderWidth: 2
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          title: { display: false },
          legend: { display: false }
        }
      }
    })
  }

  createHeroGenderChart(data) {
    const canvas = document.getElementById('heroGenderChart')
    if (!canvas || !data.heroGenders) return

    const genders = data.heroGenders
    const labels = []
    const values = []
    const colors = []

    if (genders.male > 0) {
      labels.push('Male')
      values.push(genders.male)
      colors.push('#3B82F6') // Blue
    }
    if (genders.female > 0) {
      labels.push('Female')
      values.push(genders.female)
      colors.push('#EC4899') // Pink
    }
    if (genders.unknown > 0) {
      labels.push('Unknown')
      values.push(genders.unknown)
      colors.push('#6B7280') // Gray
    }

    this.charts.heroGender = new this.Chart(canvas, {
      type: 'doughnut',
      data: {
        labels: labels,
        datasets: [{
          data: values,
          backgroundColor: colors,
          borderColor: colors,
          borderWidth: 2
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          title: { display: false },
          legend: { display: false }
        }
      }
    })
  }

  createDistributionChart(data) {
    const canvas = document.getElementById('distributionChart')
    if (!canvas || !data.photoDistribution) return

    const distribution = data.photoDistribution
    const labels = Object.keys(distribution).sort()
    const values = labels.map(label => distribution[label])

    this.charts.distribution = new this.Chart(canvas, {
      type: 'bar',
      data: {
        labels: labels,
        datasets: [{
          label: 'Sessions',
          data: values,
          backgroundColor: '#FACC15',
          borderColor: '#DC2626',
          borderWidth: 1
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          title: { display: false },
          legend: { display: false }
        },
        scales: {
          y: {
            beginAtZero: true,
            title: { display: true, text: 'Sessions' }
          },
          x: {
            title: { display: true, text: 'Photos' }
          }
        }
      }
    })
  }
}
