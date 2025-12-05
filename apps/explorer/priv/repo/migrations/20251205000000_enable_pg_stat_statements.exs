defmodule Explorer.Repo.Migrations.EnablePgStatStatements do
  use Ecto.Migration

  @moduledoc """
  Enables the pg_stat_statements extension for query performance monitoring.

  This extension provides detailed statistics about query execution times, call counts,
  and resource usage. It's essential for identifying slow queries and optimizing
  database performance.

  Note: This migration requires the extension to be preloaded via shared_preload_libraries.
  Add to postgresql.conf or database flags:
    shared_preload_libraries = 'pg_stat_statements'

  Then restart PostgreSQL before running this migration.
  """

  def up do
    execute("CREATE EXTENSION IF NOT EXISTS pg_stat_statements")

    # Create a helpful comment
    execute("""
    COMMENT ON EXTENSION pg_stat_statements IS
    'Track planning and execution statistics of all SQL statements. '
    'Use SELECT * FROM pg_stat_statements ORDER BY mean_exec_time DESC LIMIT 20 '
    'to find slow queries. Reset stats with SELECT pg_stat_statements_reset();'
    """)
  end

  def down do
    execute("DROP EXTENSION IF EXISTS pg_stat_statements CASCADE")
  end
end
