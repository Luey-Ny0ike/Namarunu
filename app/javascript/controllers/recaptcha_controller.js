import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    function: String
  }

  submit(event) {
    if (this.submitting) {
      return
    }

    const executeFunction = this.functionValue
    const executeRecaptcha = executeFunction && window[executeFunction]

    if (typeof executeRecaptcha !== "function") {
      return
    }

    event.preventDefault()
    this.submitting = true

    executeRecaptcha()
      .then(() => {
        if (this.element.requestSubmit) {
          this.element.requestSubmit()
        } else {
          this.element.submit()
        }
      })
      .catch(() => {
        this.submitting = false
      })
  }
}
