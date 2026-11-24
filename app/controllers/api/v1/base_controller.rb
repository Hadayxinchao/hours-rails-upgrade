# JSON API, v1. Requests go to the account's own address
# (https://acme.example.com/api/v1/...) with "Authorization: Bearer hrs_...".
#
# Order matters: the account schema is selected from the subdomain *before*
# the token is looked up, because tokens live in the account's schema. A token
# from one account is unknown on every other account's subdomain.
module Api
  module V1
    class BaseController < ActionController::API
      include ActionController::HttpAuthentication::Token::ControllerMethods

      PER_PAGE_MAX = 100

      # 300 requests a minute per token (per IP before authentication), counted
      # in Rails.cache: Solid Cache in production, so limits hold across processes.
      rate_limit to: 300, within: 1.minute, by: -> { rate_limit_key }, store: RateLimitStore,
                 with: -> { render_error(:too_many_requests, "rate_limited", "Too many requests; retry in a minute") }

      before_action :select_account
      before_action :authenticate

      rescue_from ActiveRecord::RecordNotFound do
        render_error(:not_found, "not_found", "Not found")
      end
      rescue_from ActionController::ParameterMissing do |error|
        render_error(:bad_request, "bad_request", error.message)
      end

      attr_reader :current_user

      private

      def select_account
        Apartment::Tenant.switch!("public")
        return if Hours.single_tenant_mode?

        subdomain = request.subdomain
        unless subdomain.present? && Account.exists?(subdomain: subdomain)
          return render_error(:not_found, "unknown_account", "No account at this address")
        end

        Apartment::Tenant.switch!(subdomain)
      end

      def authenticate
        token = authenticate_with_http_token { |plaintext, _| ApiToken.authenticate(plaintext) }
        return request_http_token_authentication_json unless token

        token.touch_last_used
        @current_user = token.user
      end

      def request_http_token_authentication_json
        headers["WWW-Authenticate"] = 'Bearer realm="Hours API"'
        render_error(:unauthorized, "unauthorized", "Missing, invalid or revoked API token")
      end

      def rate_limit_key
        header = request.authorization.to_s
        header.start_with?("Bearer ") ? ApiToken.digest(header.delete_prefix("Bearer ")) : request.remote_ip
      end

      def render_error(status, code, message, details = nil)
        body = { error: { code: code, message: message } }
        body[:error][:details] = details if details
        render json: body, status: status
      end

      def render_invalid(record)
        render_error(:unprocessable_content, "invalid", record.errors.full_messages.to_sentence,
                     record.errors.to_hash)
      end

      # ?page=2&per_page=50 → Link and X-Total-Count headers, like GitHub's API.
      def paginate(scope)
        per = params.fetch(:per_page, 50).to_i.clamp(1, PER_PAGE_MAX)
        page = [params.fetch(:page, 1).to_i, 1].max
        records = scope.page(page).per(per)
        headers["X-Total-Count"] = records.total_count.to_s
        links = { next: (page + 1 unless records.last_page? || records.out_of_range?),
                  prev: (page - 1 if page > 1) }.compact
        headers["Link"] = links.map { |rel, n| %(<#{url_for(request.query_parameters.merge(page: n, per_page: per, only_path: false))}>; rel="#{rel}") }.join(", ") if links.any?
        records
      end
    end
  end
end
