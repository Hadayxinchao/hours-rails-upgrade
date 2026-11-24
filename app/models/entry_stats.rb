class EntryStats
  SUBJECT_COLUMNS = {
    "User" => :user_id,
    "Project" => :project_id,
    "Category" => :category_id
  }.freeze

  def initialize(entries, subject = nil)
    @entries = entries
    @subject = subject
  end

  def percentage_for_subject
    (hours_for_subject.to_f / total_hours.to_f * 100).round
  end

  def hours_for_subject
    HoursValue.normalize(hour_entries_for_subject.sum(:value))
  end

  def total_hours
    HoursValue.normalize(@entries.sum(:value))
  end

  def hours_for_subject_collection(collection)
    collection.map do |subject|
      @subject = subject
      {
        value: hours_for_subject,
        color: subject.label.pastel_color,
        label: subject.label,
        highlight: "gray"
      }
    end
  end

  private

  def hour_entries_for_subject
    if @subject.instance_of?(RemainingCategory)
      @entries.where("category_id in (?)", @subject.ids)
    else
      @entries.where(SUBJECT_COLUMNS.fetch(@subject.class.name) => @subject.id)
    end
  end
end
