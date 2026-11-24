import { Controller } from "@hotwired/stimulus"

// Shows the time since startedAt as h:mm:ss, updated every second. The start
// time comes from the server, so the clock is right after reloads and in
// every open tab.
export default class extends Controller {
  static targets = ["display"]
  static values = { startedAt: String }

  connect() {
    this.render()
    this.interval = setInterval(() => this.render(), 1000)
  }

  disconnect() {
    clearInterval(this.interval)
  }

  render() {
    const seconds = Math.max(0, Math.floor((Date.now() - Date.parse(this.startedAtValue)) / 1000))
    const h = Math.floor(seconds / 3600)
    const m = String(Math.floor((seconds % 3600) / 60)).padStart(2, "0")
    const s = String(seconds % 60).padStart(2, "0")
    this.displayTarget.textContent = `${h}:${m}:${s}`
  }
}
