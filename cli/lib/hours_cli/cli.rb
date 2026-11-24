require "optparse"
require "json"
require "date"

module HoursCLI
  # `hours <command> [args] [--json]`. Every command prints a readable table
  # or line by default and the API's JSON with --json, for scripts and jq.
  class CLI
    COMMANDS = {
      "login" => "Save the account URL and an API token",
      "logout" => "Forget the saved token",
      "whoami" => "Show who the token belongs to",
      "projects" => "List projects with budget usage",
      "categories" => "List categories",
      "log" => "Log time: hours log 1.5h booking dev \"Fixed reminders #backend\" [--date yesterday]",
      "list" => "List entries: hours list [--me] [--from DATE] [--to DATE] [--project NAME]",
      "edit" => "Change an entry: hours edit ID [--hours 2h] [--date DATE] [--description TEXT]",
      "delete" => "Delete one of your entries: hours delete ID",
      "start" => "Start a timer: hours start booking dev [description]",
      "stop" => "Stop the timer and log the time",
      "status" => "Running timer and today's total",
      "discard" => "Discard the running timer",
      "report" => "Hours per project and category: hours report [--week|--month|--from DATE --to DATE] [--me]"
    }.freeze

    def self.start(argv, out: $stdout, err: $stderr, env: ENV)
      new(out: out, err: err, env: env).run(argv)
    end

    def initialize(out:, err:, env:)
      @out = out
      @err = err
      @env = env
      @options = {}
    end

    # Returns the process exit code.
    def run(argv)
      args = global_options.parse(argv.dup)
      command = args.shift
      return say("hours-cli #{VERSION}") || 0 if @options[:version]
      return help if command.nil? || %w[help -h --help].include?(command)
      raise UsageError, "Unknown command #{command.inspect}. Run: hours help" unless COMMANDS.key?(command)

      send(:"cmd_#{command}", args)
      0
    rescue OptionParser::ParseError => e
      fail_with(UsageError.new(e.message))
    rescue Error => e
      fail_with(e)
    end

    private

    # ---- commands ---------------------------------------------------------

    def cmd_login(args)
      opts = parse(args) do |o, h|
        o.on("--url URL") { |v| h[:url] = v }
        o.on("--token TOKEN") { |v| h[:token] = v }
      end
      url = opts[:url] || @options[:url] || @env["HOURS_URL"]
      token = opts[:token] || @options[:token] || @env["HOURS_TOKEN"]
      raise UsageError, "Usage: hours login --url https://ACCOUNT.example.com --token hrs_..." unless url && token

      me = Client.new(url: url, token: token).get("me")
      config.save(url: url, token: token)
      say "Logged in to #{url} as #{me['first_name']} #{me['last_name']} <#{me['email']}>. Saved to #{config.path}"
    end

    def cmd_logout(_args)
      config.delete
      say "Logged out (removed #{config.path}). The token itself still works until you revoke it in Hours."
    end

    def cmd_whoami(_args)
      me = client.get("me")
      output(me) { "#{me['first_name']} #{me['last_name']} <#{me['email']}> on #{config.url}" }
    end

    def cmd_projects(args)
      opts = parse(args) { |o, h| o.on("--archived", "Include archived projects") { h[:archived] = true } }
      projects = client.get_all("projects", archived: opts[:archived] ? "true" : nil)
      output(projects) do
        rows = projects.map do |p|
          budgets = p["budgets"].map { |b| "#{b['kind']} #{b['percentage'].round}%#{" (#{b['level']})" if b['level']}" }
          [p["slug"], p["name"], p.dig("client", "name"), budgets.join(", ")]
        end
        Table.render(%w[SLUG NAME CLIENT BUDGETS], rows)
      end
    end

    def cmd_categories(_args)
      categories = client.get("categories")
      output(categories) { Table.render(%w[ID NAME], categories.map { |c| [c["id"], c["name"]] }, right: [0]) }
    end

    def cmd_log(args)
      opts = parse(args) { |o, h| o.on("--date DATE", "today, yesterday, -N or YYYY-MM-DD") { |v| h[:date] = v } }
      duration, project_word, category_word, *rest = opts[:args]
      hours, rounded = Parsing.duration(duration)
      project, category = resolve(project_word, category_word)
      entry = client.post("hours", hour: { project_id: project["id"], category_id: category["id"], hours: hours,
                                           date: Parsing.date(opts[:date]).iso8601, description: rest.join(" ") })
      output(entry) do
        "Logged #{Parsing.hours(entry['hours'])} h of #{category['name']} on #{project['name']} " \
          "(#{entry['date']}, ##{entry['id']})#{' - rounded up to the next quarter hour' if rounded}"
      end
    end

    def cmd_list(args)
      opts = parse(args) do |o, h|
        o.on("--me", "Only your entries") { h[:me] = true }
        o.on("--from DATE") { |v| h[:from] = v }
        o.on("--to DATE") { |v| h[:to] = v }
        o.on("--project NAME") { |v| h[:project] = v }
        o.on("--limit N", Integer, "At most N entries (default 20)") { |v| h[:limit] = v }
      end
      params = { user_id: opts[:me] ? "me" : nil,
                 from: opts[:from] && Parsing.date(opts[:from]).iso8601, to: opts[:to] && Parsing.date(opts[:to]).iso8601,
                 project_id: opts[:project] && Parsing.match(projects, opts[:project], "project")["id"],
                 per_page: [opts.fetch(:limit, 20), 100].min }
      entries = client.get("hours", params).first(opts.fetch(:limit, 20))
      output(entries) do
        names = projects.to_h { |p| [p["id"], p["name"]] }
        cats = client.get("categories").to_h { |c| [c["id"], c["name"]] }
        Table.render(%w[ID DATE HOURS PROJECT CATEGORY DESCRIPTION],
                     entries.map { |e| [e["id"], e["date"], Parsing.hours(e["hours"]), names[e["project_id"]], cats[e["category_id"]], e["description"]] },
                     right: [0, 2])
      end
    end

    def cmd_edit(args)
      opts = parse(args) do |o, h|
        o.on("--hours DURATION") { |v| h[:hours] = v }
        o.on("--date DATE") { |v| h[:date] = v }
        o.on("--description TEXT") { |v| h[:description] = v }
        o.on("--project NAME") { |v| h[:project] = v }
        o.on("--category NAME") { |v| h[:category] = v }
      end
      id = entry_id(opts[:args])
      changes = {}
      changes[:hours] = Parsing.duration(opts[:hours]).first if opts[:hours]
      changes[:date] = Parsing.date(opts[:date]).iso8601 if opts[:date]
      changes[:description] = opts[:description] if opts.key?(:description)
      changes[:project_id] = Parsing.match(projects, opts[:project], "project")["id"] if opts[:project]
      changes[:category_id] = Parsing.match(client.get("categories"), opts[:category], "category")["id"] if opts[:category]
      raise UsageError, "Nothing to change. Use --hours, --date, --description, --project or --category" if changes.empty?

      entry = client.patch("hours/#{id}", hour: changes)
      output(entry) { "Updated ##{entry['id']}: #{Parsing.hours(entry['hours'])} h on #{entry['date']}" }
    end

    def cmd_delete(args)
      id = entry_id(parse(args)[:args])
      client.delete("hours/#{id}")
      output({ "deleted" => id }) { "Deleted ##{id}" }
    end

    def cmd_start(args)
      project_word, category_word, *rest = parse(args)[:args]
      project, category = resolve(project_word, category_word)
      timer = client.post("timer", timer: { project_id: project["id"], category_id: category["id"], description: rest.join(" ") })
      output(timer) { "Timer started on #{project['name']} (#{category['name']}). Stop it with: hours stop" }
    end

    def cmd_stop(_args)
      entry = client.post("timer/stop")
      output(entry) { "Logged #{Parsing.hours(entry['hours'])} h (##{entry['id']}, rounded up to the next quarter hour)" }
    end

    def cmd_status(_args)
      today = Date.today.iso8601
      total = client.get_all("hours", user_id: "me", from: today, to: today).sum { |e| e["hours"] }
      timer = begin
        client.get("timer")
      rescue ApiError => e
        raise unless e.status == 404

        nil
      end
      output({ "today_hours" => total, "timer" => timer }) do
        line = "Today: #{Parsing.hours(total)} h logged."
        next line unless timer

        name = projects.find { |p| p["id"] == timer["project_id"] }&.fetch("name")
        minutes = timer["elapsed_seconds"] / 60
        "#{line}\nTimer running on #{name}: #{format('%d:%02d', minutes / 60, minutes % 60)}" \
          "#{" - #{timer['description']}" unless timer['description'].to_s.empty?}"
      end
    end

    def cmd_discard(_args)
      client.delete("timer")
      output({ "discarded" => true }) { "Timer discarded" }
    end

    def cmd_report(args)
      opts = parse(args) do |o, h|
        o.on("--week", "This week (default)") { h[:range] = :week }
        o.on("--month", "This month") { h[:range] = :month }
        o.on("--from DATE") { |v| h[:from] = v }
        o.on("--to DATE") { |v| h[:to] = v }
        o.on("--me", "Only your entries") { h[:me] = true }
      end
      from, to = report_range(opts)
      entries = client.get_all("hours", user_id: opts[:me] ? "me" : nil, from: from.iso8601, to: to.iso8601)
      names = projects.to_h { |p| [p["id"], p["name"]] }
      cats = client.get("categories").to_h { |c| [c["id"], c["name"]] }
      grouped = entries.group_by { |e| [names[e["project_id"]] || "##{e['project_id']}", cats[e["category_id"]]] }
      rows = grouped.map { |(project, category), list| [project, category, list.sum { |e| e["hours"] }] }
                    .sort_by { |project, category, hours| [-hours, project, category.to_s] }
      total = entries.sum { |e| e["hours"] }
      data = { "from" => from.iso8601, "to" => to.iso8601, "total_hours" => total,
               "rows" => rows.map { |p, c, h| { "project" => p, "category" => c, "hours" => h } } }
      output(data) do
        Table.render(%w[PROJECT CATEGORY HOURS], rows.map { |p, c, h| [p, c, Parsing.hours(h)] }, right: [2]) +
          "Total #{from}..#{to}: #{Parsing.hours(total)} h\n"
      end
    end

    # ---- helpers ----------------------------------------------------------

    def global_options
      OptionParser.new do |o|
        o.banner = "Usage: hours <command> [options]"
        o.on("--json", "Print the API's JSON") { @options[:json] = true }
        o.on("--url URL", "Account URL (default: saved, or HOURS_URL)") { |v| @options[:url] = v }
        o.on("--token TOKEN", "API token (default: saved, or HOURS_TOKEN)") { |v| @options[:token] = v }
        o.on("-v", "--version") { @options[:version] = true }
      end.tap { |parser| parser.raise_unknown = false }
    end

    def parse(args)
      result = {}
      parser = OptionParser.new { |o| yield(o, result) if block_given? }
      result[:args] = parser.parse(args)
      result
    end

    def config
      @config ||= Config.new(path: @env.fetch("HOURS_CONFIG", Config.default_path(@env)), env: @env,
                             url: @options[:url], token: @options[:token])
    end

    def client
      @client ||= begin
        config.require!
        Client.new(url: config.url, token: config.token)
      end
    end

    def projects
      @projects ||= client.get_all("projects")
    end

    def resolve(project_word, category_word)
      [Parsing.match(projects, project_word, "project"), Parsing.match(client.get("categories"), category_word, "category")]
    end

    def entry_id(args)
      id = args.first.to_s.delete_prefix("#")
      raise UsageError, "Which entry? Give its ID (see: hours list)" unless id.match?(/\A\d+\z/)

      id
    end

    def report_range(opts)
      today = Date.today
      return [Parsing.date(opts[:from]), Parsing.date(opts[:to] || "today")] if opts[:from]
      return [Date.new(today.year, today.month, 1), today] if opts[:range] == :month

      [today - (today.cwday - 1), today]
    end

    def output(data)
      @out.puts(@options[:json] ? JSON.pretty_generate(data) : yield)
    end

    def say(text)
      @out.puts(text)
    end

    def help
      lines = COMMANDS.map { |name, text| format("  %-11s %s", name, text) }
      say <<~HELP
        Hours from the command line (hours-cli #{VERSION}).

        Usage: hours <command> [options] [--json]

        Commands:
        #{lines.join("\n")}

        Global options: --json, --url URL, --token TOKEN, --version
        Durations: 2h, 1.5h, 45m, 1h30m (rounded up to quarter hours).
        Projects and categories: slug, name or a unique prefix ("book" → "Booking app").
        Exit codes: 0 ok, 1 usage, 2 auth, 3 not found, 4 rejected, 5 network, 6 rate limited.
      HELP
      0
    end

    def fail_with(error)
      @err.puts("hours: #{error.message}")
      if error.is_a?(ApiError) && error.details.is_a?(Hash)
        # "base" errors are already the message; list only field-specific ones.
        error.details.except("base").each { |field, messages| @err.puts("  #{field}: #{Array(messages).join(', ')}") }
      end
      error.exit_code
    end
  end
end
