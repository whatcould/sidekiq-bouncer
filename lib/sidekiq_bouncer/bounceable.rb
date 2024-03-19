# frozen_string_literal: true

module SidekiqBouncer
  module Bounceable

    def self.included(base)
      base.include InstanceMethods
      base.extend ClassMethods
    end

    module ClassMethods
      # creates and sets a +SidekiqBouncer::Bouncer+
      def register_bouncer(**kwargs)
        @bouncer = SidekiqBouncer::Bouncer.new(self, **kwargs)
      end

      # @retrun [SidekiqBouncer::Bouncer]
      def bouncer
        @bouncer
      end
    end

    module InstanceMethods
    end

  end
end