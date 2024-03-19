# frozen_string_literal: true

require 'sidekiq_bouncer/config'
require 'sidekiq_bouncer/version'
require 'sidekiq_bouncer/bounceable'
require 'sidekiq_bouncer/bouncer'

module SidekiqBouncer

  class << self

    # return [SidekiqBouncer::Config] cache
    def config
      @config ||= SidekiqBouncer::Config.new
    end

    # Yield self to allow configuing in a block
    def configure(&)
      yield config
    end
  end

end