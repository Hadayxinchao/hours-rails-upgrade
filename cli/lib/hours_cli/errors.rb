module HoursCLI
  # Each failure kind has its own exit code, so scripts can tell them apart.
  class Error < StandardError
    def exit_code = 1
  end

  class UsageError < Error; end

  class ConfigError < Error
    def exit_code = 2
  end

  class ApiError < Error
    attr_reader :status, :code, :details

    def initialize(status, code, message, details = nil)
      @status = status
      @code = code
      @details = details
      super(message)
    end

    def exit_code
      case status
      when 401, 403 then 2
      when 404 then 3
      when 400, 409, 422 then 4
      when 429 then 6
      else 1
      end
    end
  end

  class NetworkError < Error
    def exit_code = 5
  end
end
