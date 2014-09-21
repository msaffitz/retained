require 'helper'

describe Retained::Configuration do
  let(:configuration) { Retained::Configuration.new }

  it 'configures groups' do
    configuration.group('group_a') do |group|
      group.reporting_interval = :day
    end
    configuration.group('group_a').reporting_interval.must_equal :day
  end

  it 'loads saved configuration' do
    configuration.group('group_b') do |group|
      group.reporting_interval = :minute
    end
    Retained::Configuration.new.group('group_b').reporting_interval.must_equal :minute
  end
end
