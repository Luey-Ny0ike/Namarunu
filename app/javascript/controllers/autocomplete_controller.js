import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { url: String, param: { type: String, default: "q" }, minLength: { type: Number, default: 2 } }
  static targets = ["input", "results", "hidden"]

  connect() {
    this._timer = null
    this._selectedStoreName = this.hiddenTarget.value ? this.inputTarget.value.trim() : ""
    this._close = this._onDocClick.bind(this)
    document.addEventListener("click", this._close)
  }

  disconnect() {
    document.removeEventListener("click", this._close)
  }

  search() {
    clearTimeout(this._timer)
    const query = this.inputTarget.value.trim()
    if (query.length < this.minLengthValue) {
      this._hide()
      return
    }
    this._timer = setTimeout(() => this._fetch(query), 300)
  }

  select(event) {
    const item = event.currentTarget
    this.inputTarget.value = item.dataset.name
    this.hiddenTarget.value = item.dataset.id
    this._selectedStoreName = item.dataset.name

    const emailInput = this.element.querySelector("[data-autocomplete-fills-email]")
    if (emailInput && item.dataset.emailAddress) emailInput.value = item.dataset.emailAddress

    const phoneInput = this.element.querySelector("[data-autocomplete-fills-phone]")
    if (phoneInput && item.dataset.phoneNumber) phoneInput.value = item.dataset.phoneNumber

    if (item.dataset.currency) {
      const currencySelect = document.querySelector("[data-autocomplete-fills-currency]")
      if (currencySelect) currencySelect.value = item.dataset.currency
    }

    this._hide()
  }

  selectNew() {
    this.hiddenTarget.value = ""
    this._selectedStoreName = ""

    this._hide()
  }

  clear() {
    if (!this.inputTarget.value.trim() || this.inputTarget.value.trim() !== this._selectedStoreName) {
      this.hiddenTarget.value = ""
    }
  }

  async _fetch(query) {
    const url = `${this.urlValue}?${this.paramValue}=${encodeURIComponent(query)}`
    try {
      const response = await fetch(url, { headers: { Accept: "application/json" } })
      const data = await response.json()
      this._render(query, data)
    } catch {
      this._hide()
    }
  }

  _render(query, items) {
    this.resultsTarget.innerHTML = ""

    items.forEach(item => {
      const li = document.createElement("li")
      li.className = "list-group-item list-group-item-action cursor-pointer"
      li.textContent = item.name
      li.dataset.id = item.id
      li.dataset.name = item.name
      li.dataset.currency = item.currency || ""
      li.dataset.emailAddress = item.email_address || ""
      li.dataset.phoneNumber = item.phone_number || ""
      li.dataset.action = "click->autocomplete#select"
      this.resultsTarget.appendChild(li)
    })

    const footer = document.createElement("li")
    footer.className = "list-group-item list-group-item-action text-muted small cursor-pointer"
    footer.textContent = `Use "${query}"`
    footer.dataset.action = "click->autocomplete#selectNew"
    this.resultsTarget.appendChild(footer)

    this.resultsTarget.classList.remove("d-none")
  }

  _hide() {
    this.resultsTarget.classList.add("d-none")
    this.resultsTarget.innerHTML = ""
  }

  _onDocClick(event) {
    if (!this.element.contains(event.target)) this._hide()
  }
}
