# frozen_string_literal: true

module SidekiqBouncer
  class Config
    attr_accessor :redis_client # Proc or RedisClient from redis-client gem
  end
end
