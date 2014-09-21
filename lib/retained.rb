require 'retained/tracker'
require 'retained/version'
require 'forwardable'

module Retained
  @tracker = Tracker.new

  class << self
    def method_missing(meth, *args, &block)
      @tracker.send(meth, *args, &block)
    end
  end
end
