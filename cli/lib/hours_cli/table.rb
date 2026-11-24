module HoursCLI
  # Plain aligned columns; numbers right-aligned.
  module Table
    module_function

    def render(headers, rows, right: [])
      return "" if rows.empty?

      cells = [headers] + rows.map { |row| row.map(&:to_s) }
      widths = headers.each_index.map { |i| cells.map { |row| row[i].to_s.length }.max }
      cells.map do |row|
        row.each_with_index.map do |cell, i|
          right.include?(i) ? cell.to_s.rjust(widths[i]) : cell.to_s.ljust(widths[i])
        end.join("  ").rstrip
      end.join("\n") + "\n"
    end
  end
end
