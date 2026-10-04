defmodule Killowatt.PolicyRegistryTest do
  use ExUnit.Case, async: true

  alias Killowatt.PolicyRegistry

  test "loads every policy from the repo registry" do
    {:ok, policies} = PolicyRegistry.load()
    assert Map.keys(policies) |> Enum.sort() == ["acme-prod", "infra-core"]
  end

  test "translates the cue shape into the watcher shape" do
    {:ok, policies} = PolicyRegistry.load()

    acme = policies["acme-prod"]
    assert acme.action == "hard_stop"
    assert acme.burst_limit == 40_00
    assert acme.burst_window_ms == 600_000
    assert "rds-prod-backups" in acme.exempt

    infra = policies["infra-core"]
    assert infra.action == "throttle"
    assert infra.hourly_limit == 120_00
  end

  test "a watcher started from the registry trips on its own limits" do
    {:ok, policies} = PolicyRegistry.load()
    {:ok, _} = Killowatt.Accounts.start_account("infra-core", policies["infra-core"])

    # 15 events of $13 each lands the hour over the $120 hourly limit
    for i <- 1..15 do
      Killowatt.AccountWatcher.record("infra-core", %{
        at_ms: i * 60_000,
        service: "queue-workers",
        cents: 13_00
      })
    end

    Process.sleep(50)
    state = Killowatt.AccountWatcher.state("infra-core")
    assert state.tripped
    Killowatt.Accounts.stop_account("infra-core")
  end

  test "missing registry is an error, not a crash" do
    assert {:error, _} = PolicyRegistry.load("does/not/exist.json")
  end

  test "garbage json is an error, not a crash" do
    path = Path.join(System.tmp_dir!(), "killowatt-registry-#{System.unique_integer([:positive])}.json")
    File.write!(path, "{not json")
    assert {:error, _} = PolicyRegistry.load(path)
    File.rm(path)
  end
end
