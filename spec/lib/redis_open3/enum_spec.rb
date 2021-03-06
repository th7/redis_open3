require 'redis_open3/enum'

describe RedisOpen3::Enum do
  let(:list_name) { 'redis_open3:redis_enum:test_list' }
  let(:timeout) { 1 }
  let(:enum) { RedisOpen3::Enum.new(list_name, redis: RedisConn.conn, timeout: timeout) }
  let(:eof) { RedisOpen3::Enum::EOF }

  after { enum.delete }

  describe '#<<' do
    it 'adds an item to the redis list' do
      RedisConn.with do |redis|
        expect {
          enum << 'test_item'
        }.to change {
          redis.lpop(list_name)
        }.from(nil).to('test_item')
      end
    end

    it 'resets the ttl' do
      RedisConn.with do |redis|
        expect {
          enum << 'test_item'
        }.to change {
          redis.ttl(list_name).to_i
        }.from(-1).to(be > timeout)
      end
    end
  end

  describe '#close' do
    it 'adds the EOF uuid to the redis list' do
      RedisConn.with do |redis|
        expect {
          enum.close
        }.to change {
          redis.lpop(list_name)
        }.from(nil).to(eof)
      end
    end

    it 'resets the ttl' do
      RedisConn.with do |redis|
        expect {
          enum.close
        }.to change {
          redis.ttl(list_name).to_i
        }.from(-1).to(be > timeout)
      end
    end
  end

  describe '#each' do
    let(:expected_items) { ['item1', 'item2', 'item3'] }

    it 'blocks until it can yield each item in the list' do
      Thread.new do
        RedisConn.with do |redis|
          expected_items.each do |item|
            redis.rpush(list_name, item)
            sleep 0.02
          end
          redis.rpush(list_name, eof)
        end
      end

      found_items = enum.each.to_a
      expected_items.each_with_index { |item, i| expect(found_items[i]).to eq item }
    end

    it 'resets the ttl' do
      RedisConn.with do |redis|
        redis.rpush(list_name, 'junk')
        redis.rpush(list_name, eof)
        redis.persist(list_name)

        expect(redis.ttl(list_name)).to eq -1
        enum.each do |item|
          expect(redis.ttl(list_name).to_i).to be > timeout
        end
      end
    end
  end

  describe '#delete' do
    it 'deletes the redis list' do
      RedisConn.with do |redis|
        enum << 'junk'
        expect {
          enum.delete
        }.to change {
          redis.exists(list_name)
        }.from(true).to(false)
      end
    end
  end

  describe '#fail' do
    let(:err) { RedisOpen3::Enum::ERR }

    it 'adds the ERR uuid to the redis list' do
      RedisConn.with do |redis|
        expect {
          enum.fail
        }.to change {
          redis.lpop(list_name)
        }.from(nil).to(err)
      end
    end

    it 'resets the ttl' do
      RedisConn.with do |redis|
        expect {
          enum.fail
        }.to change {
          redis.ttl(list_name).to_i
        }.from(-1).to(be > timeout)
      end
    end
  end

  context 'timeout' do
    it 'raises a timeout error if the timeout expires' do
      expect { enum.each.to_a }.to raise_error(RedisOpen3::Enum::TimeoutError)
    end
  end

  context 'when an error signal is sent' do
    it 'raises a command failed error' do
      RedisConn.with { |redis| redis.lpush(enum.list_name, RedisOpen3::Enum::ERR)}
      expect { enum.each.to_a }.to raise_error(RedisOpen3::Enum::Error)
    end
  end
end
