defmodule Explorer.Chain.TokenTransferTest do
  use Explorer.DataCase

  import Explorer.Factory

  alias Explorer.PagingOptions
  alias Explorer.Chain.TokenTransfer

  doctest Explorer.Chain.TokenTransfer

  describe "fetch_token_transfers_from_token_hash/2" do
    test "returns token transfers for the given address" do
      token_contract_address = insert(:contract_address)

      token = insert(:token, contract_address: token_contract_address)

      transaction =
        :transaction
        |> insert()
        |> with_block()

      token_transfer =
        insert(
          :token_transfer,
          to_address: build(:address),
          transaction: transaction,
          token_contract_address: token_contract_address,
          token: token
        )

      another_transaction =
        :transaction
        |> insert()
        |> with_block()

      another_transfer =
        insert(
          :token_transfer,
          to_address: build(:address),
          transaction: another_transaction,
          token_contract_address: token_contract_address,
          token: token
        )

      insert(
        :token_transfer,
        to_address: build(:address),
        transaction: transaction,
        token_contract_address: build(:address),
        token: token
      )

      transfers_primary_keys =
        token_contract_address.hash
        |> TokenTransfer.fetch_token_transfers_from_token_hash([])
        |> Enum.map(&{&1.transaction_hash, &1.log_index})

      assert transfers_primary_keys == [
               {another_transfer.transaction_hash, another_transfer.log_index},
               {token_transfer.transaction_hash, token_transfer.log_index}
             ]
    end

    test "when there isn't token transfers won't show anything" do
      token_contract_address = insert(:contract_address)

      insert(:token, contract_address: token_contract_address)

      transfers_ids =
        token_contract_address.hash
        |> TokenTransfer.fetch_token_transfers_from_token_hash([])
        |> Enum.map(& &1.id)

      assert transfers_ids == []
    end

    test "token transfers can be paginated" do
      token_contract_address = insert(:contract_address)

      transaction =
        :transaction
        |> insert()
        |> with_block()

      token = insert(:token)

      second_page =
        insert(
          :token_transfer,
          block_number: 999,
          to_address: build(:address),
          transaction: transaction,
          token_contract_address: token_contract_address,
          token: token
        )

      first_page =
        insert(
          :token_transfer,
          block_number: 1000,
          to_address: build(:address),
          transaction: transaction,
          token_contract_address: token_contract_address,
          token: token
        )

      paging_options = %PagingOptions{key: {first_page.block_number, first_page.log_index}, page_size: 1}

      token_transfers_primary_keys_paginated =
        token_contract_address.hash
        |> TokenTransfer.fetch_token_transfers_from_token_hash(paging_options: paging_options)
        |> Enum.map(&{&1.transaction_hash, &1.log_index})

      assert token_transfers_primary_keys_paginated == [{second_page.transaction_hash, second_page.log_index}]
    end

    test "paginates considering the log_index when there are repeated block numbers" do
      token_contract_address = insert(:contract_address)

      transaction =
        :transaction
        |> insert()
        |> with_block()

      token = insert(:token)

      token_transfer =
        insert(
          :token_transfer,
          block_number: 1000,
          log_index: 0,
          to_address: build(:address),
          transaction: transaction,
          token_contract_address: token_contract_address,
          token: token
        )

      paging_options = %PagingOptions{key: {token_transfer.block_number, token_transfer.log_index + 1}, page_size: 1}

      token_transfers_primary_keys_paginated =
        token_contract_address.hash
        |> TokenTransfer.fetch_token_transfers_from_token_hash(paging_options: paging_options)
        |> Enum.map(&{&1.transaction_hash, &1.log_index})

      assert token_transfers_primary_keys_paginated == [{token_transfer.transaction_hash, token_transfer.log_index}]
    end
  end

  describe "where_any_address_fields_match/3" do
    test "when to_address_hash match returns transactions hashes list" do
      john = insert(:address)
      paul = insert(:address)
      contract_address = insert(:contract_address)

      transaction =
        :transaction
        |> insert(
          from_address: john,
          from_address_hash: john.hash,
          to_address: contract_address,
          to_address_hash: contract_address.hash
        )
        |> with_block()

      insert(
        :token_transfer,
        from_address: john,
        to_address: paul,
        transaction: transaction,
        amount: 1
      )

      insert(
        :token_transfer,
        from_address: john,
        to_address: paul,
        transaction: transaction,
        amount: 1
      )

      {:ok, transaction_bytes} = Explorer.Chain.Hash.Full.dump(transaction.hash)

      transactions_hashes = TokenTransfer.where_any_address_fields_match(:to, paul.hash, %PagingOptions{page_size: 1})

      assert Enum.member?(transactions_hashes, transaction_bytes) == true
    end

    test "when from_address_hash match returns transactions hashes list" do
      john = insert(:address)
      paul = insert(:address)
      contract_address = insert(:contract_address)

      transaction =
        :transaction
        |> insert(
          from_address: john,
          from_address_hash: john.hash,
          to_address: contract_address,
          to_address_hash: contract_address.hash
        )
        |> with_block()

      insert(
        :token_transfer,
        from_address: john,
        to_address: paul,
        transaction: transaction,
        amount: 1
      )

      insert(
        :token_transfer,
        from_address: john,
        to_address: paul,
        transaction: transaction,
        amount: 1
      )

      {:ok, transaction_bytes} = Explorer.Chain.Hash.Full.dump(transaction.hash)

      transactions_hashes = TokenTransfer.where_any_address_fields_match(:from, john.hash, %PagingOptions{page_size: 1})

      assert Enum.member?(transactions_hashes, transaction_bytes) == true
    end

    test "when to_from_address_hash or from_address_hash match returns transactions hashes list" do
      john = insert(:address)
      paul = insert(:address)
      contract_address = insert(:contract_address)

      transaction_one =
        :transaction
        |> insert(
          from_address: john,
          from_address_hash: john.hash,
          to_address: contract_address,
          to_address_hash: contract_address.hash
        )
        |> with_block()

      insert(
        :token_transfer,
        from_address: john,
        to_address: paul,
        transaction: transaction_one,
        amount: 1
      )

      transaction_two =
        :transaction
        |> insert(
          from_address: john,
          from_address_hash: john.hash,
          to_address: contract_address,
          to_address_hash: contract_address.hash
        )
        |> with_block()

      insert(
        :token_transfer,
        from_address: paul,
        to_address: john,
        transaction: transaction_two,
        amount: 1
      )

      {:ok, transaction_one_bytes} = Explorer.Chain.Hash.Full.dump(transaction_one.hash)
      {:ok, transaction_two_bytes} = Explorer.Chain.Hash.Full.dump(transaction_two.hash)

      transactions_hashes = TokenTransfer.where_any_address_fields_match(nil, john.hash, %PagingOptions{page_size: 2})

      assert Enum.member?(transactions_hashes, transaction_one_bytes) == true
      assert Enum.member?(transactions_hashes, transaction_two_bytes) == true
    end

    test "paginates result from to_from_address_hash and from_address_hash match" do
      john = insert(:address)
      paul = insert(:address)
      contract_address = insert(:contract_address)

      transaction_one =
        :transaction
        |> insert(
          from_address: paul,
          from_address_hash: paul.hash,
          to_address: contract_address,
          to_address_hash: contract_address.hash
        )
        |> with_block(number: 1)

      insert(
        :token_transfer,
        from_address: john,
        to_address: paul,
        transaction: transaction_one,
        amount: 1
      )

      transaction_two =
        :transaction
        |> insert(
          from_address: paul,
          from_address_hash: paul.hash,
          to_address: contract_address,
          to_address_hash: contract_address.hash
        )
        |> with_block(number: 2)

      insert(
        :token_transfer,
        from_address: paul,
        to_address: john,
        transaction: transaction_two,
        amount: 1
      )

      {:ok, transaction_one_bytes} = Explorer.Chain.Hash.Full.dump(transaction_one.hash)

      page_two =
        TokenTransfer.where_any_address_fields_match(nil, john.hash, %PagingOptions{
          page_size: 1,
          key: {transaction_two.block_number, transaction_two.index}
        })

      assert Enum.member?(page_two, transaction_one_bytes) == true
    end
  end

  describe "fetch/1 with activity filtering" do
    @burn_address_hash_string "0x0000000000000000000000000000000000000000"

    setup do
      {:ok, burn_address_hash} = Explorer.Chain.string_to_address_hash(@burn_address_hash_string)
      burn_address = insert(:address, hash: burn_address_hash)
      regular_address_1 = insert(:address)
      regular_address_2 = insert(:address)
      token_contract_address = insert(:contract_address)
      token = insert(:token, contract_address: token_contract_address)

      {:ok,
       burn_address: burn_address,
       regular_address_1: regular_address_1,
       regular_address_2: regular_address_2,
       token: token,
       token_contract_address: token_contract_address}
    end

    defp create_token_transfer(from_address, to_address, token, token_contract_address, block_number) do
      transaction =
        :transaction
        |> insert()
        |> with_block(number: block_number)

      insert(
        :token_transfer,
        from_address: from_address,
        to_address: to_address,
        transaction: transaction,
        token_contract_address: token_contract_address,
        token: token,
        block_number: block_number
      )
    end

    test "filters MINTING transfers (from burn address to regular address)", context do
      %{
        burn_address: burn_address,
        regular_address_1: regular_address_1,
        regular_address_2: regular_address_2,
        token: token,
        token_contract_address: token_contract_address
      } = context

      # Minting: from burn to regular
      minting_transfer = create_token_transfer(burn_address, regular_address_1, token, token_contract_address, 1000)

      # Regular transfer: should be excluded
      _regular_transfer = create_token_transfer(regular_address_1, regular_address_2, token, token_contract_address, 999)

      results = TokenTransfer.fetch(activity: ["MINTING"], paging_options: %PagingOptions{page_size: 10})
      result_keys = Enum.map(results, &{&1.transaction_hash, &1.log_index})

      assert {minting_transfer.transaction_hash, minting_transfer.log_index} in result_keys
      assert length(results) == 1
    end

    test "filters BURNING transfers (from regular address to burn address)", context do
      %{
        burn_address: burn_address,
        regular_address_1: regular_address_1,
        regular_address_2: regular_address_2,
        token: token,
        token_contract_address: token_contract_address
      } = context

      # Burning: from regular to burn
      burning_transfer = create_token_transfer(regular_address_1, burn_address, token, token_contract_address, 1000)

      # Regular transfer: should be excluded
      _regular_transfer = create_token_transfer(regular_address_1, regular_address_2, token, token_contract_address, 999)

      results = TokenTransfer.fetch(activity: ["BURNING"], paging_options: %PagingOptions{page_size: 10})
      result_keys = Enum.map(results, &{&1.transaction_hash, &1.log_index})

      assert {burning_transfer.transaction_hash, burning_transfer.log_index} in result_keys
      assert length(results) == 1
    end

    test "filters SPAWNING transfers (from burn address to burn address)", context do
      %{
        burn_address: burn_address,
        regular_address_1: regular_address_1,
        regular_address_2: regular_address_2,
        token: token,
        token_contract_address: token_contract_address
      } = context

      # Spawning: from burn to burn
      spawning_transfer = create_token_transfer(burn_address, burn_address, token, token_contract_address, 1000)

      # Regular transfer: should be excluded
      _regular_transfer = create_token_transfer(regular_address_1, regular_address_2, token, token_contract_address, 999)

      results = TokenTransfer.fetch(activity: ["SPAWNING"], paging_options: %PagingOptions{page_size: 10})
      result_keys = Enum.map(results, &{&1.transaction_hash, &1.log_index})

      assert {spawning_transfer.transaction_hash, spawning_transfer.log_index} in result_keys
      assert length(results) == 1
    end

    test "filters TRANSFER (regular transfers between non-burn addresses)", context do
      %{
        burn_address: burn_address,
        regular_address_1: regular_address_1,
        regular_address_2: regular_address_2,
        token: token,
        token_contract_address: token_contract_address
      } = context

      # Regular transfer: between non-burn addresses
      regular_transfer = create_token_transfer(regular_address_1, regular_address_2, token, token_contract_address, 1000)

      # Minting: should be excluded
      _minting_transfer = create_token_transfer(burn_address, regular_address_1, token, token_contract_address, 999)

      results = TokenTransfer.fetch(activity: ["TRANSFER"], paging_options: %PagingOptions{page_size: 10})
      result_keys = Enum.map(results, &{&1.transaction_hash, &1.log_index})

      assert {regular_transfer.transaction_hash, regular_transfer.log_index} in result_keys
      assert length(results) == 1
    end

    test "filters multiple activity types (MINTING and BURNING)", context do
      %{
        burn_address: burn_address,
        regular_address_1: regular_address_1,
        regular_address_2: regular_address_2,
        token: token,
        token_contract_address: token_contract_address
      } = context

      # Minting
      minting_transfer = create_token_transfer(burn_address, regular_address_1, token, token_contract_address, 1000)

      # Burning
      burning_transfer = create_token_transfer(regular_address_1, burn_address, token, token_contract_address, 999)

      # Regular transfer: should be excluded
      _regular_transfer = create_token_transfer(regular_address_1, regular_address_2, token, token_contract_address, 998)

      results = TokenTransfer.fetch(activity: ["MINTING", "BURNING"], paging_options: %PagingOptions{page_size: 10})
      result_keys = Enum.map(results, &{&1.transaction_hash, &1.log_index})

      assert {minting_transfer.transaction_hash, minting_transfer.log_index} in result_keys
      assert {burning_transfer.transaction_hash, burning_transfer.log_index} in result_keys
      assert length(results) == 2
    end

    test "empty activity list returns all transfers", context do
      %{
        burn_address: burn_address,
        regular_address_1: regular_address_1,
        regular_address_2: regular_address_2,
        token: token,
        token_contract_address: token_contract_address
      } = context

      _minting_transfer = create_token_transfer(burn_address, regular_address_1, token, token_contract_address, 1000)
      _regular_transfer = create_token_transfer(regular_address_1, regular_address_2, token, token_contract_address, 999)

      results = TokenTransfer.fetch(activity: [], paging_options: %PagingOptions{page_size: 10})

      assert length(results) == 2
    end

    test "invalid activity types are ignored", context do
      %{
        burn_address: burn_address,
        regular_address_1: regular_address_1,
        regular_address_2: regular_address_2,
        token: token,
        token_contract_address: token_contract_address
      } = context

      minting_transfer = create_token_transfer(burn_address, regular_address_1, token, token_contract_address, 1000)
      _regular_transfer = create_token_transfer(regular_address_1, regular_address_2, token, token_contract_address, 999)

      # Mix valid and invalid activity types
      results = TokenTransfer.fetch(activity: ["MINTING", "INVALID_TYPE"], paging_options: %PagingOptions{page_size: 10})
      result_keys = Enum.map(results, &{&1.transaction_hash, &1.log_index})

      assert {minting_transfer.transaction_hash, minting_transfer.log_index} in result_keys
      assert length(results) == 1
    end

    test "all invalid activity types returns all transfers", context do
      %{
        burn_address: burn_address,
        regular_address_1: regular_address_1,
        regular_address_2: regular_address_2,
        token: token,
        token_contract_address: token_contract_address
      } = context

      _minting_transfer = create_token_transfer(burn_address, regular_address_1, token, token_contract_address, 1000)
      _regular_transfer = create_token_transfer(regular_address_1, regular_address_2, token, token_contract_address, 999)

      # All invalid types - should behave like empty filter
      results = TokenTransfer.fetch(activity: ["INVALID", "ALSO_INVALID"], paging_options: %PagingOptions{page_size: 10})

      assert length(results) == 2
    end
  end

  describe "uncataloged_token_transfer_block_numbers/0" do
    test "returns a list of block numbers" do
      block = insert(:block)
      address = insert(:address)

      log =
        insert(:token_transfer_log,
          transaction:
            insert(:transaction,
              block_number: block.number,
              block_hash: block.hash,
              cumulative_gas_used: 0,
              gas_used: 0,
              index: 0
            ),
          block: block,
          address_hash: address.hash
        )

      block_number = log.block_number
      assert {:ok, [^block_number]} = TokenTransfer.uncataloged_token_transfer_block_numbers()
    end
  end
end
