defmodule BlockScoutWeb.API.V2.MidlView do
  use BlockScoutWeb, :view

  alias Explorer.Chain.{Transaction, AddressesMap}
  alias Explorer.Chain
  alias Explorer.Repo
  alias Indexer.Util.EthAddressUtil
  alias Indexer.Util.BtcAddressUtil

  import Ecto.Query, only: [from: 2]

  require Logger

  @doc """
    Extends the json output for a transaction adding MIDL-related info to the output.

    ## Parameters
    - `out_json`: A map defining output json which will be extended.
    - `transaction`: transaction structure containing extra MIDL-related info.

    ## Returns
    An extended map containing `l1_*` and `op_withdrawals` items related to Optimism.
  """
  @spec extend_transaction_json_response(map(), %{
          :__struct__ => Explorer.Chain.Transaction,
          optional(any()) => any()
        }) :: map()
  def extend_transaction_json_response(out_json, %Transaction{} = transaction) do
    pubkey_hex = remove_0x_prefix_if_any(transaction.public_key)
    address_type_str = remove_0x_prefix_if_any(transaction.btc_address_byte) || "0"

    address_type =
      case Integer.parse(address_type_str) do
        {val, _} -> val
        :error -> 0
      end

    btc_address =
      if is_nil(pubkey_hex) or is_zero_64?(pubkey_hex) do
        nil
      else
        case get_btc_address_from_map(pubkey_hex) do
          nil ->
            Logger.warning("MidlView: BTC address not found in addresses_map for pubkey: #{String.slice(pubkey_hex, 0, 10)}..., computing fallback")
            computed_address = BtcAddressUtil.compute_btc_address(pubkey_hex, address_type)
            Logger.warning("MidlView: Using computed fallback BTC address: #{computed_address}")
            computed_address
          stored_address ->
            Logger.info("MidlView: Found BTC address in addresses_map: #{stored_address} for pubkey: #{String.slice(pubkey_hex, 0, 10)}...")
            stored_address
        end
      end

    eth_address =
      if is_nil(pubkey_hex) or is_zero_64?(pubkey_hex) do
        nil
      else
        case get_eth_address_from_map(pubkey_hex) do
          nil ->
            Logger.warning("MidlView: ETH address not found in addresses_map for pubkey: #{String.slice(pubkey_hex, 0, 10)}..., computing fallback")
            computed_address = EthAddressUtil.get_evm_address(pubkey_hex)
            Logger.warning("MidlView: Using computed fallback ETH address: #{computed_address}")
            computed_address
          stored_address ->
            Logger.info("MidlView: Found ETH address in addresses_map: #{stored_address} for pubkey: #{String.slice(pubkey_hex, 0, 10)}...")
            stored_address
        end
      end

    completion_tx =
      case Map.get(transaction, :completion_transaction) do
        %Ecto.Association.NotLoaded{} -> nil
        %{completion_tx: tx} -> tx
        _ -> nil
      end

    initiation_tx =
      case Map.get(transaction, :initiation_transaction) do
        %Ecto.Association.NotLoaded{} -> nil
        %{initiation_tx: tx} -> tx
        _ -> nil
      end

    btc_result_tx =
      case Map.get(transaction, :committed_send_event) do
        %Ecto.Association.NotLoaded{} -> nil
        %{btc_result_tx: tx} -> tx
        _ -> nil
      end

    out_json
    |> Map.put("btc_dapp_tx", remove_0x_prefix_if_any(transaction.btc_tx_hash))
    |> Map.put("public_key", pubkey_hex)
    |> Map.put("btc_address_byte", address_type_str)
    |> Map.put("btc_address", btc_address)
    |> Map.put("eth_address", eth_address)
    |> Map.put("intents", map_intents(transaction.intents))
    |> Map.put("completion_tx", completion_tx)
    |> Map.put("initiation_tx", initiation_tx)
    |> Map.put("btc_result_tx", remove_0x_prefix_if_any(btc_result_tx))
  end

  # Checks if a 64-char hex string consists entirely of '0'.
  # E.g. "0000000000000000000000000000000000000000000000000000000000000000"
  defp is_zero_64?(str) when is_binary(str) do
    String.length(str) == 64 and String.match?(str, ~r/^[0]+$/)
  end

  defp map_intents(nil), do: []
  defp map_intents(%Ecto.Association.NotLoaded{}), do: []

  defp map_intents(intents) when is_list(intents) do
    Enum.map(intents, &map_intent_transaction/1)
  end

  defp map_intent_transaction(%Transaction{} = intent_tx) do
    [decoded_input] = Transaction.decode_transactions([intent_tx], true, api?: true)

    %{
      "method" => Transaction.method_name(intent_tx, decoded_input),
      "hash" => intent_tx.hash,
      "status" => intent_tx.status
    }
  end

  def remove_0x_prefix_if_any(nil), do: nil

  @doc """
    Midl RPC returns BTC parameters: `btc_tx_hash`, `public_key`, `btc_address_byte` with 0x prefix.
    That is not consistent with the rest of the system, so we remove the prefix here.

    The solution is temporary. Prefix should be cleaned on the RPC side or saving to DB side.
  """
  def remove_0x_prefix_if_any(%Explorer.Chain.Hash{} = hash_struct) do
    # Convert the hash struct to a string, e.g. "0x9e48a19b..."
    hashed_string = Explorer.Chain.Hash.to_string(hash_struct)

    # If it starts with "0x", remove that prefix
    case hashed_string do
      "0x" <> rest -> rest
      other -> other
    end
  end

  @doc """
  Looks up BTC address from addresses_map table using public key.
  Returns the stored BTC address or nil if not found.
  """
    defp get_btc_address_from_map(pubkey_hex) when is_binary(pubkey_hex) do
    # Add 0x prefix for lookup since it's stored with prefix in the database
    pubkey_with_prefix = "0x" <> pubkey_hex

    case Chain.string_to_transaction_hash(pubkey_with_prefix) do
      {:ok, pubkey_hash} ->
        result = Repo.one(
          from(am in AddressesMap,
            where: am.public_key == ^pubkey_hash,
            select: am.btc_address
          )
        )

        case result do
          nil ->
            Logger.debug("MidlView: No addresses_map entry found for pubkey: #{String.slice(pubkey_hex, 0, 10)}...")
            nil
          btc_address ->
            Logger.debug("MidlView: Found addresses_map entry for pubkey: #{String.slice(pubkey_hex, 0, 10)}..., BTC address: #{btc_address}")
            btc_address
        end
      :error ->
        Logger.error("MidlView: Invalid public key format: #{String.slice(pubkey_hex, 0, 10)}...")
        nil
    end
  end

  defp get_btc_address_from_map(_), do: nil

  """
  Get ETH address from addresses_map by public key
  """
  defp get_eth_address_from_map(pubkey_hex) when is_binary(pubkey_hex) do
    pubkey_with_prefix = "0x" <> pubkey_hex

    case Chain.string_to_transaction_hash(pubkey_with_prefix) do
      {:ok, pubkey_hash} ->
        result = Repo.one(
          from(am in AddressesMap,
            where: am.public_key == ^pubkey_hash,
            select: am.eth_address
          )
        )

        case result do
          nil ->
            Logger.debug("MidlView: No addresses_map entry found for pubkey: #{String.slice(pubkey_hex, 0, 10)}...")
            nil
          eth_address ->
            Logger.debug("MidlView: Found addresses_map entry for pubkey: #{String.slice(pubkey_hex, 0, 10)}..., ETH address: #{eth_address}")
            eth_address
        end
      :error ->
        Logger.error("MidlView: Invalid public key format: #{String.slice(pubkey_hex, 0, 10)}...")
        nil
    end
  end

  defp get_eth_address_from_map(_), do: nil
end
