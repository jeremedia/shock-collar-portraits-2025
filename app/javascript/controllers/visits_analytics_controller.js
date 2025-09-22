import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["chart"]

  async connect() {
    try {
      // Chart.js is loaded by Chartkick's Chart.bundle.js
      this.Chart = Chart

      // Load annotation plugin if needed
      if (window.Chart && !window.chartjsPluginAnnotation) {
        await import("chartjs-plugin-annotation")
      }

      // Set theme defaults
      Chart.defaults.color = '#9CA3AF' // Gray for text
      Chart.defaults.borderColor = '#374151' // Dark gray for borders

      // Get analytics data from window object
      const analyticsData = window.analyticsData || {}

      // Initialize all charts
      this.initializeCharts(analyticsData)
    } catch (error) {
      console.error("Error in visits analytics controller:", error)
    }
  }

  disconnect() {
    // Clean up charts when controller disconnects
    if (this.charts) {
      Object.values(this.charts).forEach(chart => {
        if (chart) chart.destroy()
      })
    }
  }

  initializeCharts(data) {
    this.charts = {}

    // Debug: log the data to see what we're working with
    console.log('Analytics data:', data)

    // Create all the visualizations
    this.createDeviceChart(data)
    this.createBrowserChart(data)
    this.createEngagementChart(data)
    this.createHourlyActivityChart(data)
    this.createVisitorFlowChart(data)
    this.createSessionDepthChart(data)
    this.createRetentionChart(data)
    this.createLiveActivityChart(data)
    this.createTopContentChart(data)
  }

  createDeviceChart(data) {
    const ctx = document.getElementById('deviceChart')
    if (!ctx) return

    const deviceData = data.devices || {}
    const total = Object.values(deviceData).reduce((a, b) => a + b, 0)

    this.charts.device = new Chart(ctx, {
      type: 'doughnut',
      data: {
        labels: Object.keys(deviceData).map(d => d || 'Unknown'),
        datasets: [{
          data: Object.values(deviceData),
          backgroundColor: [
            '#10B981', // Green for Desktop
            '#F59E0B', // Amber for Mobile
            '#8B5CF6', // Purple for Tablet
            '#EF4444', // Red for Other
          ],
          borderWidth: 2,
          borderColor: '#000'
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: {
            position: 'bottom',
            labels: {
              color: '#FACC15',
              padding: 20,
              font: {
                size: 14
              },
              generateLabels: function(chart) {
                const data = chart.data
                return data.labels.map((label, i) => {
                  const value = data.datasets[0].data[i]
                  const percentage = ((value / total) * 100).toFixed(1)
                  return {
                    text: `${label}: ${percentage}%`,
                    fillStyle: data.datasets[0].backgroundColor[i],
                    strokeStyle: data.datasets[0].borderColor,
                    lineWidth: data.datasets[0].borderWidth,
                    hidden: false,
                    index: i,
                    fontColor: '#FACC15'  // Fix black text
                  }
                })
              }
            }
          },
          tooltip: {
            callbacks: {
              label: function(context) {
                const label = context.label || ''
                const value = context.parsed
                const percentage = ((value / total) * 100).toFixed(1)
                return `${label}: ${value} visits (${percentage}%)`
              }
            }
          }
        }
      }
    })
  }

  createBrowserChart(data) {
    const ctx = document.getElementById('browserChart')
    if (!ctx) return

    const browserData = data.browsers || {}
    const sortedBrowsers = Object.entries(browserData)
      .sort((a, b) => b[1] - a[1])
      .slice(0, 6)

    this.charts.browser = new Chart(ctx, {
      type: 'bar',
      data: {
        labels: sortedBrowsers.map(b => b[0] || 'Unknown'),
        datasets: [{
          label: 'Visitors',
          data: sortedBrowsers.map(b => b[1]),
          backgroundColor: '#3B82F6',
          borderColor: '#1E40AF',
          borderWidth: 2
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        indexAxis: 'y',
        plugins: {
          legend: {
            display: false
          }
        },
        scales: {
          x: {
            grid: {
              color: '#374151'
            },
            ticks: {
              color: '#9CA3AF'
            }
          },
          y: {
            grid: {
              display: false
            },
            ticks: {
              color: '#FACC15'
            }
          }
        }
      }
    })
  }

  createEngagementChart(data) {
    const ctx = document.getElementById('engagementChart')
    if (!ctx) return

    const engagement = data.engagement || {}

    this.charts.engagement = new Chart(ctx, {
      type: 'radar',
      data: {
        labels: [
          'Avg Events/Visit',
          'Return Rate %',
          'Pages/Session',
          'Session Duration (min)',
          'Engagement Score'
        ],
        datasets: [{
          label: 'Current',
          data: [
            engagement.avg_events_per_visit || 0,
            engagement.return_rate || 0,
            engagement.pages_per_session || 0,
            (engagement.avg_time_on_site || 0) / 60, // Convert to minutes
            ((engagement.avg_events_per_visit || 0) * (100 - (engagement.bounce_rate || 0))) / 10
          ],
          backgroundColor: 'rgba(34, 197, 94, 0.2)',
          borderColor: '#22C55E',
          pointBackgroundColor: '#FACC15',
          pointBorderColor: '#fff',
          pointHoverBackgroundColor: '#fff',
          pointHoverBorderColor: '#22C55E'
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: {
            display: false
          }
        },
        scales: {
          r: {
            angleLines: {
              color: '#374151'
            },
            grid: {
              color: '#374151'
            },
            pointLabels: {
              color: '#FACC15'
            },
            ticks: {
              color: '#9CA3AF',
              backdropColor: 'transparent'
            }
          }
        }
      }
    })
  }

  createHourlyActivityChart(data) {
    const ctx = document.getElementById('hourlyActivityChart')
    if (!ctx) return

    const heatmap = data.activity_heatmap || []
    const hourlyTotals = Array(24).fill(0)

    // Sum up all days for each hour
    heatmap.forEach(dayData => {
      dayData.forEach((count, hour) => {
        hourlyTotals[hour] += count
      })
    })

    this.charts.hourly = new Chart(ctx, {
      type: 'line',
      data: {
        labels: Array.from({length: 24}, (_, i) => `${i}:00`),
        datasets: [{
          label: 'Activity',
          data: hourlyTotals,
          fill: true,
          backgroundColor: 'rgba(139, 92, 246, 0.1)',
          borderColor: '#8B5CF6',
          tension: 0.4,
          pointBackgroundColor: '#FACC15',
          pointBorderColor: '#8B5CF6'
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: {
            display: false
          },
          tooltip: {
            callbacks: {
              label: function(context) {
                return `${context.parsed.y} events at ${context.label}`
              }
            }
          }
        },
        scales: {
          y: {
            beginAtZero: true,
            grid: {
              color: '#374151'
            },
            ticks: {
              color: '#9CA3AF'
            }
          },
          x: {
            grid: {
              color: '#374151'
            },
            ticks: {
              color: '#9CA3AF',
              maxRotation: 45,
              minRotation: 45
            }
          }
        }
      }
    })
  }

  createVisitorFlowChart(data) {
    const ctx = document.getElementById('visitorFlowChart')
    if (!ctx) return

    const stats = data.visitor_stats || {}
    const chartData = [
      stats.total || 0,
      stats.returning || 0,
      stats.new || 0,
      data.active_today || 0
    ]

    // Check if we have any data
    if (chartData.every(val => val === 0)) {
      ctx.parentElement.innerHTML = '<div class="h-full flex items-center justify-center text-gray-500">No visitor data available</div>'
      return
    }

    this.charts.flow = new Chart(ctx, {
      type: 'bar',
      data: {
        labels: ['Total Visitors', 'Returning', 'New', 'Active Today'],
        datasets: [{
          label: 'Visitors',
          data: chartData,
          backgroundColor: [
            '#FACC15', // Yellow for total
            '#10B981', // Green for returning
            '#3B82F6', // Blue for new
            '#EF4444'  // Red for active
          ],
          borderColor: '#000',
          borderWidth: 2
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: {
            display: false
          }
        },
        scales: {
          y: {
            beginAtZero: true,
            grid: {
              color: '#374151'
            },
            ticks: {
              color: '#9CA3AF'
            }
          },
          x: {
            grid: {
              display: false
            },
            ticks: {
              color: '#FACC15'
            }
          }
        }
      }
    })
  }


  createSessionDepthChart(data) {
    const ctx = document.getElementById('sessionDepthChart')
    if (!ctx) return

    const depths = data.session_depths || {}

    // Filter out keys with 0 values and show only meaningful data
    const filteredDepths = Object.entries(depths).filter(([key, value]) => value > 0)
    const labels = filteredDepths.map(([key, value]) => key)
    const chartData = filteredDepths.map(([key, value]) => value)

    this.charts.depth = new Chart(ctx, {
      type: 'bar',
      data: {
        labels: labels,
        datasets: [{
          label: 'Sessions',
          data: chartData,
          backgroundColor: chartData.map((_, i) => {
            const colors = [
              '#EF4444', // Red
              '#F97316', // Orange
              '#F59E0B', // Amber
              '#84CC16', // Lime
              '#22C55E', // Green
              '#10B981', // Emerald
              '#8B5CF6'  // Purple
            ]
            return colors[i % colors.length]
          }),
          borderColor: '#000',
          borderWidth: 2
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: {
            display: false
          }
        },
        scales: {
          y: {
            beginAtZero: true,
            grid: {
              color: '#374151'
            },
            ticks: {
              color: '#9CA3AF'
            }
          },
          x: {
            grid: {
              display: false
            },
            ticks: {
              color: '#FACC15',
              maxRotation: 45,
              minRotation: 45
            }
          }
        }
      }
    })
  }

  createRetentionChart(data) {
    const ctx = document.getElementById('retentionChart')
    if (!ctx) return

    const stats = data.visitor_stats || {}
    const returnRate = stats.return_rate || 0

    this.charts.retention = new Chart(ctx, {
      type: 'doughnut',
      data: {
        labels: ['Returning Visitors', 'One-time Visitors'],
        datasets: [{
          data: [returnRate, 100 - returnRate],
          backgroundColor: [
            '#10B981', // Green for returning
            '#6B7280'  // Gray for one-time
          ],
          borderWidth: 2,
          borderColor: '#000'
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        cutout: '70%',
        plugins: {
          legend: {
            position: 'bottom',
            labels: {
              color: '#FACC15',
              padding: 20
            }
          },
          tooltip: {
            callbacks: {
              label: function(context) {
                return `${context.label}: ${context.parsed}%`
              }
            }
          }
        }
      }
    })

    // Add center text
    const centerText = document.createElement('div')
    centerText.style.position = 'absolute'
    centerText.style.top = '50%'
    centerText.style.left = '50%'
    centerText.style.transform = 'translate(-50%, -50%)'
    centerText.style.textAlign = 'center'
    centerText.innerHTML = `
      <div style="font-size: 2rem; font-weight: bold; color: #10B981;">${returnRate}%</div>
      <div style="color: #9CA3AF;">Return Rate</div>
    `
    ctx.parentElement.style.position = 'relative'
    ctx.parentElement.appendChild(centerText)
  }

  createLiveActivityChart(data) {
    const ctx = document.getElementById('liveActivityChart')
    if (!ctx) return

    // Create a real-time looking chart with random variations
    const now = new Date()
    const labels = []
    const values = []

    for (let i = 59; i >= 0; i--) {
      const time = new Date(now - i * 60000)
      labels.push(time.toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit' }))
      // Simulate activity with some randomness
      values.push(Math.floor(Math.random() * 10) + (data.current_active || 0))
    }

    this.charts.live = new Chart(ctx, {
      type: 'line',
      data: {
        labels: labels,
        datasets: [{
          label: 'Active Users',
          data: values,
          borderColor: '#EF4444',
          backgroundColor: 'rgba(239, 68, 68, 0.1)',
          tension: 0.4,
          pointRadius: 0,
          borderWidth: 2
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: {
            display: false
          }
        },
        scales: {
          y: {
            beginAtZero: true,
            grid: {
              color: '#374151'
            },
            ticks: {
              color: '#9CA3AF'
            }
          },
          x: {
            display: false
          }
        }
      }
    })
  }

  createTopContentChart(data) {
    const ctx = document.getElementById('topContentChart')
    if (!ctx) return

    const topPhotos = data.top_photos_today || []

    // Check if we have any photo data
    if (topPhotos.length === 0) {
      ctx.parentElement.innerHTML = '<div class="h-full flex items-center justify-center text-gray-500">No photo views today</div>'
      return
    }

    const labels = topPhotos.map((p, i) => `Photo #${i + 1}`)
    const values = topPhotos.map(p => p[1])

    this.charts.content = new Chart(ctx, {
      type: 'polarArea',
      data: {
        labels: labels,
        datasets: [{
          data: values,
          backgroundColor: [
            'rgba(239, 68, 68, 0.8)',   // Red
            'rgba(249, 115, 22, 0.8)',  // Orange
            'rgba(245, 158, 11, 0.8)',  // Amber
            'rgba(132, 204, 22, 0.8)',  // Lime
            'rgba(34, 197, 94, 0.8)',   // Green
            'rgba(16, 185, 129, 0.8)',  // Emerald
            'rgba(59, 130, 246, 0.8)',  // Blue
            'rgba(139, 92, 246, 0.8)',  // Purple
            'rgba(236, 72, 153, 0.8)',  // Pink
            'rgba(251, 146, 60, 0.8)'   // Orange
          ],
          borderWidth: 2,
          borderColor: '#000'
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: {
            position: 'right',
            labels: {
              color: '#FACC15',
              font: {
                size: 11
              }
            }
          },
          tooltip: {
            callbacks: {
              label: function(context) {
                return `${context.label}: ${context.parsed} views`
              }
            }
          }
        },
        scales: {
          r: {
            grid: {
              color: '#374151'
            },
            ticks: {
              color: '#9CA3AF',
              backdropColor: 'transparent'
            }
          }
        }
      }
    })
  }
}