require 'helper'
require 'securerandom'
require 'timecop'
Timecop.safe_mode = true

SECONDS_PER_HOUR = 60*60
SECONDS_PER_DAY  = 24*SECONDS_PER_HOUR

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
      tracker.active?('entity_a').must_equal true
    end
  end

  it 'retain tracks the entity for the period specified' do
    period = Time.new(2014, 8, 30, 10, 47, 35)
    tracker.retain('entity_a', group: 'group_a', period: period)

    prefix = tracker.config.prefix
    tracker.active?('entity_a', period: period).must_equal true
  end

  it 'retains using the "default" group' do
    tracker.retain('entity_a')
    tracker.groups.must_equal ['default']
  end

  it 'retain without a period tracks the entity for the current period' do
    Timecop.freeze(Time.new(2014, 8, 29, 9, 03, 35)) do
      tracker.retain('entity_a', group: 'group_a')

      prefix = tracker.config.prefix
      tracker.active?('entity_a', group: 'group_a', period: Time.now).must_equal true
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

  describe "unique_active" do
    before(:each) do
      tracker.configure do |config|
        config.group('hour') { |g| g.reporting_interval = :hour }
        config.group('minute') { |g| g.reporting_interval = :minute }
        config.group('day') { |g| g.reporting_interval = :day}
      end
    end

    it 'properly tracks uniques when the reporting_interval is day' do
      Timecop.freeze do
        (1..4).each { |e| tracker.retain(e, group: 'day', period: Time.now)}
        (2..4).each { |e| tracker.retain(e, group: 'day', period: Time.now - SECONDS_PER_DAY)}
        (2..5).each { |e| tracker.retain(e, group: 'day', period: Time.now - 2*SECONDS_PER_DAY)}
        (1..2).each { |e| tracker.retain(e, group: 'day', period: Time.now - 3*SECONDS_PER_DAY)}

        tracker.unique_active(group: 'day', start: Time.now - 2*SECONDS_PER_DAY).must_equal 5
        tracker.unique_active(group: 'day', start: Time.now - 2*SECONDS_PER_DAY, stop: Time.now - SECONDS_PER_DAY).must_equal 4
        tracker.unique_active(group: 'day', start: Time.now - 4*SECONDS_PER_DAY, stop: Time.now - 5*SECONDS_PER_DAY).must_equal 0
        tracker.unique_active(group: 'day', start: Time.now - 3*SECONDS_PER_DAY, stop: Time.now - 3*SECONDS_PER_DAY).must_equal 2
      end
    end

    it 'properly tracks uniques when the reporting_interval is hour' do
      Timecop.freeze do
        (1..2).each { |e| tracker.retain(e, group: 'hour', period: Time.now)}
        (3..4).each { |e| tracker.retain(e, group: 'hour', period: Time.now - 3*SECONDS_PER_HOUR)}
        (5..6).each { |e| tracker.retain(e, group: 'hour', period: Time.now - 4*SECONDS_PER_HOUR)}
        (6..8).each { |e| tracker.retain(e, group: 'hour', period: Time.now - 6*SECONDS_PER_HOUR)}

        tracker.unique_active(group: 'hour', start: Time.now - 4*SECONDS_PER_HOUR).must_equal 6
        tracker.unique_active(group: 'hour', start: Time.now - 2*SECONDS_PER_HOUR, stop: Time.now - SECONDS_PER_HOUR).must_equal 0
        # tracker.unique_active(group: 'hour', start: Time.now - 6*SECONDS_PER_HOUR, stop: Time.now - 4*SECONDS_PER_HOUR).must_equal 4
        # tracker.unique_active(group: 'hour', start: Time.now - 6*SECONDS_PER_HOUR, stop: Time.now - 3*SECONDS_PER_HOUR).must_equal 7
      end
    end

    it 'properly tracks uniques when the reporting_interval is minute' do
      Timecop.freeze do
        (1..2).each { |e| tracker.retain(e, group: 'minute', period: Time.now)}
        (3..5).each { |e| tracker.retain(e, group: 'minute', period: Time.now - 2*60)}
        (2..3).each { |e| tracker.retain(e, group: 'minute', period: Time.now - 4*60)}
        (6..7).each { |e| tracker.retain(e, group: 'minute', period: Time.now - 5*60)}

        tracker.unique_active(group: 'minute', start: Time.now - 5*60).must_equal 7
        tracker.unique_active(group: 'minute', start: Time.now - 2*60, stop: Time.now).must_equal 5
        tracker.unique_active(group: 'minute', start: Time.now - 5*60, stop: Time.now - 4*60).must_equal 4
      end
    end
  end

  describe "total_retained" do
    before(:each) do
      tracker.configure do |config|
        config.group('hour') { |g| g.reporting_interval = :hour }
        config.group('minute') { |g| g.reporting_interval = :minute }
        config.group('day') { |g| g.reporting_interval = :day}
      end
    end

    it 'properly tracks retention when the reporting_interval is day' do
      Timecop.freeze do
        # Initial Period
        [1,2].each { |e| tracker.retain(e, group: 'day', period: Time.now - 4*SECONDS_PER_DAY)}
        [3,4].each { |e| tracker.retain(e, group: 'day', period: Time.now - 3*SECONDS_PER_DAY)}

        # Final Period
        tracker.retain(2, group: 'day', period: Time.now)
        tracker.retain(3, group: 'day', period: Time.now - 2*SECONDS_PER_DAY)

        tracker.total_retained(group: 'day', initial_start: Time.now - 4*SECONDS_PER_DAY, initial_stop: Time.now - 3*SECONDS_PER_DAY,
                                             final_start:   Time.now - 2*SECONDS_PER_DAY, final_stop:   Time.now                     ).must_equal 2
        tracker.total_retained(group: 'day', initial_start: Time.now - 4*SECONDS_PER_DAY, initial_stop: Time.now - 3*SECONDS_PER_DAY,
                                             final_start:   Time.now                    , final_stop:   Time.now                     ).must_equal 1
      end
    end

    it 'properly tracks retention when the reporting_interval is hour' do
      Timecop.freeze do
        # Initial Period
        [1,2].each { |e| tracker.retain(e, group: 'hour', period: Time.now - 4*SECONDS_PER_HOUR)}
        [3,4].each { |e| tracker.retain(e, group: 'hour', period: Time.now - 3*SECONDS_PER_HOUR)}

        # Final Period
        tracker.retain(2, group: 'hour', period: Time.now)
        tracker.retain(3, group: 'hour', period: Time.now - 2*SECONDS_PER_HOUR)

        tracker.total_retained(group: 'hour', initial_start: Time.now - 4*SECONDS_PER_HOUR, initial_stop: Time.now - 3*SECONDS_PER_HOUR,
                                              final_start:   Time.now - 2*SECONDS_PER_HOUR, final_stop:   Time.now                      ).must_equal 2
        tracker.total_retained(group: 'hour', initial_start: Time.now - 4*SECONDS_PER_HOUR, initial_stop: Time.now - 3*SECONDS_PER_HOUR,
                                              final_start:   Time.now                     , final_stop:   Time.now                      ).must_equal 1
      end
    end

    it 'properly tracks retention when the reporting_interval is minute' do
      Timecop.freeze do
        # Initial Period
        [1,2].each { |e| tracker.retain(e, group: 'minute', period: Time.now - 4*60)}
        [3,4].each { |e| tracker.retain(e, group: 'minute', period: Time.now - 3*60)}

        # Final Period
        tracker.retain(2, group: 'minute', period: Time.now)
        tracker.retain(3, group: 'minute', period: Time.now - 2*60)

        tracker.total_retained(group: 'minute', initial_start: Time.now - 4*60, initial_stop: Time.now - 3*60,
                                                final_start:   Time.now - 2*60, final_stop:   Time.now        ).must_equal 2
        tracker.total_retained(group: 'minute', initial_start: Time.now - 4*60, initial_stop: Time.now - 3*60,
                                                final_start:   Time.now       , final_stop:    Time.now       ).must_equal 1
      end
    end
  end

  it 'retention properly returns retention percent' do
    Timecop.freeze do
      # Initial Period
      [1,2].each { |e| tracker.retain(e, group: 'minute', period: Time.now - 4*SECONDS_PER_DAY)}
      [3,4].each { |e| tracker.retain(e, group: 'minute', period: Time.now - 3*SECONDS_PER_DAY)}

      # Final Period
      tracker.retain(2, group: 'minute', period: Time.now)
      tracker.retain(3, group: 'minute', period: Time.now - 2*SECONDS_PER_DAY)

      tracker.retention(group: 'minute', initial_start: Time.now - 4*SECONDS_PER_DAY, initial_stop: Time.now - 3*SECONDS_PER_DAY,
                                         final_start:   Time.now - 2*SECONDS_PER_DAY, final_stop:   Time.now                     ).must_equal 0.5

      tracker.retention(group: 'minute', initial_start: Time.now - 4*SECONDS_PER_DAY, initial_stop: Time.now - 3*SECONDS_PER_DAY,
                                         final_start:   Time.now                    , final_stop:   Time.now                     ).must_equal 0.25
    end
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

  it 'temp_bitmap cleans up the temporary bitmap' do
    tmp_key = nil
    tracker.send(:temp_bitmap) do |key|
      tmp_key = key
      tracker.config.redis_connection.setbit key, 0, 1
    end
    tracker.config.redis_connection.exists(tmp_key).must_equal false
  end

  it 'temp_bitmap cleans up the temporary bitmap with exception raised' do
    tmp_key = nil
    begin
      tracker.send(:temp_bitmap) do |key|
        tmp_key = key
        tracker.config.redis_connection.setbit key, 0, 1
        raise 'exception'
      end
    rescue
    end
    tracker.config.redis_connection.exists(tmp_key).must_equal false
  end

  it 'temp_bitmap returns the value' do
    tracker.send(:temp_bitmap) do |key|
      4
    end.must_equal 4
  end
end
