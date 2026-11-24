# frozen_string_literal: true

class Entry < ApplicationRecord
  self.abstract_class = true

  include Twitter::Extractor

  validates :user, :project, :date, presence: true
  validates :value, presence: true

  audited allow_mass_assignment: true

  belongs_to :user, touch: true
  belongs_to :project, touch: true

  belongs_to :invoice, optional: true

  # Must come after belongs_to :project (Rails 5.1+ HasManyThroughOrderError).
  has_one :client, through: :project

  # Once an entry is on an invoice, what was invoiced can't change underneath
  # it. Deleting a draft or voiding the invoice releases the entry.
  LOCKED_ATTRIBUTES = %w[value date project_id user_id category_id].freeze

  validate :not_changed_while_invoiced, on: :update

  # Budgets: re-check this project (and the previous one if it was moved).
  after_commit :check_budgets

  def check_budgets
    ids = [project_id, (saved_change_to_project_id || [])[0]].compact.uniq
    Project.where(id: ids).find_each { |project| BudgetCheckJob.perform_later(project) }
  end
  before_destroy :prevent_destroy_while_invoiced

  def invoiced?
    invoice_id.present?
  end

  private

  def not_changed_while_invoiced
    return unless invoice_id_was.present? && invoice_id.present?
    return unless (changed & LOCKED_ATTRIBUTES).any?

    errors.add(:base, :invoiced, number: invoice&.number)
  end

  def prevent_destroy_while_invoiced
    return unless invoiced?

    errors.add(:base, :invoiced, number: invoice&.number)
    throw :abort
  end
end
