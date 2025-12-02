defmodule BlockScoutWeb.API.V2.InternalTransactionController do
  use BlockScoutWeb, :controller
  alias Explorer.Chain.InternalTransaction
  alias Explorer.{Helper, PagingOptions}

  import BlockScoutWeb.Chain,
    only: [
      split_list_by_page: 1,
      split_list_by_page: 2,
      paging_options: 1,
      next_page_params: 3
    ]

  import BlockScoutWeb.PagingHelper,
    only: [
      delete_parameters_from_next_page_params: 1
    ]

  import Explorer.PagingOptions, only: [default_paging_options: 0]

  action_fallback(BlockScoutWeb.API.V2.FallbackController)

  @api_true [api?: true]

  @doc """
    Function to handle GET requests to `/api/v2/internal-transactions` endpoint.
  """
  @spec internal_transactions(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def internal_transactions(conn, params) do
    paging_options = paging_options(params)

    parsed_limit = Helper.parse_integer(params["limit"])
    page_size = if parsed_limit && parsed_limit > 0, do: min(50, parsed_limit), else: 50

    options =
      paging_options
      |> Keyword.update(:paging_options, default_paging_options(), fn paging_options ->
        %PagingOptions{paging_options | page_size: page_size + 1}
      end)
      |> Keyword.merge(@api_true)

    result =
      options
      |> InternalTransaction.fetch()
      |> split_list_by_page(page_size)

    {internal_transactions, next_page} = result

    next_page_params =
      next_page |> next_page_params(internal_transactions, delete_parameters_from_next_page_params(params))

    conn
    |> put_status(200)
    |> render(:internal_transactions, %{
      internal_transactions: internal_transactions,
      next_page_params: next_page_params
    })
  end
end
