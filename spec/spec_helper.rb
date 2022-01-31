require "bundler/setup"
require "sidekiq_bouncer"
require 'byebug'

RSpec.configure do |config|
  config.filter_run_when_matching :focus
  # # Disable RSpec exposing methods globally on `Module` and `main`
  # config.disable_monkey_patching!

  # config.expect_with :rspec do |c|
  #   c.syntax = :expect
  # end
end
