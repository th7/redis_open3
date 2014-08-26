require 'redis_open3'

describe RedisOpen3 do
  let(:ropen) { RedisOpen3.new(conns, timeout: 1) }
  let(:conns) { RedisConn.method(:with) }

  describe '#popen3' do
    it 'yields 3 redis enum objects and a hash with their list uuids' do
      ropen.open3 do |r_in, r_out, r_err, uuids|
        expect(uuids[RedisOpen3::IN_KEY]).to  eq r_in.list_name
        expect(uuids[RedisOpen3::OUT_KEY]).to eq r_out.list_name
        expect(uuids[RedisOpen3::ERR_KEY]).to eq r_err.list_name
      end
    end

    it 'sends EOF to redis in enum after block closes' do
      r_in = nil
      ropen.open3 { |redis_in| r_in = redis_in }
      expect(r_in.each.to_a).to eq []
    end

    it 'deletes the redis_out and redis_err list' do
      out_name = nil
      err_name = nil
      conns.call do |redis|
        ropen.open3 do |_, redis_out, redis_err|
          out_name = redis_out.list_name
          err_name = redis_err.list_name
          redis_out << 'junk'
          redis_err << 'junk'
          expect(redis.exists(out_name)).to eq true
          expect(redis.exists(err_name)).to eq true
        end
        expect(redis.exists(out_name)).to eq false
        expect(redis.exists(err_name)).to eq false
      end
    end

    context 'an exception is raised' do
      it 'sends fail to redis_in' do
        expect {
          ropen.open3 do |redis_in|
            expect(redis_in).to receive(:fail)
            raise 'fail'
          end
        }.to raise_error RuntimeError, 'fail'
      end
    end
  end

  describe '#process3' do
    let(:uuids) {{
      RedisOpen3::IN_KEY  => SecureRandom.uuid,
      RedisOpen3::OUT_KEY => SecureRandom.uuid,
      RedisOpen3::ERR_KEY => SecureRandom.uuid
    }}

    it 'yields 3 redis enum objects with given list names' do
      ropen.process3(uuids) do |r_in, r_out, r_err|
        expect(r_in.list_name).to  eq uuids[RedisOpen3::IN_KEY]
        expect(r_out.list_name).to eq uuids[RedisOpen3::OUT_KEY]
        expect(r_err.list_name).to eq uuids[RedisOpen3::ERR_KEY]
      end
    end

    it 'sends EOF to redis out and redis err enums after block closes' do
      r_out = nil
      r_err = nil
      ropen.process3(uuids) { |_, redis_out, redis_err| r_out = redis_out; r_err = redis_err }
      expect(r_out.each.to_a).to eq []
      expect(r_err.each.to_a).to eq []
    end

    it 'deletes the redis_in list' do
      conns.call do |redis|
        ropen.process3(uuids) do |redis_in|
          redis_in << 'junk'
          expect(redis.exists(uuids[RedisOpen3::IN_KEY])).to eq true
        end
        expect(redis.exists(uuids[RedisOpen3::IN_KEY])).to eq false
      end
    end

    context 'an exception is raised' do
      it 'sends fail to redis_out' do
        expect {
          ropen.process3(uuids) do |_, redis_out|
            expect(redis_out).to receive(:fail)
            raise 'fail'
          end
        }.to raise_error RuntimeError, 'fail'
      end
    end
  end
end
