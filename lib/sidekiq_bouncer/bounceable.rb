# frozen_string_literal: true

module SidekiqBouncer
  module Bounceable

    def self.included(base)
      base.prepend InstanceMethods
      base.extend ClassMethods
    end

    module ClassMethods
      # @retrun [SidekiqBouncer::Bouncer]
      attr_reader :bouncer

      # creates and sets a +SidekiqBouncer::Bouncer+
      def register_bouncer(**)
        @bouncer = SidekiqBouncer::Bouncer.new(self, **)
      end
    end

    module InstanceMethods
      def perform(*, debounce_key, **)
        self.class.bouncer.run(debounce_key) do
          super(*, **)
        end
      end
    end

  end
end