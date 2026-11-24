module Api
  module V1
    # The signed-in user's timer: same rules as the dashboard timer.
    class TimersController < BaseController
      def show
        timer = current_user.timer
        timer ? render(json: ApiSerializer.timer(timer)) : render_error(:not_found, "no_timer", "No timer is running")
      end

      def create
        return render_error(:conflict, "timer_running", I18n.t("timers.already_running")) if current_user.timer

        timer = Timer.new(params.require(:timer).permit(:project_id, :category_id, :description)
                                .merge(user: current_user, started_at: Time.current))
        timer.save ? render(json: ApiSerializer.timer(timer), status: :created) : render_invalid(timer)
      end

      def stop
        timer = current_user.timer or return render_error(:not_found, "no_timer", "No timer is running")
        hour = timer.stop!
        hour.persisted? ? render(json: ApiSerializer.hour(hour), status: :created) : render_invalid(hour)
      end

      def destroy
        current_user.timer&.destroy
        head :no_content
      end
    end
  end
end
