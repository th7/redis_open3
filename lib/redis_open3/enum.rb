require 'redis'
require 'redis_open3/error'

class RedisOpen3
  class Enum
    class TimeoutError < RedisOpen3::Error; end
    class Error < RedisOpen3::Error; end

    include Enumerable
    attr_reader :list_name

    # magic :(
    EOF = '90829c12-3ac3-4af9-aeb4-8b63d1cc1d23'
    EOF_REGX = /\A#{EOF}\z/

    ERR = '7ce43256-a6ed-4890-9352-956ab8816dbd'
    ERR_REGX = /\A#{ERR}\z/

    def initialize(list_name, opts={})
      @list_name = list_name
      @timeout   = opts[:timeout]
      @redis     = opts[:redis] || Redis.new(opts[:redis_opts] || {})
    end

    def <<(input)
      push(input)
    end

    def close
      push(EOF)
    end

    def each(&block)
      Enumerator.new do |y|
        until (line = pop.chomp) =~ EOF_REGX
          raise Error, "Received error signal." if line =~ ERR_REGX
          y << line
        end
      end.each(&block)
    end

    def delete
      @redis.del(list_name)
    end

    def fail
      push(ERR)
    end

    private

    def push(string)
      @redis.rpush(list_name, string)
      @redis.expire(list_name, @timeout + 10)
    end

    def pop
      popped = @redis.blpop(list_name, @timeout)
      @redis.expire(list_name, @timeout + 10)
      if popped
        popped.last
      else
        raise TimeoutError, "Timeout of #{@timeout.inspect} seconds expired on list_name #{list_name.inspect}."
      end
    end
  end
end
