import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["content", "icon"]
  
  connect() {
    // Start expanded
    this.contentTarget.style.display = "grid"
  }
  
  toggle() {
    if (this.contentTarget.style.display === "none") {
      this.contentTarget.style.display = "grid"
      this.iconTarget.style.transform = "rotate(0deg)"
    } else {
      this.contentTarget.style.display = "none"
      this.iconTarget.style.transform = "rotate(-90deg)"
    }
  }
}