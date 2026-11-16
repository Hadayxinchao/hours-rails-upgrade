# frozen_string_literal: true

class EntryQuery
  # Only these keys may be applied. The keys come straight from URL params,
  # so they must never be used to pick an arbitrary method to call.
  FILTERS = EntryFilter::KEYS

  # entry_type is kept for API compatibility; the table name now comes from
  # the relation itself instead of module-level (thread-unsafe) state.
  def initialize(entries, params, _entry_type = nil)
    @entries = entries.extending(Scopes)
    @params = params
  end

  def filter
    filter_params.reduce(entries) do |result, (filter, value)|
      present?(value) ? result.public_send(filter, value) : result
    end
  end

  private

  attr_reader :entries, :params

  def filter_params
    return {} unless params

    hash = params.respond_to?(:permit) ? params.permit(*FILTERS).to_h : params.to_h
    hash.symbolize_keys.slice(*FILTERS).compact
  end

  def present?(value)
    value != "" && !value.nil?
  end

  module Scopes
    def client_id(param)
      joins(:project).where(projects: { client_id: param })
    end

    def project_id(param)
      where(project_id: param)
    end

    def user(param)
      where(user_id: param)
    end

    def billed(param)
      where(billed: param)
    end

    def from_date(param)
      where(arel_table[:date].gteq(Date.parse(param.to_s)))
    end

    def to_date(param)
      where(arel_table[:date].lteq(Date.parse(param.to_s)))
    end

    def archived(param)
      joins(:project).where(projects: { archived: param })
    end

    def billable(param)
      joins(:project).where(projects: { billable: param })
    end
  end
end
