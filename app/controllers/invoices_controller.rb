class InvoicesController < ApplicationController
  before_action :invoice, only: %i[show destroy mark_sent mark_paid void]

  rescue_from Invoice::InvalidTransition do |error|
    redirect_to invoice_path(@invoice), alert: error.message
  end

  def index
    @invoices = Invoice.includes(:client).recent_first
  end

  def new
    @client = Client.find(params[:client_id])
    load_unbilled_entries
  end

  def create
    @client = Client.find(params[:client_id])
    result = InvoiceBuilder.new(
      @client,
      hour_ids: params[:hour_ids], mileage_ids: params[:mileage_ids],
      issued_on: parse_date(params[:issued_on]), due_in_days: params[:due_in_days].presence || 14,
      tax_rate: params[:tax_rate], notes: params[:notes]
    ).call

    if result.success?
      redirect_to invoice_path(result.invoice),
                  notice: t("invoices.notices.created", number: result.invoice.number)
    else
      @errors = result.errors
      load_unbilled_entries
      render :new, status: :unprocessable_content
    end
  end

  def show
    respond_to do |format|
      format.html
      format.pdf do
        send_data InvoicePdf.new(@invoice).render, filename: "invoice-#{@invoice.number}.pdf",
                                                   type: "application/pdf", disposition: "inline"
      end
    end
  end

  def mark_sent
    @invoice.mark_sent!
    redirect_to invoice_path(@invoice), notice: t("invoices.notices.sent", number: @invoice.number)
  end

  def mark_paid
    @invoice.mark_paid!
    redirect_to invoice_path(@invoice), notice: t("invoices.notices.paid", number: @invoice.number)
  end

  def void
    @invoice.void!
    redirect_to invoice_path(@invoice), notice: t("invoices.notices.void", number: @invoice.number)
  end

  def destroy
    @invoice.destroy_draft!
    redirect_to invoices_path, notice: t("invoices.notices.deleted", number: @invoice.number)
  end

  private

  def invoice
    @invoice ||= Invoice.includes(lines: :project).find(params[:id])
  end

  def load_unbilled_entries
    projects = @client.projects.where(billable: true)
    @hours = Hour.includes(:category, :user, :project)
                 .where(project: projects, billed: false, invoice_id: nil).order(:date, :id)
    @mileages = Mileage.includes(:user, :project)
                       .where(project: projects, billed: false, invoice_id: nil).order(:date, :id)
    @selected_hours = params.key?(:hour_ids) ? params[:hour_ids].map(&:to_i) : @hours.map(&:id)
    @selected_mileages = params.key?(:mileage_ids) ? params[:mileage_ids].map(&:to_i) : @mileages.map(&:id)
  end

  def parse_date(value)
    Date.iso8601(value.to_s)
  rescue Date::Error
    Date.current
  end
end
