require "net/http"
require "json"
require "uri"

module HoursCLI
  # Thin client for the Hours REST API v1 (docs/api/openapi.yaml).
  class Client
    TIMEOUT = 15

    def initialize(url:, token:, user_agent: "hours-cli/#{VERSION}")
      @base = URI.join(url.to_s.sub(%r{/*\z}, "/"), "api/v1/")
      @token = token
      @user_agent = user_agent
    end

    def get(path, params = {}) = request(Net::HTTP::Get, path, params: params)
    def post(path, body = nil) = request(Net::HTTP::Post, path, body: body)
    def patch(path, body) = request(Net::HTTP::Patch, path, body: body)
    def delete(path) = request(Net::HTTP::Delete, path)

    # Follows rel="next" links until the last page.
    def get_all(path, params = {})
      records = []
      uri = build_uri(path, params.merge(per_page: 100))
      while uri
        response = perform(Net::HTTP::Get.new(uri))
        records.concat(parse(response))
        uri = next_link(response)
      end
      records
    end

    private

    def request(klass, path, params: {}, body: nil)
      req = klass.new(build_uri(path, params))
      if body
        req["Content-Type"] = "application/json"
        req.body = JSON.generate(body)
      end
      parse(perform(req))
    end

    def build_uri(path, params)
      uri = URI.join(@base, path.delete_prefix("/"))
      query = params.compact.map { |k, v| [k.to_s, v.to_s] }
      uri.query = URI.encode_www_form(query) unless query.empty?
      uri
    end

    def perform(req)
      req["Authorization"] = "Bearer #{@token}"
      req["Accept"] = "application/json"
      req["User-Agent"] = @user_agent
      uri = req.uri
      Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https",
                                          open_timeout: TIMEOUT, read_timeout: TIMEOUT) { |http| http.request(req) }
    rescue SocketError, SystemCallError, Net::OpenTimeout, Net::ReadTimeout, OpenSSL::SSL::SSLError => e
      raise NetworkError, "Can't reach #{uri.host}: #{e.message}"
    end

    def parse(response)
      status = response.code.to_i
      body = response.body.to_s.empty? ? nil : JSON.parse(response.body)
      return body if status.between?(200, 299)

      error = body.is_a?(Hash) ? body["error"].to_h : {}
      raise ApiError.new(status, error["code"], error["message"] || "HTTP #{status}", error["details"])
    rescue JSON::ParserError
      raise ApiError.new(status, "bad_response", "Unexpected response (HTTP #{status}); is the URL an Hours account?")
    end

    def next_link(response)
      link = response["Link"].to_s.split(",").find { |part| part.include?('rel="next"') }
      link && URI(link[/<([^>]+)>/, 1])
    end
  end
end
