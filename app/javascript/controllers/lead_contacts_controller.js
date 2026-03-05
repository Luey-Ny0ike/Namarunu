import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["container", "template"]

  add(event) {
    event.preventDefault()

    const index = Date.now().toString()
    const content = this.templateTarget.innerHTML.replace(/NEW_RECORD/g, index)
    this.containerTarget.insertAdjacentHTML("beforeend", content)
  }

  remove(event) {
    event.preventDefault()

    const contactRow = event.currentTarget.closest("[data-lead-contact-row]")
    if (!contactRow) return

    const destroyInput = contactRow.querySelector('input[name*="[_destroy]"]')
    if (destroyInput) destroyInput.value = "1"

    contactRow.classList.add("d-none")

    contactRow.querySelectorAll("input, select, textarea").forEach((field) => {
      if (field === destroyInput) return
      if (field.type === "hidden") return

      field.disabled = true
    })
  }
}
