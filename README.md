# Retained: Activity & Retention Tracking at Scale

Retained makes it easy to track activity and retention at scale in daily, hourly, or minute intervals using Redis bitmaps.


## Requirements

* Ruby 2.0.0 or above
* Redis

## Installing Retained

Use RubyGems to install Retained:

    $ gem install retained

If you are using Bundler, you can also install it by adding it to your Gemfile:

    gem 'retained'

Run `bundle install` to install.

## Basic Usage

Retained works by tracking whether an **entity** was active within a reporting interval for a specific **group**. Entities can be anything you wish to track activity for, and are identified by a unique identifier that you provide to Retained.  Groups provide a scope for the entities activity.  For example, groups allow you to track activity by a User (entity) for a specific feature of your product.  Like entities, groups are identified by a unique identifier that you provide to Retained.

### Retained Defaults

Retained's default settings are to connect to Redis at `redis://localhost:6379`, to prefix all keys with `retained`, and to track activity within the `default` group at a daily interval.  **Note:**  All dates are stored internally as UTC.

### Examples

To track an entity with an id of `entity_id` as active for the current day:

    Retained.retain('entity_id')

To track an entity with an id of `entity_id` as active on another day:

    Retained.retain('entity_id', period: Time.new(2013,10,1))

To query whether an entity was active on a given day:

    Retained.active?('entity_id', period: Time.new(2014,3,21))

To determine the total number of active entities on a given day:

    Retained.total_active(period: Time.new(2014,2,10))

To determine the total number of unique entities over a range:

    Retained.unique_active(start: Time.new(2014,2,10), stop: Time.new(2014,2,13)

## Advanced Usage

### Configuration

Retained can be configured with an alternate Redis connection string as well as an alternate prefix for keys:

    Retained.configure do |config|
      config.redis = 'redis://example.org:6379'
      config.prefix = 'my_prefix',
    end

You can also configure groups to use an alternate reporting interval-- either daily, hourly, or by minute.

**Important!** Once set, a group's reporting interval **cannot** be changed. 

For example, to configure a 'generated_report' group to use an hourly interval:

    Retained.configure do |config|
      config.group('generated_report).do |group|
        group.reporting_interval = :hour
      end
    end

If you need to have more control over the Redis connection (i.e. to use Sentinel), you can directly provide an already established connection:

    Retained.configure do |config|
      config.redis_connection = Redis.new
    end

### Non-Singleton Use

You can connect to multiple backends for Retained by instantiating a Retained tracker directly:

    tracker = Retained::Tracker.new
    tracker.configure do |config|
      config.redis = 'redis://other.example.org:6379'
    end
    tracker.retain('entity_id)

## Contributing to retained

* Check out the latest master to make sure the feature hasn't been implemented or the bug hasn't been fixed yet.
* Check out the issue tracker to make sure someone already hasn't requested it and/or contributed it.
* Fork the project.
* Start a feature/bugfix branch.
* Commit and push until you are happy with your contribution.
* Make sure to add tests for it. This is important so I don't break it in a future version unintentionally.
* Please try not to mess with the Rakefile, version, or history. If you want to have your own version, or is otherwise necessary, that is fine, but please isolate to its own commit so I can cherry-pick around it.


---
Copyright (c) 2014-2015 Mike Saffitz. See LICENSE.txt for further details.
