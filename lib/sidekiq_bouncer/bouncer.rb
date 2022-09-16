module SidekiqBouncer
  class Bouncer

    DELAY_BUFFER = 1          # Seconds
    DELAY = 60                # Seconds
    ALLOWED_PARAM_CLASSES = [
      Integer, String, Symbol
    ].freeze

    attr_reader :klass
    attr_accessor :delay, :delay_buffer, :only_params_at_index
    
    # @param [Class] klass worker class that responds to `perform_at`
    # @param [Integer] delay seconds used for debouncer
    # @param [Integer] delay_buffer used to prevent race conditions
    # @param [Array<Integer>] only_params_at_index if present, only considers params at specified indices on #debounce and #let_in?
    def initialize(klass, delay: DELAY, delay_buffer: DELAY_BUFFER, only_params_at_index: [])
      unless klass.is_a?(Class)# && klass.new.respond_to?(:perform_at)
        raise TypeError.new('first argument must be a class')
      end

      @klass = klass
      @delay = delay
      @delay_buffer = delay_buffer
      @only_params_at_index = only_params_at_index
    end
    
    # Schedules a job to be executed with a specified delay + the delay_buffer, and
    # sets a key to redis which will be used to debounce jobs with matching arguments
    #
    # @param [Array] params
    # @return [Boolean] true if should be excecuted
    def debounce(*params)
      redis_params = validate_and_filter_params(params)

      # Refresh the timestamp in redis with debounce delay added.
      redis.call('SET', redis_key(redis_params), now_i + @delay)

      # Schedule the job with not only debounce delay added, but also DELAY_BUFFER.
      # DELAY_BUFFER helps prevent race condition between this line and the one above.
      @klass.perform_at(now_i + @delay + @delay_buffer, *params)
    end

    # Checks if job should be excecuted
    #
    # @param [Array] params
    # @return [Boolean] true if should be excecuted
    def let_in?(*params)
      redis_params = validate_and_filter_params(params)

      # Only the last job should come after the timestamp.
      timestamp = redis.call('GET', redis_key(redis_params))
      return false if now_i < timestamp.to_i

      # But because of DELAY_BUFFER, there could be mulitple last jobs enqueued within
      # the span of DELAY_BUFFER. The first one will clear the timestamp, and the rest
      # will skip when they see that the timestamp is gone.
      return false if timestamp.nil?
      redis.call('DEL', redis_key(redis_params))

      true
    end

    # @return [RedisClient::Pooled]
    def redis
      SidekiqBouncer.config.redis
    end

    private
    
    # Validates all arguments are included in ALLOWED_PARAM_CLASSES and filters
    # params based on @only_params_at_index if present
    #
    # @param [Array] params
    # @return [Array] params (filtered if @only_params_at_index)
    def validate_and_filter_params(params)
      params = params.values_at(*@only_params_at_index).compact if @only_params_at_index && !@only_params_at_index.empty?
      params.flatten.each{ |param|
        raise TypeError.new(
          "sidekiq debouncer only supports #{ALLOWED_PARAM_CLASSES.join(', ')}, got: '#{param.class}' as argument"
        ) unless ALLOWED_PARAM_CLASSES.include?(param.class)
      }
      params
    end
    
    # Builds a key based on arguments
    #
    # @param [Array] redis_params
    # @return [String]
    def redis_key(redis_params)
      "#{@klass}:#{redis_params.flatten.join(',')}"
    end

    # @return [Integer] Time#now as integer
    def now_i
      Time.now.to_i
    end

  end
end
