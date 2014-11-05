require 'helper'
require 'securerandom'
require 'timecop'
Timecop.safe_mode = true


describe Retained::Tracker do
  let(:tracker) { Retained::Tracker.new }

  before(:each) do
    tracker.config.redis_connection.flushdb
  end

  it 'retain tracks using the default group in the current period' do
    Timecop.freeze(Time.new(2014, 8, 29, 9, 03, 35)) do
     tracker.retain('entity_a')
      prefix = tracker.config.prefix
      group  = tracker.config.default_group
      tracker.config.redis_connection.sparse_bitmap("#{prefix}:#{group}:1409328000")[0]
    end
  end

  it 'retain tracks the entity for the period specified' do
    period = Time.new(2014, 8, 30, 10, 47, 35)
    tracker.retain('entity_a', group: 'group_a', period: period)

    prefix = tracker.config.prefix
    tracker.config.redis_connection.sparse_bitmap("#{prefix}:group_a:1409356800")[0]
  end

  it 'retains using the "default" group' do
    tracker.retain('entity_a')
    tracker.groups.must_equal ['default']
  end

  it 'retain without a period tracks the entity for the current period' do
    Timecop.freeze(Time.new(2014, 8, 29, 9, 03, 35)) do
      tracker.retain('entity_a', group: 'group_a')

      prefix = tracker.config.prefix
      tracker.config.redis_connection.sparse_bitmap("#{prefix}:group_a:1409328000")[0]
    end
  end

  it 'total_active returns the number of active entities in the "default" group in the period' do
    period = Time.new(2014, 8, 30, 10, 47, 35)
    (count = rand(100)).times do |i|
      tracker.retain("entity_#{i}", period: period)
    end
    tracker.total_active(period: period).must_equal count
    tracker.total_active(group: "default", period: period).must_equal count
  end

  it 'total_active returns the number of active entities in the period' do
    period = Time.new(2014, 8, 30, 10, 47, 35)
    (count = rand(100)).times do |i|
      tracker.retain("entity_#{i}", group: 'group_a', period: period)
    end
    tracker.total_active(group: 'group_a', period: period).must_equal count
  end

  it 'total_active without a period returns the number of active entities for the current period' do
    (count = rand(100)).times do |i|
      tracker.retain("entity_#{i}", group: 'group_a', period: Time.now)
    end
    tracker.total_active(group: 'group_a').must_equal count
  end

  describe 'active?' do
    it 'returns true when the entity is active' do
      Timecop.freeze do
        tracker.retain('entity_a', group: 'group_a', period: Time.now)
        tracker.active?('entity_a', group: 'group_a', period: Time.now).must_equal true
        tracker.active?('entity_a', period: Time.now).must_equal true
        tracker.active?('entity_a').must_equal true
        tracker.active?('entity_a', group: ['group_a']).must_equal true
      end
    end

    it 'returns false when the entity was not active' do
      Timecop.freeze do
        tracker.retain('entity_a', group: 'group_a', period: Time.now)
        tracker.active?('entity_b').must_equal false
        tracker.active?('entity_a', group: 'group_b').must_equal false
      end
    end
  end

  it 'entity_index returns the offset' do
    group_a = SecureRandom.hex
    entity_a = SecureRandom.hex
    entity_b = SecureRandom.hex

    tracker.entity_index(entity_a, group_a).must_equal 0
    tracker.entity_index(entity_b, group_a).must_equal 1
    tracker.entity_index(SecureRandom.hex, group_a).must_equal 2
    tracker.entity_index(entity_a, SecureRandom.hex).must_equal 0
    tracker.entity_index(entity_b, group_a).must_equal 1
  end

  it 'key_period returns the proper key for the given period' do
    tracker.configure do |config|
      config.group('hour') { |g| g.reporting_interval = :hour }
      config.group('minute') { |g| g.reporting_interval = :minute }
      config.group('day') { |g| g.reporting_interval = :day}
    end

    tracker.key_period('hour', Time.new(2014, 8, 30, 10, 35, 47, 0)).must_equal 'retained:hour:1409392800'
    tracker.key_period('minute', Time.new(2014, 8, 30, 10, 35, 47, 5*3600)).must_equal 'retained:minute:1409376900'
    tracker.key_period('day', Time.new(2014, 8, 30, 10, 35, 47, -2*3600)).must_equal 'retained:day:1409356800'
  end
end
