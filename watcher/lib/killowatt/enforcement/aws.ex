defmodule Killowatt.Enforcement.Aws do
  @moduledoc """
  scales the auto scaling group behind the tripped service to zero, via the
  aws query api with sigv4 signing.

  needs; AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, and AWS_REGION in the
  environment, and optionally KILOWATT_ASG_MAP as service=asg pairs, comma
  separated. without the map the service name is used as the group name.

  reversible; scale the group back to its previous min and desired to
  restore, and that undo rides along with every order.
  """

  alias Killowatt.Enforcement.Aws.Sigv4

  def scale_to_zero(service) do
    with {:ok, access_key} <- env("AWS_ACCESS_KEY_ID"),
         {:ok, secret} <- env("AWS_SECRET_ACCESS_KEY"),
         {:ok, region} <- env("AWS_REGION") do
      asg = asg_for(service)
      host = "autoscaling.#{region}.amazonaws.com"

      params = [
        {"Action", "UpdateAutoScalingGroup"},
        {"AutoScalingGroupName", asg},
        {"DesiredCapacity", "0"},
        {"MinSize", "0"},
        {"Version", "2011-01-01"}
      ]

      amz_date = Sigv4.timestamp()
      {auth, payload, _} = Sigv4.authorization(host, params, region, "autoscaling", access_key, secret, amz_date)

      request =
        {String.to_charlist("https://#{host}/"),
         [
           {~c"authorization", String.to_charlist(auth)},
           {~c"x-amz-date", String.to_charlist(amz_date)},
           {~c"content-type", ~c"application/x-www-form-urlencoded"}
         ], ~c"application/x-www-form-urlencoded", payload}

      case :httpc.request(:post, request, [{:timeout, 15_000}], []) do
        {:ok, {{_, status, _}, _headers, _body}} when status in 200..299 ->
          :ok

        {:ok, {{_, status, _}, _headers, body}} ->
          {:error, {:http, status, IO.iodata_to_binary(body)}}

        {:error, reason} ->
          {:error, {:transport, reason}}
      end
    end
  end

  defp env(name) do
    case System.get_env(name) do
      nil -> {:error, {:missing_env, name}}
      "" -> {:error, {:missing_env, name}}
      value -> {:ok, value}
    end
  end

  # KILOWATT_ASG_MAP="api=prod-api-asg,workers=prod-workers-asg"
  defp asg_for(service) do
    case System.get_env("KILOWATT_ASG_MAP") do
      nil ->
        service

      "" ->
        service

      mapping ->
        mapping
        |> String.split(",", trim: true)
        |> Enum.map(fn pair ->
          case String.split(pair, "=", parts: 2) do
            [k, v] -> {String.trim(k), String.trim(v)}
            _ -> nil
          end
        end)
        |> Enum.reject(&is_nil/1)
        |> Map.new()
        |> Map.get(service, service)
    end
  end
end
