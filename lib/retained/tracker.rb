require 'redis/bitops'
require 'active_support/core_ext/time/calculations'
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
      bitmap = config.redis_connection.sparse_bitmap(key_period(group, period))
      bitmap[index] = true
    end

    # Total active entities in the period, or now if now period,
    # is provided.
    def total_active(group: 'default', period: Time.now)
      bitmap = config.redis_connection.sparse_bitmap(key_period(group, period))
      bitmap.bitcount
    end

    # Returns true if the entity was active in the given period,
    # or now if now period is provided.  If a group or an array of groups
    # is provided activity will only be considered based on those groups.
    def active?(entity, group: nil, period: Time.now)
      group = [group] if group.is_a?(String)
      group = groups if group == [] || !group

      group.to_a.each do |g|
        bitmap = config.redis_connection.sparse_bitmap(key_period(g, period))
        index = entity_index(entity, g)
        return bitmap[index] if bitmap[index]
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
      period = period.utc.send("beginning_of_#{config.group(group).reporting_interval}")
      "#{config.prefix}:#{group}:#{period.to_i}"
    end
  end
end
