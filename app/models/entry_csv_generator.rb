require "csv"

class EntryCSVGenerator
  def self.generate(hours_entries, mileages_entries)
    new(hours_entries, mileages_entries).generate
  end

  # Every row reads the user, project, client (and category for hours).
  # Without preloading that was ~89,000 queries for 23k rows.
  HOURS_INCLUDES = [:user, :category, { project: :client }].freeze
  MILEAGES_INCLUDES = [:user, { project: :client }].freeze

  def initialize(hours_entries, mileages_entries)
    @hours_report = Report.new(preload(hours_entries, HOURS_INCLUDES))
    @mileages_report = Report.new(preload(mileages_entries, MILEAGES_INCLUDES))
  end

  def generate
    CSV.generate(**options) do |csv|
      csv << []
      csv << [I18n.translate("report.headers.hours")]
      fill_fields("hours", csv)
      csv << []
      csv << [I18n.translate("report.headers.mileages")]
      fill_fields("mileages", csv)
    end
  end

  def options
    if I18n.locale.in?(%i[nl de])
      return {
        col_sep: ";"
      }
    end

    { col_sep: "," }
  end

  def preload(entries, associations)
    entries.respond_to?(:includes) ? entries.includes(associations) : entries
  end

  def get_fields(entry, entry_type)
    fields = [entry.date, entry.user, entry.project]
    fields.push [entry.category] if entry_type == "hours"
    fields.push [entry.client, entry.value, entry.billable, entry.billed]
    fields.push [entry.description] if entry_type == "hours"
    fields.flatten
  end

  def fill_fields(entry_type, csv)
    report = instance_variable_get("@#{entry_type}_report")
    csv << report.headers(entry_type)
    report.each_row do |entry|
      csv << get_fields(entry, entry_type)
    end
  end
end
