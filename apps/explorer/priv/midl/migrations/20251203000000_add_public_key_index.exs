defmodule Explorer.Repo.Midl.Migrations.AddPublicKeyIndex do
  use Ecto.Migration

  @disable_ddl_transaction true
  @disable_migration_lock true

  def change do
    create_if_not_exists index(:transactions, [:public_key],
      name: :index_transactions_on_public_key,
      concurrently: true)
  end
end
