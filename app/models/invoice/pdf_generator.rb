# frozen_string_literal: true

class Invoice::PdfGenerator
  BRAND_GREEN   = "31DE79"
  DARK_TEXT     = "111111"
  MID_GRAY      = "3A3A3A"
  BORDER_BLACK  = "111111"
  PAPER_GRAY    = "FFFFFF"
  BODY_SIZE     = 13.2
  STAMP_RED     = "E01E2E"

  def initialize(invoice)
    @invoice = invoice
  end

  def render
    doc = Prawn::Document.new(page_size: "A4", margin: [16, 16, 16, 16])
    configure_fonts(doc)
    doc.font(@body_font)
    draw_page_shell(doc)
    row_y = draw_line_items(doc)
    draw_summary_and_footer(doc, row_y)
    doc.render
  end

  private

  def draw_background(pdf)
    pdf.fill_color PAPER_GRAY
    pdf.fill_rectangle [0, pdf.bounds.top], pdf.bounds.width, pdf.bounds.height

    pdf.stroke_color BORDER_BLACK
    pdf.line_width 1
    pdf.stroke_rectangle [0, pdf.bounds.top], pdf.bounds.width, pdf.bounds.height
    pdf.fill_color DARK_TEXT
  end

  def draw_header(pdf)
    top = pdf.bounds.top
    header_height = 104
    logo_width = 150

    pdf.stroke_color BORDER_BLACK
    pdf.line_width 0.7
    pdf.stroke_vertical_line top, top - header_height, at: logo_width

    pdf.fill_color BRAND_GREEN
    with_logo_font(pdf) do
      pdf.text_box "NAMARUNU",
                   at: [10, top - 38], width: logo_width - 20, height: 28,
                   size: 18, align: :center, valign: :center
    end

    pdf.fill_color DARK_TEXT
    pdf.text_box "NAMARUNU SOLUTIONS",
                 at: [logo_width + 24, top - 20], width: 320, height: 22,
                 size: 16, character_spacing: 1.4

    pdf.fill_color BRAND_GREEN
    pdf.text_box "HELPING BUSINESSES GROW",
                 at: [logo_width + 24, top - 42], width: 320, height: 16,
                 size: 10.5, style: :bold, character_spacing: 1.7

    pdf.fill_color MID_GRAY
    pdf.text_box "NAMARUNU@GMAIL.COM / WWW.NAMARUNU.COM",
                 at: [logo_width + 24, top - 61], width: 340, height: 12,
                 size: 5.9, character_spacing: 0.8

    y = top - header_height
    pdf.stroke_color BORDER_BLACK
    pdf.line_width 3
    pdf.stroke_horizontal_line 0, pdf.bounds.width, at: y
  end

  def draw_invoice_meta(pdf)
    base_y = pdf.bounds.top - 136
    left_x = 46
    right_x = pdf.bounds.width / 2 + 16

    pdf.fill_color DARK_TEXT
    pdf.font(@body_font) do
      pdf.text_box "INVOICE NUMBER", at: [left_x, base_y], width: 260, height: 16,
                   size: BODY_SIZE, style: :bold, character_spacing: 1.2
      pdf.text_box @invoice.invoice_number.to_s, at: [left_x, base_y - 20], width: 260, height: 16,
                   size: BODY_SIZE
    end

    row_y = base_y - 58
    pdf.font(@body_font) do
      pdf.text_box "DATE ISSUED", at: [left_x, row_y], width: 260, height: 16,
                   size: BODY_SIZE, style: :bold, character_spacing: 1.2
      pdf.text_box "ISSUED TO", at: [right_x, row_y], width: 260, height: 16,
                   size: BODY_SIZE, style: :bold, character_spacing: 1.2

      pdf.text_box issued_date, at: [left_x, row_y - 20], width: 260, height: 16, size: BODY_SIZE
      pdf.text_box @invoice.recipient_name.to_s, at: [right_x, row_y - 20], width: 260, height: 16, size: BODY_SIZE
    end

    table_top = row_y - 44
    pdf.stroke_color BORDER_BLACK
    pdf.line_width 1.3
    pdf.stroke_horizontal_line left_x, pdf.bounds.width - 66, at: table_top

    header_y = table_top - 20
    pdf.font(@body_font) do
      pdf.text_box "SERVICE DESCRIPTION", at: [left_x, header_y], width: 240, height: 16,
                   size: BODY_SIZE, style: :bold, character_spacing: 0.8
      pdf.text_box "QTY", at: [336, header_y], width: 34, height: 16,
                   size: BODY_SIZE, style: :bold, character_spacing: 0.8
      pdf.text_box "PRICE", at: [388, header_y], width: 48, height: 16,
                   size: BODY_SIZE, style: :bold, character_spacing: 0.8
      pdf.text_box "TOTAL", at: [446, header_y], width: 48, height: 16,
                   size: BODY_SIZE, style: :bold, character_spacing: 0.8
    end
    @line_item_y = header_y - 36
  end

  def draw_line_items(pdf)
    left_x = 46
    row_y = @line_item_y || (pdf.bounds.top - 280)
    row_height = 20
    min_row_y = footer_bar_top(pdf) + 22

    line_items = @invoice.line_items.presence || [fallback_line_item]

    pdf.fill_color DARK_TEXT
    pdf.font(@body_font) do
      line_items.each do |line_item|
        if (row_y - row_height) < min_row_y
          draw_bottom_bar(pdf)
          draw_page_shell(pdf, new_page: true)
          row_y = @line_item_y
        end

        description = line_item.description.to_s.presence || "Invoice item"
        qty = line_item.quantity.to_i
        qty = 1 if qty <= 0
        unit_amount = line_item.unit_amount_cents.to_i
        amount = line_item.amount_cents.to_i

        pdf.text_box description, at: [left_x, row_y], width: 250, height: 16, size: BODY_SIZE
        pdf.text_box qty.to_s, at: [336, row_y], width: 34, height: 16, size: BODY_SIZE
        pdf.text_box plain_amount(unit_amount), at: [388, row_y], width: 48, height: 16, size: BODY_SIZE
        pdf.text_box plain_amount(amount), at: [446, row_y], width: 52, height: 16, size: BODY_SIZE

        row_y -= row_height
      end
    end
    row_y
  end

  def fallback_line_item
    Invoice::LineItem.new(
      description: "Invoice item",
      quantity: 1,
      unit_amount_cents: @invoice.total_cents.to_i,
      amount_cents: @invoice.total_cents.to_i
    )
  end

  def draw_payment_info(pdf)
    pdf.fill_color DARK_TEXT

    lines = [
      { text: "Bank name: Equity bank", style: :normal },
      { text: "Account no: 1450286637983", style: :normal },
      { text: "Account Name: Namarunu Solutions Ltd", style: :normal },
      { text: "", style: :normal },
      { text: "or", style: :bold },
      { text: "", style: :normal },
      { text: "Paybill: 247247", style: :normal },
      { text: "Account no: 714247", style: :normal }
    ]

    line_step = 17
    blank_step = 10
    footer_safe_gap = 38
    min_last_line_y = footer_bar_top(pdf) + footer_safe_gap
    steps_before_last = lines[0...-1].sum { |line| line[:text].empty? ? blank_step : line_step }
    default_start_y = pdf.bounds.bottom + 138
    row_y = [default_start_y, min_last_line_y + steps_before_last].max
    payment_section_top_y = row_y + 22

    pdf.font(@body_font, style: :bold) do
      pdf.text_box "Payments can be made here:", at: [56, payment_section_top_y], width: 260, height: 16,
                   size: 12
    end

    lines.each do |line|
      if line[:text].empty?
        row_y -= blank_step
        next
      end

      pdf.font(@body_font, style: line[:style]) do
        pdf.text_box line[:text], at: [56, row_y], width: 320, height: 16, size: 12
      end
      row_y -= line_step
    end
    payment_section_top_y
  end

  def draw_summary_and_footer(pdf, row_y)
    row_y = ensure_summary_space(pdf, row_y)
    summary_line = draw_totals_line(pdf, row_y)
    payment_section_top_y = payment_title_y(pdf)
    draw_paid_stamp(pdf, gap_top_y: summary_line - 18, gap_bottom_y: payment_section_top_y)
    draw_payment_info(pdf)
    draw_bottom_bar(pdf)
  end

  def ensure_summary_space(pdf, row_y)
    min_gap_for_stamp = 126
    summary_line = row_y - 8
    return row_y if (summary_line - payment_title_y(pdf)) >= min_gap_for_stamp

    draw_bottom_bar(pdf)
    draw_page_shell(pdf, new_page: true)
    @line_item_y
  end

  def draw_totals_line(pdf, row_y)
    left_x = 46
    summary_line = row_y - 8

    pdf.stroke_color BORDER_BLACK
    pdf.line_width 1.8
    pdf.stroke_horizontal_line left_x, pdf.bounds.width - 66, at: summary_line

    pdf.fill_color DARK_TEXT
    pdf.font(@body_font, style: :bold) do
      pdf.text_box "TOTAL", at: [352, summary_line - 18], width: 54, height: 16,
                   size: BODY_SIZE, style: :bold, character_spacing: 0.8
      pdf.text_box currency_total(@invoice.total_cents), at: [432, summary_line - 18], width: 120, height: 16,
                   size: BODY_SIZE, style: :bold
    end

    summary_line
  end

  def draw_paid_stamp(pdf, gap_top_y:, gap_bottom_y:)
    return unless @invoice.status.to_s == "paid"
    return unless gap_top_y && gap_bottom_y

    center_x = pdf.bounds.width / 2.0
    center_y = (gap_top_y + gap_bottom_y) / 2.0
    width = 220
    height = 88
    x = center_x - (width / 2.0)
    y = center_y + (height / 2.0)

    pdf.save_graphics_state do
      pdf.rotate(14, origin: [center_x, center_y]) do
        pdf.fill_color "FFFFFF"
        pdf.fill_rectangle [x, y], width, height

        pdf.stroke_color STAMP_RED
        pdf.line_width 4
        pdf.stroke_rectangle [x, y], width, height
        pdf.line_width 1.5
        pdf.stroke_rectangle [x + 8, y - 8], width - 16, height - 16

        pdf.fill_color STAMP_RED
        pdf.font(@body_font, style: :bold) do
          stamp_text = "PAID"
          stamp_size = 44
          text_width = pdf.width_of(stamp_text, size: stamp_size, character_spacing: 1.8)
          text_x = x + ((width - text_width) / 2.0)
          text_y = y - (height / 2.0) - (stamp_size * 0.30)

          pdf.draw_text stamp_text,
                        at: [text_x, text_y],
                        size: stamp_size,
                        character_spacing: 1.8
        end
      end
    end

    pdf.fill_color DARK_TEXT
    pdf.stroke_color BORDER_BLACK
    pdf.line_width 1
  end

  def draw_bottom_bar(pdf)
    pdf.fill_color BRAND_GREEN
    pdf.fill_rectangle [0, footer_bar_top(pdf)], pdf.bounds.width, footer_bar_height

    pdf.fill_color "FFFFFF"
    pdf.font(@thanks_font, style: :bold) do
      pdf.text_box "Thank you!",
                   at: [0, footer_bar_top(pdf) - 17], width: pdf.bounds.width, height: 28,
                   size: 20, align: :center, valign: :center
    end

    pdf.fill_color DARK_TEXT
  end

  def draw_page_shell(pdf, new_page: false)
    pdf.start_new_page if new_page
    draw_background(pdf)
    draw_header(pdf)
    draw_invoice_meta(pdf)
  end

  def footer_bar_height
    62
  end

  def footer_bar_top(pdf)
    pdf.bounds.bottom + footer_bar_height
  end

  def payment_title_y(pdf)
    line_step = 17
    blank_step = 10
    footer_safe_gap = 38
    lines = 8
    blank_lines = 2
    steps_before_last = ((lines - 1 - blank_lines) * line_step) + (blank_lines * blank_step)
    min_last_line_y = footer_bar_top(pdf) + footer_safe_gap
    default_start_y = pdf.bounds.bottom + 138
    first_line_y = [default_start_y, min_last_line_y + steps_before_last].max
    first_line_y + 22
  end

  def configure_fonts(pdf)
    body_normal = first_existing_path(
      "app/assets/fonts/Raleway-Regular.ttf",
      "app/assets/fonts/Raleway-VariableFont_wght.ttf",
      "app/assets/fonts/raleway/Raleway-Regular.ttf",
      "app/assets/fonts/raleway/Raleway-VariableFont_wght.ttf",
      "/usr/share/fonts/truetype/raleway/Raleway-Regular.ttf",
      "/usr/share/fonts/raleway/Raleway-Regular.ttf",
      "/usr/local/share/fonts/Raleway-Regular.ttf",
      File.expand_path("~/.local/share/fonts/Raleway-Regular.ttf")
    )

    body_bold = first_existing_path(
      "app/assets/fonts/Raleway-Bold.ttf",
      "app/assets/fonts/Raleway-VariableFont_wght.ttf",
      "app/assets/fonts/raleway/Raleway-Bold.ttf",
      "app/assets/fonts/raleway/Raleway-VariableFont_wght.ttf",
      "/usr/share/fonts/truetype/raleway/Raleway-Bold.ttf",
      "/usr/share/fonts/raleway/Raleway-Bold.ttf",
      "/usr/local/share/fonts/Raleway-Bold.ttf",
      File.expand_path("~/.local/share/fonts/Raleway-Bold.ttf")
    ) || body_normal

    if body_normal
      pdf.font_families.update(
        "RalewayCustom" => {
          normal: body_normal,
          bold: body_bold,
          italic: body_normal,
          bold_italic: body_bold
        }
      )
      @body_font = "RalewayCustom"
    else
      @body_font = "Helvetica"
    end

    logo = first_existing_path(
      "app/assets/fonts/ArchivoBlack-Regular.ttf",
      "app/assets/fonts/archivo-black/ArchivoBlack-Regular.ttf",
      "/usr/share/fonts/truetype/archivo-black/ArchivoBlack-Regular.ttf",
      "/usr/share/fonts/archivo-black/ArchivoBlack-Regular.ttf",
      "/usr/local/share/fonts/ArchivoBlack-Regular.ttf",
      File.expand_path("~/.local/share/fonts/ArchivoBlack-Regular.ttf")
    )

    if logo
      pdf.font_families.update(
        "ArchivoBlackCustom" => {
          normal: logo,
          bold: logo,
          italic: logo,
          bold_italic: logo
        }
      )
      @logo_font = "ArchivoBlackCustom"
    else
      @logo_font = @body_font
    end

    thanks_regular = first_existing_path(
      "app/assets/fonts/AbhayaLibre-Regular.ttf",
      "app/assets/fonts/abhaya-libre/AbhayaLibre-Regular.ttf"
    )

    thanks_bold = first_existing_path(
      "app/assets/fonts/AbhayaLibre-Bold.ttf",
      "app/assets/fonts/AbhayaLibre-ExtraBold.ttf",
      "app/assets/fonts/abhaya-libre/AbhayaLibre-Bold.ttf",
      "app/assets/fonts/abhaya-libre/AbhayaLibre-ExtraBold.ttf"
    )

    if thanks_regular || thanks_bold
      regular = thanks_regular || thanks_bold
      bold = thanks_bold || thanks_regular
      pdf.font_families.update(
        "AbhayaLibreCustom" => {
          normal: regular,
          bold: bold,
          italic: regular,
          bold_italic: bold
        }
      )
      @thanks_font = "AbhayaLibreCustom"
    else
      @thanks_font = @body_font
    end
  end

  def with_logo_font(pdf, &block)
    pdf.font(@logo_font, &block)
  end

  def first_existing_path(*paths)
    paths.find { |path| valid_font_file?(path) }
  end

  def valid_font_file?(path)
    return false unless File.exist?(path)
    return false unless path.downcase.end_with?(".ttf", ".otf")

    File.size(path) > 1024
  end

  def issued_date
    date = @invoice.issued_at&.to_date || @invoice.created_at.to_date
    "#{date.day.ordinalize} #{date.strftime('%B %Y')}"
  end

  def plain_amount(cents)
    amount = cents.to_i / 100.0
    format("%.0f", amount)
  end

  def currency_total(cents)
    amount = cents.to_i / 100.0
    case @invoice.currency
    when "KES"
      "KES #{with_delimiter(amount.to_i)}"
    when "USD"
      "USD #{with_delimiter(amount.to_i)}"
    when "TZS"
      "TZS #{with_delimiter(amount.to_i)}"
    else
      "#{@invoice.currency} #{with_delimiter(amount.to_i)}"
    end
  end

  def with_delimiter(number)
    number.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\1,').reverse
  end
end
