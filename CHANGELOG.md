# 0.2.3

  * Updated to latest redis-bitops, which includes multiple fixes
  and performance improvements.
  * Refactor to ensure that unique_active is properly measured
  across measurement periods.

# 0.2.2

  * Fixed default group.  Was erroneously using an empty string
  instead of the string 'default'.
  * Added unique_active method

# 0.2.1

  * Fixed ActiveSupport require declaration

# 0.2.0

  * Added support for directly providing a Redis connection
