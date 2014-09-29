require 'retained/redis_connection'
require 'retained/group_configuration'

module Retained
  class Configuration
    attr_accessor :redis
    attr_accessor :prefix
    attr_reader :default_group
    attr_reader :group_configs
    attr_writer :redis_connection

    def initialize
      @redis = { url: 'redis://localhost:6379' }
      @prefix = 'retained'
      @default_group = 'default'
      @group_configs = {}
    end

    # Retrieve the configuration for the group. A block may be provided
    # to configure the group.
    def group(group)
      @group_configs[group.to_s] ||= fetch_group_configuration(group)

      if block_given?
        yield(@group_configs[group.to_s])
        save_group_configuration(group, @group_configs[group.to_s])
      else
        @group_configs[group.to_s].set_defaults
      end

      @group_configs[group.to_s]
    end

    def redis_connection
      @redis_connection ||= RedisConnection.new(redis)
    end

    private

    def fetch_group_configuration(group)
      redis_connection.sadd "#{prefix}:groups", group.to_s
      GroupConfiguration.new(redis_connection.hgetall "#{prefix}:group_config:#{group}")
    end

    def save_group_configuration(group, configuration)
      configuration.set_defaults
      redis_connection.hmset "#{prefix}:group_config:#{group}", *configuration.to_hash
      redis_connection.sadd "#{prefix}:groups", group.to_s
      @group_configs[group.to_s] = configuration
    end
  end
end
