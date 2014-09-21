module Retained
  class GroupConfiguration
    attr_reader :reporting_interval

    ReportingIntervals = %i(day hour minute).freeze

    def initialize(options = {})
      @reporting_interval = nil

      options.each do |key, value|
        send("#{key}=", value)
      end
    end

    def reporting_interval=(reporting_interval)
      reporting_interval = reporting_interval.to_sym

      if @reporting_interval && @reporting_interval != reporting_interval
        fail 'Group reporting_interval is immutable once set'
      elsif !ReportingIntervals.include?(reporting_interval)
        fail ArgumentError, "Invalid reporting_interval: `#{reporting_interval}`.  Must be one of #{ReportingIntervals}"
      end

      @reporting_interval = reporting_interval
    end

    def set_defaults
      @reporting_interval ||= :day
    end

    # Returns the configuration as a hash of key/values
    def to_hash
      {
        reporting_interval: reporting_interval
      }
    end
  end
end
