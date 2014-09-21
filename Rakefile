# encoding: utf-8

require 'rubygems'
require 'bundler'
begin
  Bundler.setup(:default, :development)
rescue Bundler::BundlerError => e
  $stderr.puts e.message
  $stderr.puts 'Run `bundle install` to install missing gems'
  exit e.status_code
end
require 'rake'

require 'jeweler'
require './lib/retained/version.rb'
Jeweler::Tasks.new do |gem|
  # gem is a Gem::Specification... see http://guides.rubygems.org/specification-reference/ for more options
  gem.name = 'retained'
  gem.homepage = 'http://github.com/msaffitz/retained'
  gem.license = 'MIT'
  gem.summary = %Q{Activity & Retention Tracking at Scale}
  gem.description = %Q{
    Easy tracking of activity and retention at scale in daily, hourly, or minute intervals
    using sparse Redis bitmaps.
  }
  gem.email = 'm@saffitz.com'
  gem.authors = ['Mike Saffitz']
  gem.version = Retained::Version::STRING
  # dependencies defined in Gemfile
end
Jeweler::RubygemsDotOrgTasks.new

require 'rake/testtask'
Rake::TestTask.new(:test) do |test|
  test.libs << 'lib' << 'test'
  test.pattern = 'test/**/*_spec.rb'
  test.verbose = true
end

desc 'Code coverage detail'
task :simplecov do
  ENV['COVERAGE'] = 'true'
  Rake::Task['test'].execute
end

task :default => :test

require 'yard'
YARD::Rake::YardocTask.new
