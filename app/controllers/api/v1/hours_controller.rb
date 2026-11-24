module Api
  module V1
    # Everyone in the account can read hours (like Reports); changes are
    # limited to your own entries (like the UI). Invoiced entries are locked.
    class HoursController < BaseController
      def index
        scope = Hour.includes(:tags).order(date: :desc, id: :desc)
        scope = scope.where(user_id: params[:user_id] == "me" ? current_user.id : params[:user_id]) if params[:user_id]
        scope = scope.where(project_id: params[:project_id]) if params[:project_id]
        scope = scope.where(date: parse_date(:from)..) if params[:from]
        scope = scope.where(date: ..parse_date(:to)) if params[:to]
        scope = scope.where(billed: params[:billed] == "true") if params.key?(:billed)
        render json: paginate(scope).map { |hour| ApiSerializer.hour(hour) }
      end

      def show
        render json: ApiSerializer.hour(Hour.find(params[:id]))
      end

      def create
        hour = current_user.hours.build(hour_params)
        hour.date ||= Date.current
        if hour.save
          render json: ApiSerializer.hour(hour), status: :created, location: api_v1_hour_url(hour)
        else
          render_invalid(hour)
        end
      end

      def update
        hour = current_user.hours.find(params[:id])
        hour.update(hour_params) ? render(json: ApiSerializer.hour(hour)) : render_invalid(hour)
      end

      def destroy
        hour = current_user.hours.find(params[:id])
        hour.destroy ? head(:no_content) : render_invalid(hour)
      end

      private

      def hour_params
        attrs = params.require(:hour).permit(:project_id, :category_id, :hours, :date, :description)
        attrs[:value] = attrs.delete(:hours) if attrs.key?(:hours)
        attrs
      end

      def parse_date(key)
        Date.iso8601(params[key].to_s)
      rescue Date::Error
        raise ActionController::ParameterMissing, "#{key} must be a date (YYYY-MM-DD)"
      end
    end
  end
end
