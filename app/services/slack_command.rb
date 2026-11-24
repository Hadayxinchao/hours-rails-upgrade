# Parses and runs the text of a /hours command for a linked user. Returns the
# reply text.
#
#   /hours 1.5h booking-app development Fixed reminders #backend
#   /hours 45m order dev
#   /hours start booking-app development Reminder emails
#   /hours stop · /hours status · /hours help
class SlackCommand
  DURATION = /\A(?:(?<h>\d+(?:[.,]\d+)?)h)?(?:(?<m>\d+)m)?\z|\A(?<plain>\d+(?:[.,]\d+)?)\z/i

  def initialize(user, text)
    @user = user
    @words = text.to_s.strip.split(/\s+/)
  end

  def run
    case @words.first&.downcase
    when nil, "help" then t("help")
    when "status" then status
    when "stop" then stop
    when "start" then start(@words.drop(1))
    else log(@words)
    end
  end

  private

  def log(words)
    seconds = duration(words.first) or return t("help")
    project, category, description = resolve(words.drop(1))
    return project if project.is_a?(String) # an error message

    hour = @user.hours.build(project: project, category: category, description: description,
                             date: Date.current, value: HoursValue.from_seconds(seconds))
    return hour.errors.full_messages.to_sentence unless hour.save

    rounded = (seconds % 900).zero? ? "" : t("rounded")
    t("logged", hours: hour.value, project: project.name, category: category.name) + rounded
  end

  def start(words)
    return t("already_running", project: @user.timer.project.name) if @user.timer

    project, category, description = resolve(words)
    return project if project.is_a?(String)

    Timer.create!(user: @user, project: project, category: category, description: description,
                  started_at: Time.current)
    t("started", project: project.name, category: category.name)
  end

  def stop
    timer = @user.timer or return t("no_timer")
    hour = timer.stop!
    return hour.errors.full_messages.to_sentence unless hour.persisted?

    t("logged", hours: hour.value, project: hour.project.name, category: hour.category.name)
  end

  def status
    today = HoursValue.normalize(@user.hours.where(date: Date.current).sum(:value))
    running = @user.timer
    text = t("today", hours: today)
    return text unless running

    minutes = (running.elapsed / 60).to_i
    text + " " + t("running", project: running.project.name, time: format("%d:%02d", minutes / 60, minutes % 60))
  end

  # "<project> <category> [description...]" → [Project, Category, String] or [error message]
  def resolve(words)
    project = match(Project.unarchived, words[0], :project)
    return [project] if project.is_a?(String)

    category = match(Category.all, words[1], :category)
    return [category] if category.is_a?(String)

    [project, category, words.drop(2).join(" ").presence]
  end

  # Exact slug or name first, then a unique prefix ("book" → "Booking app").
  def match(scope, word, kind)
    return t("missing_#{kind}") if word.blank?

    needle = word.downcase.tr("-_", "  ")
    records = scope.to_a
    exact = records.find { |r| r.name.downcase == needle || (r.respond_to?(:slug) && r.slug == word.downcase) }
    return exact if exact

    found = records.select { |r| r.name.downcase.start_with?(needle) }
    return found.first if found.one?
    return t("unknown_#{kind}", word: word) if found.empty?

    t("ambiguous", word: word, options: found.map(&:name).first(5).join(", "))
  end

  def duration(word)
    match = DURATION.match(word.to_s)
    return nil unless match && (match[:h] || match[:m] || match[:plain])

    hours = (match[:h] || match[:plain]).to_s.tr(",", ".").to_f
    seconds = (hours * 3600 + match[:m].to_i * 60).round
    seconds.positive? ? seconds : nil
  end

  def t(key, **args)
    I18n.t("slack.#{key}", **args)
  end
end
