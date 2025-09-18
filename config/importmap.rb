# Pin npm packages by running ./bin/importmap

pin "application"
pin "@hotwired/stimulus", to: "@hotwired--stimulus.js" # @3.2.2
pin "@hotwired/turbo-rails", to: "@hotwired--turbo-rails.js" # @8.0.16
pin "@hotwired/turbo", to: "@hotwired--turbo.js" # @8.0.13
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin_all_from "app/javascript/controllers", under: "controllers"
pin "controllers", to: "controllers/index.js"
pin "persistent_storage", to: "persistent_storage.js"
# Chartkick and Chart.js Configuration
# Chartkick bundles Chart.js as Chart.bundle.js which includes the core library
pin "chartkick", to: "chartkick.js"
pin "Chart.bundle", to: "Chart.bundle.js"

# CRITICAL: Chart.js plugin compatibility mappings
# Chart.js plugins expect to import "chart.js" and "chart.js/helpers"
# We map these to Chart.bundle.js to satisfy plugin dependencies
pin "chart.js/helpers", to: "Chart.bundle.js"  # Required by plugins
pin "chart.js", to: "Chart.bundle.js"          # Required by plugins

# Chart.js plugins (UMD versions in vendor/javascript/)
pin "chartjs-plugin-annotation", to: "chartjs-plugin-annotation.js"
