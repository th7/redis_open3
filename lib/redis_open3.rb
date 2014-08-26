require 'redis_open3/version'
require 'redis_open3/enum'

class RedisOpen3
  IN_KEY  = 'redis_open3_in'
  OUT_KEY = 'redis_open3_out'
  ERR_KEY = 'redis_open3_err'

  def initialize(redis_pool, opts={})
    @redis_pool = redis_pool
    @timeout    = opts[:timeout] || 900
  end

  def open3
    with_enums(generated_uuids) do |redis_in, redis_out, redis_err, uuids|
      begin
        yield redis_in, redis_out, redis_err, uuids
      rescue Exception => e
        redis_in.fail
        raise e
      ensure
        redis_out.delete
        redis_err.delete
      end
      redis_in.close
    end
  end

  def process3(uuids)
    with_enums(uuids) do |redis_in, redis_out, redis_err|
      begin
        yield redis_in, redis_out, redis_err
      rescue Exception => e
        redis_out.fail
        ([e.inspect] + e.backtrace).each { |row| redis_err << row }
        raise e
      ensure
        redis_in.delete
        redis_err.close
      end
      redis_out.close
    end
  end

  private

  def with_conns
    @redis_pool.call do |redis1|
      @redis_pool.call do |redis2|
        @redis_pool.call do |redis3|
          yield redis1, redis2, redis3
        end
      end
    end
  end

  def with_enums(uuids)
    with_conns do |redis1, redis2, redis3|
      redis_in  = Enum.new(uuids[IN_KEY],  redis: redis1, timeout: @timeout)
      redis_out = Enum.new(uuids[OUT_KEY], redis: redis2, timeout: @timeout)
      redis_err = Enum.new(uuids[ERR_KEY], redis: redis3, timeout: @timeout)
      yield redis_in, redis_out, redis_err, uuids
    end
  end

  def generated_uuids
    [ IN_KEY, OUT_KEY, ERR_KEY ].inject({}) do |result, key|
      result[key] = SecureRandom.uuid
      result
    end
  end
end
