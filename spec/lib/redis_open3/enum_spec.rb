require 'redis_open3/enum'

describe RedisOpen3::Enum do
  let(:list_name) { 'redis_open3:redis_enum:test_list' }
  let(:enum) { RedisOpen3::Enum.new(list_name, redis: RedisConn.conn, timeout: 1) }
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

  context 'timeout' do
    it 'raises a timeout error if the timeout expires' do
      expect { enum.each.to_a }.to raise_error(RedisOpen3::Enum::TimeoutError)
    end
  end
end
