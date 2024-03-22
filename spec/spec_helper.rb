# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path('../lib', __dir__)
require 'bundler/setup'
require 'sidekiq_bouncer'
require 'timecop'
require 'debug'

RSpec.configure do |config|
  config.filter_run_when_matching :focus
  # # Disable RSpec exposing methods globally on `Module` and `main`
  # config.disable_monkey_patching!

  # config.expect_with :rspec do |c|
  #   c.syntax = :expect
  # end
end
