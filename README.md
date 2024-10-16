# Sidekiq::Bouncer

This Ruby gem debounces Sidekiq jobs that have the same worker class and params.

It lets duplicate jobs enqueue. Each time, it refreshes a timestamp in Redis.
When duplicate jobs run, they are checked against this timestamp in Redis and
only the last job will execute.

## Alternatives Considered

This is a home grown solution. We looked at the official V6 recommendation and
top gems from Googling 'sidekiq debounce', but all were too slow or broken.

  1) https://github.com/mperham/sidekiq/wiki/API

     The official recommendation is to find and delete duplicate jobs before
     enqueuing a new job. V6 introduced `scan` for this purpose, and it is
     1.5x faster than V5's `select` method, but still too slow at high volume.

  2) https://github.com/paladinsoftware/sidekiq-debouncer

     Still works, but it uses the slow `select` method.

## Performance

For each duplicate job, this approach takes 10ms flat; in comparison, `scan`
takes 10ms per each thousand job in the scheduled set, which adds up quickly.
The before (using `scan`) and after (using this gem):

![Screen Shot 2020-06-16 at 5 50 46 PM](https://user-images.githubusercontent.com/680345/85186918-a2ff7580-b250-11ea-8b85-625efb722853.png)

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'sidekiq-bouncer'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install sidekiq-bouncer

## Usage

```ruby
# config/initializers/sidekiq_bouncer.rb
SidekiqBouncer.configure do |config|
  config.redis_pool = Sidekiq.redis_pool
end

# app/workers/foo_worker.rb
class FooWorker
  include Sidekiq::Worker
  include SidekiqBouncer::Bounceable

  # The default delay is 60 seconds. You can optionally override it.
  register_bouncer(delay: optional_delay_override, delay_buffer: optional_delay_buffer_override)

  def perform(param1, param2)
    # Do your thing.
  end
end

# Call `.bouncer.debounce(...)` instead of `.perform_in/perform_async(...)`.
FooWorker.bouncer.debounce(param1, param2, key_or_args_indices: [0, 1])
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/apartmentlist/sidekiq-bouncer. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Sidekiq::Bouncer project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/apartmentlist/sidekiq-bouncer/blob/master/CODE_OF_CONDUCT.md).
