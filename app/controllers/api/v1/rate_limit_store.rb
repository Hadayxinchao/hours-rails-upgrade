module Api
  module V1
    # rate_limit keeps the store it is given at class load; this indirection
    # lets specs count in a memory store (the test env's Rails.cache is null).
    module RateLimitStore
      mattr_accessor :backend

      def self.increment(...)
        (backend || Rails.cache).increment(...)
      end
    end
  end
end
