class HoursController < EntriesController
  def create
    @entry = Hour.new(entry_params)
    @entry.user = current_user

    if @entry.save
      redirect_to root_path, notice: t("entry_created.hours")
    else
      redirect_to root_path, notice: @entry.errors.full_messages.join(". ")
    end
  end

  # HTML: the full edit page and a redirect, as before. Turbo Stream: the row
  # on "My Entries" is swapped for an inline form and back.
  def update
    saved = resource.update(entry_params)
    respond_to do |format|
      format.turbo_stream { replace_row(saved ? "entries/hour_row" : "entries/hour_edit_row") }
      format.html do
        if saved
          redirect_to user_entries_path(current_user), notice: t("entry_saved")
        else
          redirect_to edit_hour_path(resource), alert: update_failed_message
        end
      end
    end
  end

  def edit
    super
    resource
    respond_to do |format|
      format.turbo_stream { replace_row(params[:cancel] ? "entries/hour_row" : "entries/hour_edit_row") }
      format.html
    end
  end

  private

  def replace_row(partial)
    render turbo_stream: turbo_stream.replace(helpers.dom_id(resource), partial: partial,
                                                                     locals: { entry: resource, editable: true })
  end

  def resource
    @hours_entry ||= current_user.hours.find(params[:id])
  end

  def entry_params
    params.require(:hour)
          .permit(:project_id, :category_id, :value, :description, :date)
          .merge(date: parsed_date(:hour))
  end
end
