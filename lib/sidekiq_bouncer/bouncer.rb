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
      unless klass.is_a?(Class)# && klass.new.respond_to?(:perform_at)
        raise TypeError.new('first argument must be a class')
      end

      @klass = klass
      @delay = delay
      @delay_buffer = delay_buffer
    end
    
    # Schedules a job to be executed with a specified delay + the delay_buffer, and
    # sets a key to redis which will be used to debounce jobs with matching arguments
    #
    # @param [*] params
    # @param [String|Array<Integer>] key_or_positions
    # @return [Boolean] true if should be excecuted
    def debounce(*params, key_or_positions:)
      key = key_or_positions.is_a?(Array) ? params.values_at(*key_or_positions).flatten.join(',') : key_or_positions
      scoped_key = redis_key(key)

      # Refresh the timestamp in redis with debounce delay added.
      redis.call('SET', scoped_key, now_i + @delay)

      # Schedule the job with not only debounce delay added, but also DELAY_BUFFER.
      # DELAY_BUFFER helps prevent race condition between this line and the one above.
      @klass.perform_at(
        now_i + @delay + @delay_buffer,
        *params,
        scoped_key
      )
    end

    # Checks if job should be excecuted
    #
    # @param [NilClass|String] scoped_key
    # @return [Boolean] true if should be excecuted
    def let_in?(key)
      return true if key.nil? || redis_key(nil) == key
      
      # Only the last job should come after the timestamp.
      timestamp = redis.call('GET', key)
      return false if now_i < timestamp.to_i

      # But because of DELAY_BUFFER, there could be mulitple last jobs enqueued within
      # the span of DELAY_BUFFER. The first one will clear the timestamp, and the rest
      # will skip when they see that the timestamp is gone.
      return false if timestamp.nil?
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
