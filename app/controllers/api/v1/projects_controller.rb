module Api
  module V1
    class ProjectsController < BaseController
      def index
        scope = Project.includes(:client).by_name
        scope = scope.unarchived unless params[:archived] == "true"
        render json: paginate(scope).map { |project| ApiSerializer.project(project) }
      end

      def show
        render json: ApiSerializer.project(Project.find(params[:id]))
      end
    end
  end
end
