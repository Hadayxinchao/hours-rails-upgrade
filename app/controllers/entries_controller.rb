class EntriesController < ApplicationController
  include CSVDownload

  DATE_FORMAT = "%d/%m/%Y".freeze

  def index
    @user = User.find_by_slug(params[:user_id])
    @hours_entries = @user.hours.by_date.page(params[:hours_pages]).per(20)
    @mileages_entries = @user.mileages.by_date.page(
      params[:mileages_pages]
    ).per(20)

    respond_to do |format|
      format.html { @mileages_entries + @hours_entries }
      format.csv do
        send_csv(
          name: @user.name,
          hours_entries: @user.hours.by_date,
          mileages_entries: @user.mileages.by_date
        )
      end
    end
  end

  def destroy
    message = if resource.destroy
                { notice: t("entry_deleted.#{controller_name}") }
              else
                { alert: resource.errors.full_messages.to_sentence }
              end
    redirect_to user_entries_path(current_user) + "##{controller_name}", **message
  end

  def edit
    @entry_type = set_entry_type
  end

  private

  def update_failed_message
    resource.errors.full_messages.to_sentence.presence || t("entry_failed")
  end

  def set_entry_type
    params[:controller]
  end

  # The classic forms send dd/mm/yyyy; date inputs (inline editing) send ISO.
  def parsed_date(entry_type)
    value = params[entry_type][:date].to_s
    return Date.iso8601(value) if value.match?(/\A\d{4}-\d{2}-\d{2}\z/)

    Date.strptime(value, DATE_FORMAT)
  end
end
