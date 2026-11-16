# frozen_string_literal: true

# == Schema Information
#
# Table name: clients
#
#  id                :integer          not null, primary key
#  name              :string           default(""), not null
#  description       :string           default("")
#  logo_file_name    :string
#  logo_content_type :string
#  logo_file_size    :integer
#  logo_updated_at   :datetime
#  created_at        :datetime
#  updated_at        :datetime
#

class Client < ApplicationRecord
  validates :name, presence: true,
                   uniqueness: { case_sensitive: false }
  scope :by_name, -> { order(Arel.sql("lower(name)")) }
  scope :by_last_updated, -> { order("clients.updated_at DESC") }
  has_many :projects

  has_many :hours, through: :projects
  has_many :mileages, through: :projects

  LOGO_CONTENT_TYPES = %w[image/png image/jpeg image/gif image/webp].freeze

  has_one_attached :logo
  validate :logo_must_be_an_image

  # 100x100 square crop, same as the old Paperclip "100x100#" style.
  def logo_thumbnail
    logo.variant(resize_to_fill: [100, 100])
  end

  private

  def logo_must_be_an_image
    return unless logo.attached?
    return if LOGO_CONTENT_TYPES.include?(logo.content_type)

    errors.add(:logo, :invalid)
  end
end
