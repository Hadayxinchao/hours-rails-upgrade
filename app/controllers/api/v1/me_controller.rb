module Api
  module V1
    class MeController < BaseController
      def show
        render json: ApiSerializer.user(current_user)
      end
    end
  end
end
