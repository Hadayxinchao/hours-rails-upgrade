# frozen_string_literal: true

class Entry < ApplicationRecord
  self.abstract_class = true

  include Twitter::Extractor

  validates :user, :project, :date, presence: true
  validates :value, presence: true, numericality: { greater_than: 0,
                                                    only_integer: true }

  audited allow_mass_assignment: true

  belongs_to :user, touch: true
  belongs_to :project, touch: true

  # Must come after belongs_to :project (Rails 5.1+ HasManyThroughOrderError).
  has_one :client, through: :project
end
