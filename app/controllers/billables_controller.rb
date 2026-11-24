class BillablesController < ApplicationController
  # Two queries for all unbilled entries instead of 4+ per project and one
  # per row for the user (was ~1,400 queries on the benchmark data).
  def index
    projects = Project.where(billable: true, archived: false).to_a
    @hours_by_project = Hour.includes(:category, :user, :project)
                            .where(project_id: projects.map(&:id), billed: false)
                            .order(:id).group_by(&:project_id)
    @mileages_by_project = Mileage.includes(:user, :project)
                                  .where(project_id: projects.map(&:id), billed: false)
                                  .order(:id).group_by(&:project_id)
    @projects = projects.select do |project|
      @hours_by_project.key?(project.id) || @mileages_by_project.key?(project.id)
    end
  end

  def bill_entries
    if params[:hours_to_bill]
      Hour.where(id: params[:hours_to_bill]).update_all("billed = true")
    end

    if params[:mileages_to_bill]
      Mileage.where(id: params[:mileages_to_bill]).update_all("billed = true")
    end
    render json: nil, status: 200
  end
end
