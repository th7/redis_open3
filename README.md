# RedisOpen3

Provides Open3 like syntax for passing data through Redis.

## Installation

Add this line to your application's Gemfile:

    gem 'redis_open3'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install redis_open3

## Usage

Initialize a RedisOpen3 object giving a method which will yield redis connections.
```
# example using ConnectinPool gem
conn_pool = ConnectionPool.new(size: 9, timeout: 10) { Redis.new }
ropen3 = RedisOpen3.new(conn_pool.method(:with))
```

Use #popen3 to start passing data through Redis.
```
# example using RedisOpen3 to pass data to a different Sidekiq instance
ropen3.popen3 do |redis_in, redis_out, redis_err, uuids|
  # start the foreign Sidekiq job
  # The worker must be pre-configured to use a queue worked by the foreign process
  ForeignWorker.perform_async(args, uuids)

  # Then feed data across Redis
  # Using threads allows true streaming between processes/workers
  threads = [] << Thread.new do
    input_data.each { |row| redis_in << row }
    # Important to signal that we're done sending data
    redis_in.close
  end

  # Catch your return data
  threads << Thread.new do
    redis_out.each { |row| output_file << row }
  end

  # Catch logging/error messages
  threads << Thread.new do
    redis_err.each { |row| log_file << row }
  end

  threads.each(&:join)
  # You should have already closed redis_in yourself, but it will also be closed if you haven't
  # redis_out and redis_err lists will be deleted
end
```

Use #process3 to receive input and return data
```
# This could be used as the body of the perform method on a Sidekiq worker
# Assumes uuids were send across as args
ropen3.process3(uuids) do |redis_in, redis_out, redis_err|
  # Pull your input data from Redis
  # And send your results back across Redis
  redis_in.each { |row| redis_out << process(row) }

  # Any exceptions raised from this block will be sent to redis_err
  # redis_out and redis_err will be closed
  # redis_in will be deleted
end
```
## Contributing

1. Fork it ( https://github.com/[my-github-username]/redis_open3/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
