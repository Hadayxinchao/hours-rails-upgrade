# Renders an invoice as PDF with Prawn (pure Ruby; no headless browser).
# DejaVu Sans covers Latin-extended names (e.g. Vietnamese) and currency
# symbols such as ₫; Helvetica is the fallback when the font isn't installed.
class InvoicePdf
  FONT_DIR = "/usr/share/fonts/truetype/dejavu".freeze
  GREY = "777777".freeze

  def initialize(invoice)
    @invoice = invoice
    @currency = invoice.currency
  end

  def render
    pdf = Prawn::Document.new(page_size: "A4", margin: 48, info: { Title: "Invoice #{@invoice.number}" })
    setup_font(pdf)
    header(pdf)
    lines(pdf)
    totals(pdf)
    footer(pdf)
    pdf.render
  end

  private

  def setup_font(pdf)
    regular = File.join(FONT_DIR, "DejaVuSans.ttf")
    return unless File.exist?(regular)

    pdf.font_families.update("DejaVu" => { normal: regular, bold: File.join(FONT_DIR, "DejaVuSans-Bold.ttf") })
    pdf.font "DejaVu"
  end

  def header(pdf)
    pdf.text "INVOICE", size: 22, style: :bold
    pdf.text @invoice.number, size: 12, color: GREY
    if @invoice.void?
      pdf.move_down 4
      pdf.text "VOID", size: 14, style: :bold, color: "B00020"
    end
    pdf.move_down 18
    pdf.table([
      [t("bill_to"), @invoice.client.name],
      [t("issued_on"), I18n.l(@invoice.issued_on)],
      [t("due_on"), I18n.l(@invoice.due_on)]
    ], cell_style: { borders: [], padding: [2, 12, 2, 0], size: 10 }) do |table|
      table.column(0).text_color = GREY
    end
    pdf.move_down 20
  end

  def lines(pdf)
    rows = [[t("description"), t("quantity"), t("unit_price"), t("amount")]]
    @invoice.lines.each do |line|
      rows << [line.description, quantity(line.quantity), money(line.unit_price_cents), money(line.amount_cents)]
    end
    pdf.table(rows, header: true, width: pdf.bounds.width, column_widths: { 1 => 60, 2 => 90, 3 => 100 },
                    cell_style: { size: 10, padding: [6, 6], borders: [:bottom], border_color: "DDDDDD" }) do |table|
      table.row(0).font_style = :bold
      table.row(0).border_color = "999999"
      table.columns(1..3).align = :right
    end
  end

  def totals(pdf)
    rows = [[t("subtotal"), money(@invoice.subtotal_cents)]]
    if @invoice.tax_rate.positive?
      rate = @invoice.tax_rate.to_s("F").sub(/\.0+\z/, "")
      rows << [I18n.t("invoices.fields.tax", rate: rate), money(@invoice.tax_cents)]
    end
    rows << [t("total"), money(@invoice.total_cents)]
    pdf.move_down 10
    pdf.table(rows, position: :right, column_widths: [140, 100],
                    cell_style: { size: 10, padding: [3, 6], borders: [], align: :right }) do |table|
      table.row(-1).font_style = :bold
      table.row(-1).size = 12
    end
  end

  def footer(pdf)
    return if @invoice.notes.blank?

    pdf.move_down 24
    pdf.text t("notes"), size: 10, style: :bold
    pdf.text @invoice.notes, size: 10
  end

  def t(key)
    I18n.t("invoices.fields.#{key}")
  end

  def money(cents)
    Money.format(cents, @currency)
  end

  def quantity(value)
    value.to_s("F").sub(/\.0+\z/, "")
  end
end
