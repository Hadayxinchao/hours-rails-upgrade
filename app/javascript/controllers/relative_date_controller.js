import { Controller } from "@hotwired/stimulus"

// "today", "yesterday", "3 days ago". Replaces feed.js, which only ran once on
// page load and so missed entries that arrive later over the live feed.
export default class extends Controller {
  static values = { date: String }

  connect() {
    if (!window.DateFormatter) return

    const locale = document.body.dataset.language
    this.element.textContent = new window.DateFormatter(this.dateValue, locale).daysAgoInWords()
  }
}
