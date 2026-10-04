defmodule Killowatt.Enforcement do
  @moduledoc """
  turns a hard stop into an action. dry run is the default; live adapters
  opt in. every order carries its own undo, because reversible is the only
  sane default.
  """

  require Logger

  def dispatch(account, service, policy_action, mode \\ :dry_run)

  # watch mode never touches anything, whatever mode is asked for
  def dispatch(_account, _service, "alert_only", _mode), do: {:ok, :watching}

  def dispatch(account, service, "hard_stop", mode) do
    order = %{
      account: account,
      service: service,
      action: "suspend",
      undo: "re-enable #{service}"
    }

    apply_order(order, mode)
  end

  def dispatch(account, service, "throttle", mode) do
    order = %{
      account: account,
      service: service,
      action: "throttle",
      undo: "remove the throttle on #{service}"
    }

    apply_order(order, mode)
  end

  defp apply_order(order, :dry_run) do
    Killowatt.Alerts.notice(%{
      account: order.account,
      kind: "enforced",
      message: "dry run; would #{order.action} #{order.service} → #{order.undo}"
    })

    {:ok, order}
  end

  defp apply_order(order, {:test, pid}) when is_pid(pid) do
    send(pid, {:enforcement_order, order})
    {:ok, order}
  end

  defp apply_order(order, :cloudflare) do
    case Killowatt.Enforcement.Cloudflare.suspend(order.service) do
      :ok ->
        Killowatt.Alerts.notice(%{
          account: order.account,
          kind: "enforced",
          message:
            "suspended the worker behind #{order.service} via the cloudflare api → #{order.undo}"
        })

        {:ok, order}

      {:error, reason} ->
        Killowatt.Alerts.notice(%{
          account: order.account,
          kind: "enforcement failed",
          message: "#{order.service}; #{inspect(reason)}"
        })

        {:error, reason}
    end
  end
end
