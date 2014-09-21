require 'redis'

module Retained
  class RedisConnection
    attr_reader :client

    def initialize(options = {})
      @client = Redis.new(options)
    end

    def method_missing(method, *args, &block)
      @client.send(method, *args, &block)
    end
  end
end
