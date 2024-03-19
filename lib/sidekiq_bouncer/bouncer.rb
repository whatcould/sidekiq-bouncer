# frozen_string_literal: true

module SidekiqBouncer
  class Bouncer

    DELAY_BUFFER = 1          # Seconds
    DELAY = 60                # Seconds

    attr_reader :klass
    attr_accessor :delay, :delay_buffer

    # @param [Class] klass worker class that responds to `perform_at`
    # @param [Integer] delay seconds used for debouncer
    # @param [Integer] delay_buffer used to prevent race conditions
    def initialize(klass, delay: DELAY, delay_buffer: DELAY_BUFFER)
      # unless klass.is_a?(Class) && klass.respond_to?(:perform_at)
      #   raise TypeError.new("first argument must be a class and respond to 'perform_at'")
      # end

      @klass = klass
      @delay = delay
      @delay_buffer = delay_buffer
    end

    # Schedules a job to be executed with a specified delay + the delay_buffer, and
    # sets a key to Redis which will be used to debounce jobs
    #
    # @param [*] params
    # @param [Array<Integer>|#to_s] key_or_args_indices
    # @return [Boolean] true if should be excecuted
    def debounce(*params, key_or_args_indices:)
      raise TypeError.new('key_or_args_indices cannot be nil') if key_or_args_indices.nil?

      key = case key_or_args_indices
      when Array
        params.values_at(*key_or_args_indices).join(',')
      else
        key_or_args_indices
      end

      key = redis_key(key)

      # Add/Update the timestamp in redis with debounce delay added.
      redis.call('SET', key, now_i + @delay)

      # Schedule the job with not only debounce delay added, but also DELAY_BUFFER.
      # DELAY_BUFFER helps prevent race condition between this line and the one above.
      @klass.perform_at(
        now_i + @delay + @delay_buffer,
        *params,
        key
      )
    end

    # Checks if job should be excecuted
    #
    # @param [NilClass|String] key
    # @return [Boolean] true if should be excecuted
    def let_in?(key)
      # handle non-debounced jobs and already scheduled jobs when debouncer is added for the first time
      return true if key.nil?

      # Only the last job should come after the timestamp.
      # Due to the DELAY_BUFFER, there could be mulitple jobs enqueued within
      # the span of DELAY_BUFFER. The first one will clear the timestamp, and the rest
      # will skip when they see that the timestamp is gone.
      timestamp = redis.call('GET', key)
      return false if timestamp.nil? || now_i < timestamp.to_i

      redis.call('DEL', key)

      true
    end

    # @return [RedisClient::Pooled]
    def redis
      SidekiqBouncer.config.redis
    end

    private

    # Builds a key based on arguments
    #
    # @param [Array] redis_params
    # @return [String]
    def redis_key(key)
      "#{@klass}:#{key}"
    end

    # @return [Integer] Time#now as integer
    def now_i
      Time.now.to_i
    end

  end
end
