require 'helper'

describe Retained::GroupConfiguration do
  let(:group_configuration) { Retained::GroupConfiguration.new }

  it 'reporting_interval is set' do
    group_configuration.reporting_interval = :day
    group_configuration.reporting_interval.must_equal :day
  end

  it 'reporting_interval cannot be changed once set' do
    group_configuration.reporting_interval = :day
    proc { group_configuration.reporting_interval = 'month' }.must_raise RuntimeError
  end

  it 'reporting_interval must be hour, minute, or day' do
    proc { group_configuration.reporting_interval = :week }.must_raise ArgumentError
    proc { group_configuration.reporting_interval = 'month' }.must_raise ArgumentError
  end
end
