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
    @total_hours_spent ||= hours.sum(:value)
  end

  def label
    name
  end

  def budget_status
    budget - total_hours_spent if budget
  end


  private

  def hours_per_category
    @hours_per_category ||= hours.group(:category_id).sum(:value)
  end

  def slug_source
    name
  end
end
