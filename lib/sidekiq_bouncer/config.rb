# frozen_string_literal: true

module SidekiqBouncer
  class Config
    attr_accessor :redis_pool # Sidekiq.redis_pool
  end
end
