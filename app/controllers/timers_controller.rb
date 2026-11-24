# Start / stop / discard the current user's timer. Responds with Turbo Streams
# (the timer panel and the navbar indicator are replaced in place) and falls
# back to a redirect for non-Turbo requests.
class TimersController < ApplicationController
  # Not current_user.build_timer: on a has_one that replaces (and, with
  # dependent: :destroy, deletes) a timer that is already running.
  def create
    return respond(alert: t("timers.already_running")) if current_user.timer

    timer = Timer.new(timer_params.merge(user: current_user, started_at: Time.current))
    if timer.save
      respond(notice: t("timers.started"))
    else
      respond(alert: timer.errors.full_messages.to_sentence)
    end
  end

  def stop
    timer = current_user.timer
    return respond(alert: nil) unless timer

    hour = timer.stop!
    if hour.persisted?
      respond(notice: t("timers.logged", hours: hour.value, project: hour.project.name))
    else
      respond(alert: hour.errors.full_messages.to_sentence)
    end
  end

  def destroy
    current_user.timer&.destroy
    respond(notice: t("timers.discarded"))
  end

  private

  def timer_params
    params.require(:timer).permit(:project_id, :category_id, :description)
  end

  def respond(notice: nil, alert: nil)
    current_user.reload
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.replace("timer", partial: "timers/panel",
                                        locals: { timer: current_user.timer, notice: notice, alert: alert }),
          turbo_stream.replace("timer-indicator", partial: "timers/indicator", locals: { timer: current_user.timer })
        ]
      end
      format.html { redirect_to root_path, notice: notice, alert: alert }
    end
  end
end
