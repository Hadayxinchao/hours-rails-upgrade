module Api
  module V1
    class CategoriesController < BaseController
      def index
        render json: Category.by_name.map { |category| ApiSerializer.category(category) }
      end
    end
  end
end
