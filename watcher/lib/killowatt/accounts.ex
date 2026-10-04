defmodule Killowatt.Accounts do
  @moduledoc """
  one tiny supervised process per account. the beam keeps them apart;
  one account going sideways never touches the rest.
  """
  use DynamicSupervisor

  def start_link(init) do
    DynamicSupervisor.start_link(__MODULE__, init, name: __MODULE__)
  end

  @impl true
  def init(_init) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def start_account(account, policy) do
    DynamicSupervisor.start_child(
      __MODULE__,
      {Killowatt.AccountWatcher, {account, policy}}
    )
  end

  def stop_account(account) do
    case Registry.lookup(Killowatt.Registry, account) do
      [{pid, _}] -> DynamicSupervisor.terminate_child(__MODULE__, pid)
      [] -> :ok
    end
  end
end
