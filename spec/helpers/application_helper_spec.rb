# frozen_string_literal: true

require "rails_helper"

RSpec.describe ApplicationHelper, type: :helper do
  describe "#lead_status_badge_class" do
    it "maps statuses to the expected Bootstrap classes" do
      expect(helper.lead_status_badge_class("new")).to eq("text-bg-secondary")
      expect(helper.lead_status_badge_class("in_progress")).to eq("text-bg-secondary")
      expect(helper.lead_status_badge_class("contacted")).to eq("text-bg-info")
      expect(helper.lead_status_badge_class("qualified")).to eq("text-bg-info")
      expect(helper.lead_status_badge_class("demo_booked")).to eq("text-bg-primary")
      expect(helper.lead_status_badge_class("demo_completed")).to eq("text-bg-primary")
      expect(helper.lead_status_badge_class("awaiting_commitment")).to eq("text-bg-warning text-dark")
      expect(helper.lead_status_badge_class("invoice_sent")).to eq("text-bg-warning text-dark")
      expect(helper.lead_status_badge_class("won")).to eq("text-bg-success")
      expect(helper.lead_status_badge_class("lost")).to eq("text-bg-danger")
      expect(helper.lead_status_badge_class("unresponsive")).to eq("text-bg-dark")
    end

    it "falls back to secondary for unknown values" do
      expect(helper.lead_status_badge_class("something_else")).to eq("text-bg-secondary")
      expect(helper.lead_status_badge_class(nil)).to eq("text-bg-secondary")
    end
  end

  describe "#lead_temperature_badge_class" do
    it "maps temperatures to the expected Bootstrap classes" do
      expect(helper.lead_temperature_badge_class("hot")).to eq("text-bg-danger")
      expect(helper.lead_temperature_badge_class("warm")).to eq("text-bg-warning text-dark")
      expect(helper.lead_temperature_badge_class("cold")).to eq("text-bg-secondary")
    end

    it "falls back to secondary for unknown values" do
      expect(helper.lead_temperature_badge_class("unknown")).to eq("text-bg-secondary")
      expect(helper.lead_temperature_badge_class(nil)).to eq("text-bg-secondary")
    end
  end
end
