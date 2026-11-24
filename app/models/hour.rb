# == Schema Information
#
# Table name: hours
#
#  id          :integer          not null, primary key
#  project_id  :integer          not null
#  category_id :integer          not null
#  user_id     :integer          not null
#  value       :decimal(6, 2)    not null
#  date        :date             not null
#  created_at  :datetime
#  updated_at  :datetime
#  description :string
#  billed      :boolean          default("false")
#

class Hour < Entry
  audited allow_mass_assignment: true

  belongs_to :category

  has_many :taggings, inverse_of: :hour
  has_many :tags, through: :taggings

  validates :category, presence: true
  validates :value, numericality: { greater_than: 0, less_than_or_equal_to: 24 }
  validate :value_in_quarter_hours

  # 3 rather than 3.0; see HoursValue.
  def value
    HoursValue.normalize(super)
  end

  accepts_nested_attributes_for :taggings

  scope :by_last_created_at, -> { order("created_at DESC") }
  scope :by_date, -> { order("date DESC") }
  scope :billable, -> { where("billable").joins(:project) }
  scope :with_clients, lambda {
    where.not("projects.client_id" => nil).joins(:project)
  }

  before_save :set_tags_from_description
  after_create_commit -> { BroadcastActivityJob.perform_later(self) }

  def tag_list
    tags.map(&:name).join(", ")
  end

  def self.query(params, includes = nil)
    EntryQuery.new(self.includes(includes).by_date, params, "hours").filter
  end

  private

  def value_in_quarter_hours
    raw = read_attribute(:value)
    return if raw.nil? || (raw % HoursValue::STEP).zero?

    errors.add(:value, :quarter_hours)
  end

  def set_tags_from_description
    tagnames = extract_hashtags(description)
    self.tags = tagnames.map do |tagname|
      Tag.where("name ILIKE ?", tagname.strip).first_or_initialize.tap do |tag|
        tag.name = tagname.strip
        tag.save!
      end
    end
  end
end
