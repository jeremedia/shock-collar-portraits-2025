# Pin npm packages by running ./bin/importmap

pin "application"
pin "@hotwired/stimulus", to: "@hotwired--stimulus.js" # @3.2.2
pin "@hotwired/turbo-rails", to: "@hotwired--turbo-rails.js" # @8.0.16
pin "@hotwired/turbo", to: "@hotwired--turbo.js" # @8.0.13
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin_all_from "app/javascript/controllers", under: "controllers"
pin "controllers", to: "controllers/index.js"
pin "persistent_storage", to: "persistent_storage.js"
pin "chartkick", to: "chartkick.js"
pin "Chart.bundle", to: "Chart.bundle.js"
