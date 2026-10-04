defmodule Killowatt.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Registry, keys: :unique, name: Killowatt.Registry},
      Killowatt.Alerts,
      Killowatt.Accounts
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: Killowatt.Supervisor)
  end
end
