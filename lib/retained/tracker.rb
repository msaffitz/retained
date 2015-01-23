require 'redis'
require 'active_support/core_ext/time/calculations'
require 'securerandom'
require 'retained/configuration'

module Retained
  class Tracker
    attr_accessor :config

    def initialize(config = Configuration.new)
      @config = config
    end

    def configure
      yield(config)
    end

    # Tracks the entity as active at the period, or now if no period
    # is provided.
    def retain(entity, group: 'default', period: Time.now)
      index = entity_index(entity, group)
      config.redis_connection.setbit key_period(group, period), index, 1
    end

    # Total active entities in the period, or now if no period,
    # is provided.
    def total_active(group: 'default', period: Time.now)
      config.redis_connection.bitcount key_period(group, period)
    end

    # Returns the total number of unique active entities between
    # the start and end periods (inclusive), or now if no stop
    # period is provided.
    def unique_active(group: 'default', start:, stop: Time.now)
      keys = []
      start = period_start(group, start)
      while (start <= stop)
        keys << key_period(group, start)
        start += seconds_in_reporting_interval(config.group(group).reporting_interval)
      end
      return 0  if keys.length == 0

      temp_bitmap do |key|
        config.redis_connection.bitop 'OR', key, *keys
        config.redis_connection.bitcount key
      end
    end

    # Returns true if the entity was active in the given period,
    # or now if no period is provided.  If a group or an array of groups
    # is provided activity will only be considered based on those groups.
    def active?(entity, group: nil, period: Time.now)
      group = [group] if group.is_a?(String)
      group = groups if group == [] || !group

      group.to_a.each do |g|
        return true if config.redis_connection.getbit(key_period(g, period), entity_index(entity, g)) == 1
      end
      false
    end

    # Returns an array of all groups
    def groups
      config.redis_connection.smembers "#{config.prefix}:groups"
    end

    # Returns the index (offset) of the entity within the group.
    #
    # Thanks to crashlytics for the monotonic_zadd approach taken here
    # http://www.slideshare.net/crashlytics/crashlytics-on-redis-analytics
    def entity_index(entity, group)
      monotonic_zadd = <<LUA
        local sequential_id = redis.call('zscore', KEYS[1], ARGV[1])
        if not sequential_id then
          sequential_id = redis.call('zcard', KEYS[1])
          redis.call('zadd', KEYS[1], sequential_id, ARGV[1])
        end
        return sequential_id
LUA

      key = "#{config.prefix}:entity_ids:#{group}"
      config.redis_connection.eval(monotonic_zadd, [key], [entity.to_s]).to_i
    end

    # Returns the key for the group at the period.  All periods are
    # internally stored relative to UTC.
    def key_period(group, period)
      "#{config.prefix}:#{group}:#{period_start(group, period).to_i}"
    end

    private
    def temp_bitmap
      temp_key = "#{config.prefix}:temp:#{SecureRandom.hex}"
      begin
        yield temp_key
      ensure
        config.redis_connection.del temp_key
      end
    end

    # Returns the time (UTC) that the period starts at for the given group
    def period_start(group, period)
      period.utc.send("beginning_of_#{config.group(group).reporting_interval}")
    end

    def seconds_in_reporting_interval(interval)
      case(interval.to_sym)
        when :day    then 60*60*24
        when :hour   then 60*60
        when :minute then 60
        else fail "Unknown reporting interval: #{interval}"
      end
    end
  end
end
