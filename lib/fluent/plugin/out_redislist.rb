module Fluent
  class RedisOutput < BufferedOutput
    Fluent::Plugin.register_output('redislist', self)
    attr_reader :host, :port, :db_number, :redis, :limit

    def initialize
      super
      require 'redis'
      require 'msgpack'
    end

    def configure(conf)
      super

      @host = conf.has_key?('host') ? conf['host'] : 'localhost'
      @port = conf.has_key?('port') ? conf['port'].to_i : 6379
      @db_number = conf.has_key?('db_number') ? conf['db_number'].to_i : nil
      @limit = conf.has_key?('redislist_limit') ? conf['redislist_limit'].to_i : nil

    end

    def start
      super

      @redis = Redis.new(:host => @host, :port => @port,
                         :thread_safe => true, :db => @db_number)
    end

    def shutdown
      @redis.quit
    end

    def format(tag, time, record)
      [tag, record].to_msgpack
    end

    def write(chunk)
      @redis.pipelined {
        chunk.open { |io|
          begin
            MessagePack::Unpacker.new(io).each.each_with_index { |record, index|
              @redis.rpush record[0], record[1].to_json
              @redis.ltrim record[0], -@limit, -1 if @limit
            }
          rescue EOFError
            # EOFError always occured when reached end of chunk.
          end
        }
      }
    end
  end
end
