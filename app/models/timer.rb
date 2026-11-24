# The user's running timer. The start time lives on the server, so the timer
# survives reloads, other tabs and other devices; the browser only displays it.
class Timer < ApplicationRecord
  MAX_DURATION = 24.hours

  belongs_to :user
  belongs_to :project
  belongs_to :category

  # Explicit: this app predates belongs_to being required by default.
  validates :user, :project, :category, presence: true
  validates :user_id, uniqueness: true
  validates :started_at, presence: true

  def elapsed(now = Time.current)
    now - started_at
  end

  # Logs the elapsed time (rounded up to the next quarter hour) as an hours
  # entry dated on the day the timer started, and removes the timer.
  # Returns the entry; on failure the timer stays and the entry carries errors.
  def stop!(now = Time.current)
    hour = user.hours.build(project: project, category: category, description: description,
                            date: started_at.in_time_zone.to_date,
                            value: HoursValue.from_seconds(elapsed(now)))
    if elapsed(now) > MAX_DURATION
      hour.errors.add(:base, :timer_too_long)
      return hour
    end

    transaction do
      hour.save!
      destroy!
    end
    hour
  rescue ActiveRecord::RecordInvalid
    hour
  end
end
