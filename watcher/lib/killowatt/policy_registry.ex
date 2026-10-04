defmodule Killowatt.PolicyRegistry do
  @moduledoc """
  the same exported registry the rust core reads; one policy per account,
  from policies/accounts.json. one source of truth means the core and the
  watcher cannot drift apart.
  """

  @candidates ["policies/accounts.json", "../policies/accounts.json"]

  @doc "load the registry as %{account => watcher policy}"
  def load(path \\ nil) do
    with {:ok, raw} <- read(path),
         {:ok, decoded} <- JSON.decode(raw) do
      policies =
        Map.new(decoded, fn {_key, pol} ->
          {pol["account"], to_watcher_policy(pol)}
        end)

      {:ok, policies}
    end
  end

  def load!(path \\ nil) do
    case load(path) do
      {:ok, policies} -> policies
      {:error, reason} -> raise "cannot load the policy registry; #{inspect(reason)}"
    end
  end

  @doc "start one watcher per policy in the registry; returns the accounts watched"
  def start_from_registry(enforce_mode \\ :dry_run) do
    {:ok, policies} = load()

    Enum.map(policies, fn {account, policy} ->
      {:ok, _} = Killowatt.Accounts.start_account(account, policy, enforce: enforce_mode)
      account
    end)
  end

  # cue speaks snake_case cents; the watcher speaks its own shape.
  defp to_watcher_policy(pol) do
    %{
      daily_limit: pol["daily_limit_cents"],
      hourly_limit: pol["hourly_limit_cents"],
      burst_window_ms: pol["burst"]["window_seconds"] * 1_000,
      burst_limit: pol["burst"]["limit_cents"],
      exempt: pol["exempt"] || [],
      action: pol["action"] || "hard_stop"
    }
  end

  defp read(nil) do
    case Enum.find(@candidates, &File.exists?/1) do
      nil -> {:error, :registry_not_found}
      path -> File.read(path)
    end
  end

  defp read(path), do: File.read(path)
end
