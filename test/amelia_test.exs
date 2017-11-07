defmodule AmeliaTest do
  use ExUnit.Case
  doctest Amelia

  setup do
    {:ok, genserver} = Amelia.start_link
    {:ok, process: genserver}
  end

  test "that there is no lock to start", %{process: process} do
    assert GenServer.call(process, :is_locked) == false
  end

  test "that lock and unlock work", %{process: process} do
    assert GenServer.call(process, :is_locked) == false
    :ok = GenServer.call process, {:lock, :test}
    assert GenServer.call(process, :is_locked) == true
    :ok = GenServer.call process, {:unlock, :test}
    assert GenServer.call(process, :is_locked) == false
  end

  test "that lock and unlock work over time", %{process: process} do
    assert GenServer.call(process, :is_locked) == false
    :timer.sleep 1000
    assert GenServer.call(process, :is_locked) == false
    :timer.sleep 1000
    assert GenServer.call(process, :is_locked) == false
    :ok = GenServer.call process, {:lock, :test}
    assert GenServer.call(process, :is_locked) == true
    :timer.sleep 1000
    assert GenServer.call(process, :is_locked) == true
    :ok = GenServer.call process, {:unlock, :test}
    :timer.sleep 1000
    assert GenServer.call(process, :is_locked) == false
  end

  test "that timelock works", %{process: process} do
    assert GenServer.call(process, :is_locked) == false
    :ok = GenServer.call process, {:timelock, :test, 1500}, 10000
    assert GenServer.call(process, :is_locked) == true
    :timer.sleep 1000
    assert GenServer.call(process, :is_locked) == true
    :timer.sleep 1000
    assert GenServer.call(process, :is_locked) == false
  end

  test "that datalock works", %{process: process} do
    assert GenServer.call(process, :is_locked) == false
    :ok = GenServer.call process, {:datalock, :test, :test}
    assert GenServer.call(process, :is_locked) == true
    assert GenServer.call(process, :get_lock_data) == :test
    :ok = GenServer.call process, {:dataunlock, :test, :test}
    assert GenServer.call(process, :is_locked) == false
  end

  test "that datalock disallows standard unlock", %{process: process} do
    assert GenServer.call(process, :is_locked) == false
    :ok = GenServer.call process, {:datalock, :test, :test}
    assert GenServer.call(process, :is_locked) == true
    assert GenServer.call(process, :get_lock_data) == :test
    assert GenServer.call(process, :get_lock_data) != nil
    :ok = GenServer.call process, {:unlock, :test}
    assert GenServer.call(process, :is_locked) == true
    :ok = GenServer.call process, {:dataunlock, :test, :test}
    assert GenServer.call(process, :is_locked) == false
  end

  test "that timedatalock works", %{process: process} do
    assert GenServer.call(process, :is_locked) == false
    :ok = GenServer.call process, {:timedatalock, :test, 1500, :test}
    assert GenServer.call(process, :is_locked) == true
    assert GenServer.call(process, :get_lock_data) == :test

    :timer.sleep 1000
    assert GenServer.call(process, :is_locked) == true
    assert GenServer.call(process, :get_lock_data) == :test

    :timer.sleep 1000
    assert GenServer.call(process, :is_locked) == false
    assert GenServer.call(process, :get_lock_data) == nil
  end

  test "that timedatalock disallows standard unlock", %{process: process} do
    assert GenServer.call(process, :is_locked) == false
    :ok = GenServer.call process, {:timedatalock, :test, 15000, :test}
    assert GenServer.call(process, :is_locked) == true
    assert GenServer.call(process, :get_lock_data) == :test
    assert GenServer.call(process, :get_lock_data) != nil
    :ok = GenServer.call process, {:unlock, :test}
    assert GenServer.call(process, :is_locked) == true
    :timer.sleep 2000
    :ok = GenServer.call process, {:unlock, :test}
    assert GenServer.call(process, :is_locked) == true
    send process, {:timedataunlock, :test, :test}
    assert GenServer.call(process, :is_locked) == false
  end
end
