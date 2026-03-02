import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "rows", "template",
    "subtotal", "taxRate", "taxAmount", "grandTotal",
    "subtotalCents", "taxCents", "totalCents", "amountDueCents"
  ]
  static values = { currency: String, plans: Object }

  connect() {
    this._rowIndex = this.rowsTarget.querySelectorAll("[data-line-item-row]").length
    this.calculate()
  }

  add() {
    const html = this.templateTarget.innerHTML.replace(/LINE_ITEM_INDEX/g, this._rowIndex)
    this.rowsTarget.insertAdjacentHTML("beforeend", html)
    this._rowIndex++
    this.calculate()
  }

  remove(event) {
    const row = event.currentTarget.closest("[data-line-item-row]")
    const destroyInput = row.querySelector("[data-destroy-input]")
    if (destroyInput) {
      destroyInput.value = "1"
      row.classList.add("d-none")
    } else {
      row.remove()
    }
    this.calculate()
  }

  planChanged(event) {
    const planCode = event.target.value
    if (!planCode) return

    const planInfo = this.plansValue[planCode]
    if (!planInfo) return

    const currencyEl = this.element.querySelector("[data-currency-select]")
    const currency = currencyEl ? currencyEl.value : this.currencyValue

    const billingPeriodEl = this.element.querySelector("[data-billing-period-select]")
    const billingPeriod = billingPeriodEl && billingPeriodEl.value ? billingPeriodEl.value : "monthly"

    const priceCents = (planInfo.prices[currency] || {})[billingPeriod] || 0
    const periodLabel = billingPeriod === "semi_annually" ? "semi-annually" : billingPeriod

    let firstRow = this.rowsTarget.querySelector("[data-line-item-row]:not(.d-none)")
    if (!firstRow) {
      this.add()
      firstRow = this.rowsTarget.querySelector("[data-line-item-row]")
    }

    if (firstRow) {
      const kindSelect = firstRow.querySelector("[data-kind-select]")
      if (kindSelect) kindSelect.value = "subscription"

      const descInput = firstRow.querySelector("[data-description-input]")
      if (descInput) descInput.value = `${planInfo.name} plan (${periodLabel})`

      const qtyInput = firstRow.querySelector("[data-qty-input]")
      if (qtyInput) qtyInput.value = 1

      const priceInput = firstRow.querySelector("[data-price-input]")
      if (priceInput) priceInput.value = (priceCents / 100).toFixed(2)
    }

    const planTypeSelect = this.element.querySelector("[data-plan-type-select]")
    if (planTypeSelect && planInfo.plan_type) planTypeSelect.value = planInfo.plan_type

    this.calculate()
  }

  kindChanged(event) {
    const kind = event.target.value
    const row = event.target.closest("[data-line-item-row]")
    if (!row) return

    const descInput = row.querySelector("[data-description-input]")
    if (!descInput || descInput.value.trim()) return

    const defaults = { setup_fee: "Setup fee", tax: "Tax", discount: "Discount" }
    if (defaults[kind]) descInput.value = defaults[kind]
  }

  currencyChanged(event) {
    this.currencyValue = event.target.value
    this.calculate()
  }

  calculate() {
    let subtotalCents = 0

    this.rowsTarget.querySelectorAll("[data-line-item-row]:not(.d-none)").forEach(row => {
      const qty = parseInt(row.querySelector("[data-qty-input]").value) || 0
      const price = parseFloat(row.querySelector("[data-price-input]").value) || 0
      const unitCents = Math.round(price * 100)
      const amountCents = qty * unitCents

      row.querySelector("[data-unit-amount-cents-input]").value = unitCents
      row.querySelector("[data-amount-cents-input]").value = amountCents
      row.querySelector("[data-amount-display]").textContent = this.formatMoney(amountCents)

      subtotalCents += amountCents
    })

    const taxRate = parseFloat(this.taxRateTarget.value) || 0
    const taxCents = Math.round(subtotalCents * taxRate / 100)
    const totalCents = subtotalCents + taxCents

    this.subtotalTarget.textContent = this.formatMoney(subtotalCents)
    this.taxAmountTarget.textContent = this.formatMoney(taxCents)
    this.grandTotalTarget.textContent = this.formatMoney(totalCents)

    this.subtotalCentsTarget.value = subtotalCents
    this.taxCentsTarget.value = taxCents
    this.totalCentsTarget.value = totalCents
    this.amountDueCentsTarget.value = totalCents
  }

  formatMoney(cents) {
    const amount = cents / 100
    switch (this.currencyValue) {
      case "KES": return `KES ${Math.round(amount).toLocaleString()}`
      case "TZS": return `TZS ${Math.round(amount).toLocaleString()}`
      case "USD": return `$${amount.toFixed(2)}`
      default:    return `${this.currencyValue} ${amount.toFixed(2)}`
    }
  }
}
