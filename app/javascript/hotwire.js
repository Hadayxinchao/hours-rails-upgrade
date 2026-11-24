// Hotwire entry point. Turbo Drive stays off while the jQuery pages are
// migrated: those scripts bind on page load and would not re-run after a
// Drive visit. Frames, streams and forms opt in with data-turbo="true".
import { Turbo } from "@hotwired/turbo-rails"
import "controllers"

Turbo.session.drive = false
