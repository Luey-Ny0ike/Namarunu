# frozen_string_literal: true

store = Store.find_or_create_by!(email_address: "hello@gloworganics.co.ke") do |s|
  s.name         = "Glow Organics Kenya"
  s.currency     = "KES"
  s.phone_number = "+254 712 345 678"
end

subscription = Store::Subscription.find_or_create_by!(
  store:                store,
  plan_code:            "sungura",
  billing_period:       "monthly",
  current_period_start: Date.new(2026, 2, 1),
  current_period_end:   Date.new(2026, 2, 28)
) do |s|
  s.currency          = "KES"
  s.status            = "active"
  s.quantity          = 1
  s.unit_amount_cents = 195_000
end

unless Invoice.exists?(store_subscription: subscription,
                        billing_period_start: subscription.current_period_start,
                        billing_period_end:   subscription.current_period_end)
  Invoice::Creator.new(subscription).create
end

[
  {
    name: "Zawadi Boutique",
    industry: "fashion",
    location: "Westlands, Nairobi",
    status: "active",
    instagram_handle: "zawadiboutique",
    contacts: [
      { name: "Amina Odhiambo", phone: "+254 711 001 001", email: "amina@zawadiboutique.co.ke", role: "Owner" }
    ]
  },
  {
    name: "Pendo Naturals",
    industry: "beauty",
    location: "Kilimani, Nairobi",
    status: "active",
    instagram_handle: "pendonaturals",
    tiktok_handle: "pendonaturals",
    contacts: [
      { name: "Grace Njeri", phone: "+254 722 002 002", email: "grace@pendonaturals.co.ke", role: "Owner" },
      { name: "David Kamau", phone: "+254 733 002 003", role: "Manager" }
    ]
  },
  {
    name: "Jua Kali Electronics",
    industry: "other",
    location: "Gikomba, Nairobi",
    status: "pending",
    contacts: [
      { name: "Peter Otieno", phone: "+254 700 003 001", email: "peter@juakali.co.ke", role: "Owner" }
    ]
  },
  {
    name: "Dhahabu Jewellers",
    industry: "jewellery",
    location: "CBD, Nairobi",
    status: "active",
    instagram_handle: "dhahabujewellers",
    contacts: [
      { name: "Fatuma Hassan", email: "fatuma@dhahabujewellers.co.ke", role: "Owner" },
      { name: "Ali Hassan", phone: "+254 755 004 002", role: "Sales" }
    ]
  },
  {
    name: "Nyumbani Home Goods",
    industry: "household_goods",
    location: "Ngong Road, Nairobi",
    status: "cancelled",
    contacts: [
      { name: "Joyce Wanjiku", phone: "+254 799 005 001", email: "joyce@nyumbanihome.co.ke", role: "Owner" }
    ]
  }
].each do |attrs|
  account = Account.find_or_create_by!(name: attrs[:name]) do |a|
    a.industry         = attrs[:industry]
    a.location         = attrs[:location]
    a.status           = attrs[:status]
    a.instagram_handle = attrs[:instagram_handle]
    a.tiktok_handle    = attrs[:tiktok_handle]
  end

  attrs[:contacts].each do |contact_attrs|
    account.contacts.find_or_create_by!(name: contact_attrs[:name]) do |c|
      c.phone = contact_attrs[:phone]
      c.email = contact_attrs[:email]
      c.role  = contact_attrs[:role]
    end
  end
end

LEAD_FIRST_NAMES = %w[
  Amina Aisha Fatuma Grace Joyce Wanjiku Njeri Purity Mercy Faith
  Brian Kevin Dennis Patrick Kelvin Moses Elijah Samuel George John
  Lilian Sharon Winnie Esther Naomi Ruth Miriam Beatrice Cynthia Diana
  Hassan Ali Omar Yusuf Ibrahim Abdallah Rashid Salim Ahmed Mohamed
  Otieno Odhiambo Akinyi Adhiambo Awino Onyango Ouma Ochieng Ogola Ondiek
  Kamau Waweru Mwangi Njogu Kariuki Gitahi Njoroge Waithaka Muigai Gichuki
  Mutua Musyoka Muthiani Ndambuki Munyao Kivuva Mutuku Kioko Kitheka Katana
  Zawadi Pendo Furaha Neema Baraka Upendo Imani Amani Tumaini Salama
].freeze

LEAD_LAST_NAMES = %w[
  Odhiambo Njeri Wanjiku Kamau Otieno Mwangi Kariuki Mutua Ochieng Hassan
  Njoroge Musyoka Auma Akinyi Waweru Gitahi Ndambuki Munyao Adhiambo Kioko
  Awino Njogu Waithaka Kivuva Ogola Muigai Kitheka Katana Gichuki Ondiek
  Rashid Salim Ahmed Omar Ali Yusuf Ibrahim Abdallah Mohamed Baraka
].freeze

BUSINESS_SUFFIXES = [
  "Shop", "Store", "Boutique", "Traders", "Enterprises", "Supplies",
  "Collections", "Fashion", "Designs", "Beauty", "Naturals", "Style",
  "Hub", "Point", "Centre", "Market", "Palace", "Kingdom", "World", "Place"
].freeze

NAIROBI_LOCATIONS = [
  "Westlands, Nairobi", "Kilimani, Nairobi", "CBD, Nairobi", "Ngong Road, Nairobi",
  "Gikomba, Nairobi", "Eastleigh, Nairobi", "South B, Nairobi", "South C, Nairobi",
  "Kasarani, Nairobi", "Ruiru, Kiambu", "Thika Road, Nairobi", "Lang'ata, Nairobi",
  "Karen, Nairobi", "Lavington, Nairobi", "Parklands, Nairobi", "Buruburu, Nairobi",
  "Umoja, Nairobi", "Donholm, Nairobi", "Embakasi, Nairobi", "Kayole, Nairobi",
  "Kikuyu, Kiambu", "Limuru, Kiambu", "Kitengela, Kajiado", "Rongai, Kajiado",
  "Ngong, Kajiado", "Athi River, Machakos", "Mombasa Road, Nairobi",
  "Upperhill, Nairobi", "Hurlingham, Nairobi", "Industrial Area, Nairobi"
].freeze

INDUSTRIES = Lead::INDUSTRIES.keys.map(&:to_s).freeze
STATUSES   = Lead::STATUSES.keys.map(&:to_s).freeze
SOURCES    = Lead::SOURCES.keys.map(&:to_s).freeze
TEMPS      = Lead::TEMPERATURES.keys.map(&:to_s).freeze

def random_phone(index)
  base = 700_000_100 + index
  "+254 #{base.to_s[0..2]} #{base.to_s[3..5]} #{base.to_s[6..]}"
end

def random_handle(business_name, suffix)
  base = business_name.downcase.gsub(/[^a-z0-9]/, "")
  "#{base}#{suffix}"
end

rng = Random.new(42)

200.times do |i|
  first  = LEAD_FIRST_NAMES[rng.rand(LEAD_FIRST_NAMES.size)]
  last   = LEAD_LAST_NAMES[rng.rand(LEAD_LAST_NAMES.size)]
  suffix = BUSINESS_SUFFIXES[rng.rand(BUSINESS_SUFFIXES.size)]
  biz    = "#{first} #{last} #{suffix}"

  next if Lead.exists?(business_name: biz)

  industry   = INDUSTRIES[rng.rand(INDUSTRIES.size)]
  location   = NAIROBI_LOCATIONS[rng.rand(NAIROBI_LOCATIONS.size)]
  source     = SOURCES[rng.rand(SOURCES.size)]
  temp       = TEMPS[rng.rand(TEMPS.size)]
  phone      = random_phone(i)

  non_terminal = STATUSES - %w[lost won]
  terminal     = %w[lost won]
  status_pool  = non_terminal * 4 + terminal
  status       = status_pool[rng.rand(status_pool.size)]

  lost_reason = status == "lost" ? Lead::LOST_REASONS.keys.map(&:to_s).sample(random: rng) : nil
  invoice_sent_at = status == "invoice_sent" ? (rng.rand(30) + 1).days.ago : nil
  converted_at = %w[won].include?(status) ? (rng.rand(14) + 1).days.ago : nil

  has_instagram = rng.rand < 0.5
  has_tiktok    = rng.rand < 0.3

  lead = Lead.new(
    business_name:    biz,
    industry:         industry,
    location:         location,
    source:           source,
    temperature:      temp,
    status:           status,
    lost_reason:      lost_reason,
    invoice_sent_at:  invoice_sent_at,
    converted_at:     converted_at,
    instagram_handle: has_instagram ? random_handle(biz, rng.rand(999)) : nil,
    tiktok_handle:    has_tiktok    ? random_handle(biz, rng.rand(999)) : nil
  )

  lead.lead_contacts.build(
    name:  "#{first} #{last}",
    phone: phone,
    email: rng.rand < 0.6 ? "#{first.downcase}.#{last.downcase}#{i}@gmail.com" : nil,
    role:  "Owner"
  )

  if rng.rand < 0.3
    second_first = LEAD_FIRST_NAMES[rng.rand(LEAD_FIRST_NAMES.size)]
    second_last  = LEAD_LAST_NAMES[rng.rand(LEAD_LAST_NAMES.size)]
    lead.lead_contacts.build(
      name:  "#{second_first} #{second_last}",
      phone: random_phone(i + 10_000),
      role:  "Manager"
    )
  end

  lead.save!
end
