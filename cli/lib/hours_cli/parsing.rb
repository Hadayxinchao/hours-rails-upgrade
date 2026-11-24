require "date"

module HoursCLI
  # Same conventions as the Slack command: durations like 2h, 1.5h, 45m,
  # 1h30m (rounded up to quarter hours) and names by slug, exact name or a
  # unique prefix.
  module Parsing
    DURATION = /\A(?:(?<h>\d+(?:[.,]\d+)?)h)?(?:(?<m>\d+)m)?\z|\A(?<plain>\d+(?:[.,]\d+)?)\z/i

    module_function

    # → [hours (quarter steps), rounded?]
    def duration(text)
      match = DURATION.match(text.to_s.strip)
      raise UsageError, "Not a duration: #{text.inspect} (try 2h, 1.5h, 45m or 1h30m)" unless match && (match[:h] || match[:m] || match[:plain])

      minutes = ((match[:h] || match[:plain]).to_s.tr(",", ".").to_f * 60 + match[:m].to_i).round
      raise UsageError, "Duration must be more than zero" unless minutes.positive?

      hours = (minutes / 15.0).ceil / 4.0
      [(hours % 1).zero? ? hours.to_i : hours, (minutes % 15) != 0]
    end

    def date(text, today: Date.today)
      case text.to_s.strip.downcase
      when "", "today" then today
      when "yesterday" then today - 1
      when /\A-(\d+)\z/ then today - Regexp.last_match(1).to_i
      else Date.iso8601(text)
      end
    rescue Date::Error
      raise UsageError, "Not a date: #{text.inspect} (use YYYY-MM-DD, today, yesterday or -N days)"
    end

    def match(records, word, kind)
      raise UsageError, "Which #{kind}?" if word.to_s.empty?

      needle = word.downcase.tr("-_", "  ")
      exact = records.find { |r| r["name"].downcase == needle || r["slug"] == word.downcase }
      return exact if exact

      found = records.select { |r| r["name"].downcase.start_with?(needle) }
      return found.first if found.one?
      raise UsageError, "No #{kind} matches #{word.inspect}" if found.empty?

      raise UsageError, "#{word.inspect} matches several #{kind}s: #{found.map { |r| r['name'] }.first(5).join(', ')}"
    end

    def hours(value)
      value == value.to_i ? value.to_i.to_s : value.to_s
    end
  end
end
