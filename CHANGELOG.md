# 0.3.2

  * Remove redis gem dependency version
  * Added total_retained and retention methods for directly
  calculating retention between to period ranges.

# 0.3.1

  * Update redis gem dependency to ~3.2

# 0.3.0

  * BREAKING CHANGE:  Removed dependency on redis-bitops, which
  while conserving space resulted in significant degradation of
  performance due to the additional overhead of tracking chunks
  and additional bit operations.

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
