defmodule Amelia do
  use GenServer

  require Logger

  ## GenServer init. API

  def start_link(_) do
    GenServer.start_link __MODULE__, :ok, name: __MODULE__
  end

  def init(:ok) do
    Logger.info "Starting amelia..."
    state = %{
      is_locked: false,
      lock_data: nil
    }

    {:ok, state}
  end

  ## Lock helper functions

  defp do_lock(lock_name) do
    :global.set_lock {lock_name, self()}
  end

  defp do_unlock(lock_name, expected_data, actual_data) do
    if expected_data == actual_data do
      :global.del_lock {lock_name, self()}
      :ok
    else
      :error
    end
  end

  ## GenServer API: Basic un/locking

  def handle_call({:lock, lock_name}, _from, state) do
    new_state = state
    unless state[:is_locked] do
      do_lock lock_name
    end

    {:reply, :ok, %{new_state | is_locked: true}}
  end

  def handle_call({:unlock, lock_name}, _from, state) do
    new_state = state
    did_unlock = if state[:is_locked] do
      case do_unlock(lock_name, nil, state[:lock_data]) do
        :ok -> true
        :error -> false
      end
    else
      false
    end

    case did_unlock do
      true -> {:reply, :ok, %{new_state | is_locked: false}}
      false -> {:reply, :ok, new_state}
    end
  end

  ## GenServer API: Timed un/locking

  def handle_call({:timelock, lock_name, time_ms}, _from, state) do
    unless state[:is_locked] do
      do_lock lock_name
      Process.send_after self(), {:unlock, lock_name}, time_ms
    end

    {:reply, :ok, %{state | is_locked: true}}
  end

  def handle_info({:unlock, lock_name}, state) do
    did_unlock = if state[:is_locked] do
      do_unlock lock_name, nil, state[:lock_data]
      true
    else
      false
    end

    case did_unlock do
      true -> {:noreply, %{state | is_locked: false}}
      false -> {:noreply, state}
    end
  end

  ## GenServer API: Data un/locking

  def handle_call({:datalock, lock_name, data}, _from, state) do
    new_state = state
    did_lock = unless state[:is_locked] do
      do_lock lock_name
      true
    else
      false
    end

    case did_lock do
      true -> {:reply, :ok, %{new_state | is_locked: true, lock_data: data}}
      false -> {:reply, :ok, %{new_state | is_locked: true}}
    end
  end

  def handle_call({:dataunlock, lock_name, data}, _from, state) do
    new_state = state
    did_unlock = 
      if state[:is_locked] do
        case do_unlock lock_name, state[:lock_data], data do
          :ok -> true
          :error -> false
        end
      else
        false
      end

    case did_unlock do
      true -> {:reply, :ok, %{new_state | is_locked: false, lock_data: nil}}
      false -> {:reply, :ok, %{new_state | is_locked: true}}
    end
  end

  ## GenServer API: Timed data un/locking

  def handle_call({:timedatalock, lock_name, time_ms, data}, _from, state) do
    unless state[:is_locked] do
      do_lock lock_name
      Process.send_after self(), {:timedataunlock, lock_name, data}, time_ms
    end

    {:reply, :ok, %{state | is_locked: true, lock_data: data}}
  end

  def handle_info({:timedataunlock, lock_name, data}, state) do
    did_unlock = if state[:is_locked] do
      do_unlock lock_name, data, state[:lock_data]
      true
    else
      false
    end

    case did_unlock do
      true -> {:noreply, %{state | is_locked: false, lock_data: nil}}
      false -> {:noreply, state}
    end
  end

  ## GenServer API: Util

  def handle_call(:is_locked, _from, state) do
    {:reply, state[:is_locked], state}
  end

  def handle_call(:get_lock_data, _from, state) do
    {:reply, state[:lock_data], state}
  end
end
