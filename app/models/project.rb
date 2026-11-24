# frozen_string_literal: true

# == Schema Information
#
# Table name: projects
#
#  id          :integer          not null, primary key
#  name        :string           default(""), not null
#  created_at  :datetime
#  updated_at  :datetime
#  slug        :string
#  budget      :integer
#  billable    :boolean          default("false")
#  client_id   :integer
#  archived    :boolean          default("false"), not null
#  description :text
#

class Project < ApplicationRecord
  include Sluggable
  include MoneyAttribute

  audited allow_mass_assignment: true

  validates :name, presence: true,
                   uniqueness: { case_sensitive: false }
  validates_with ClientBillableValidator
  has_many :hours
  has_many :mileages
  has_many :users, -> { distinct }, through: :hours
  has_many :categories, -> { distinct }, through: :hours
  has_many :tags, -> { distinct }, through: :hours
  belongs_to :client, touch: true

  # Rates are in the client's currency (see docs/phase-2/PLAN.md).
  money_attribute :hourly_rate
  money_attribute :mileage_rate
  money_attribute :budget_amount

  has_many :budget_alerts, dependent: :delete_all

  # Re-check budgets when a budget or rate changes. The change is noted in
  # after_update, not read at commit time: a later touch (an entry saved in the
  # same transaction) leaves the previous save's saved_changes in place.
  BUDGET_INPUTS = %w[budget budget_amount_cents hourly_rate_cents mileage_rate_cents].freeze
  after_update { @budget_inputs_changed = true if (saved_changes.keys & BUDGET_INPUTS).any? }
  after_commit do
    BudgetCheckJob.perform_later(self) if @budget_inputs_changed
    @budget_inputs_changed = false
  end

  scope :by_last_updated, -> { order("projects.updated_at DESC") }
  scope :by_name, -> { order(Arel.sql("lower(name)")) }

  scope :are_archived, -> { where(archived: true) }
  scope :unarchived, -> { where(archived: false) }
  scope :billable, -> { where(billable: true) }

  # Same ordering as before (rounded share of hours, descending), but computed
  # from one GROUP BY query per project instead of two SUM queries per
  # category every time it was called (~780 queries on the dashboard).
  def sorted_categories
    @sorted_categories ||= categories.sort_by do |category|
      percentage_for_category(category)
    end.reverse
  end

  # category may be a Category or a RemainingCategory (several ids).
  def hours_for_category(category)
    ids = category.respond_to?(:ids) ? category.ids : [category.id]
    ids.sum { |id| hours_per_category.fetch(id, 0) }
  end

  def percentage_for_category(category)
    (hours_for_category(category).to_f / total_hours_spent.to_f * 100).round
  end

  def total_hours_spent
    @total_hours_spent ||= HoursValue.normalize(hours.sum(:value))
  end

  def label
    name
  end

  def budget_status
    budget - total_hours_spent if budget
  end

  def money_currency
    client&.currency || "USD"
  end

  # Value of all hours and kilometres at the current rates (minor units), or
  # nil if work was logged without a rate to price it.
  def spent_cents
    hours_total = hours.sum(:value)
    km_total = mileages.sum(:value)
    return nil if (hours_total.positive? && !hourly_rate_cents) || (km_total.positive? && !mileage_rate_cents)

    (BigDecimal(hours_total.to_s) * hourly_rate_cents.to_i + km_total * mileage_rate_cents.to_i)
      .round(0, :half_up).to_i
  end

  def budget_usages
    @budget_usages ||= BudgetUsage.for(self)
  end

  MEMOIZED = %i[@total_hours_spent @hours_per_category @sorted_categories @budget_usages].freeze

  # reload refreshes attributes only; drop the memoized totals as well.
  def reload(*)
    MEMOIZED.each { |ivar| remove_instance_variable(ivar) if instance_variable_defined?(ivar) }
    super
  end


  private

  def hours_per_category
    @hours_per_category ||= HoursValue.normalize_hash(hours.group(:category_id).sum(:value))
  end

  def slug_source
    name
  end
end
