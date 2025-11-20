defmodule BlockScoutWeb.GraphQL.Resolvers.TokenBalance do
  @moduledoc """
  Resolver for token balance queries in GraphQL API.
  """

  alias Absinthe.Relay.Connection
  alias Explorer.Chain.Address
  alias Explorer.Chain.Address.CurrentTokenBalance
  alias Explorer.Repo

  @doc """
  Resolves token balances for a given address.

  By default, filters out zero-balance tokens (value > 0).
  Supports pagination through Relay connection pattern.
  Orders results by token value in descending order.
  """
  def get_by(%Address{hash: address_hash}, args, _) do
    connection_args = Map.take(args, [:after, :before, :first, :last])

    address_hash
    |> query_token_balances(args)
    |> Connection.from_query(&Repo.replica().all/1, connection_args, options(args))
  end

  defp query_token_balances(address_hash, args) do
    include_zero = Map.get(args, :include_zero_balances, false)

    query =
      if include_zero do
        # Use include_unfetched to get ALL balances including zeros
        CurrentTokenBalance.last_token_balances_include_unfetched(address_hash)
      else
        # Use regular function which filters value > 0
        CurrentTokenBalance.last_token_balances(address_hash)
      end

    order_by_value(query)
  end

  defp order_by_value(query) do
    import Ecto.Query, only: [order_by: 3]
    order_by(query, [tb], desc: tb.value, desc: tb.id)
  end

  defp options(%{before: _}), do: []
  defp options(%{count: count}), do: [count: count]
  defp options(_), do: []
end
