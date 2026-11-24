# A budget threshold that has been reached and reported for a project. The
# unique index makes sending each alert at most once, even when two entries
# are saved at the same moment.
class BudgetAlert < ApplicationRecord
  KINDS = %w[hours amount].freeze
  THRESHOLDS = [80, 100].freeze

  belongs_to :project

  validates :kind, inclusion: { in: KINDS }
  validates :threshold, inclusion: { in: THRESHOLDS }
end
