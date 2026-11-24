# ES modules for Hotwire, served through Sprockets next to the classic
# jQuery bundle (app/assets/javascripts/application.js).
pin "hotwire"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin_all_from "app/javascript/controllers", under: "controllers"
