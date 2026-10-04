# verify aws credentials with our own sigv4 signer; calls sts
# GetCallerIdentity, which every valid key can answer. run from the
# watcher directory with;
#
#   mix run ../scripts/check-aws.exs
#
# needs AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY; AWS_REGION is optional
# here because sts is global.

alias Killowatt.Enforcement.Aws.Sigv4

defmodule CheckAws do
  def env(name) do
    case System.get_env(name) do
      nil -> {:error, {:missing_env, name}}
      "" -> {:error, {:missing_env, name}}
      value -> {:ok, value}
    end
  end
end

with {:ok, access_key} <- CheckAws.env("AWS_ACCESS_KEY_ID"),
     {:ok, secret} <- CheckAws.env("AWS_SECRET_ACCESS_KEY") do
  region = "us-east-1"
  host = "sts.#{region}.amazonaws.com"

  params = [
    {"Action", "GetCallerIdentity"},
    {"Version", "2011-06-15"}
  ]

  amz_date = Sigv4.timestamp()
  {auth, payload, _} = Sigv4.authorization(host, params, region, "sts", access_key, secret, amz_date)

  request =
    {String.to_charlist("https://#{host}/"),
     [
       {~c"authorization", String.to_charlist(auth)},
       {~c"x-amz-date", String.to_charlist(amz_date)},
       {~c"content-type", ~c"application/x-www-form-urlencoded"}
     ], ~c"application/x-www-form-urlencoded", payload}

  case :httpc.request(:post, request, [{:timeout, 15_000}], []) do
    {:ok, {{_, status, _}, _headers, body}} when status in 200..299 ->
      xml = IO.iodata_to_binary(body)
      account = xml |> String.split("<Account>") |> List.last() |> String.split("</Account>") |> List.first()
      arn = xml |> String.split("<Arn>") |> List.last() |> String.split("</Arn>") |> List.first()
      IO.puts("credentials verified through our own sigv4 signer")
      IO.puts("  account; #{account}")
      IO.puts("  arn;     #{arn}")
      IO.puts("")
      IO.puts("for scale-to-zero enforcement this identity also needs")
      IO.puts("autoscaling:UpdateAutoScalingGroup on the groups you map")

    {:ok, {{_, status, _}, _headers, body}} ->
      IO.puts("aws answered #{status}; the signature worked, the identity did not")
      IO.puts(IO.iodata_to_binary(body))
      System.halt(1)

    {:error, reason} ->
      IO.puts("transport error; #{inspect(reason)}")
      System.halt(1)
  end
else
  {:error, {:missing_env, name}} ->
    IO.puts("set #{name} first; this check signs an sts GetCallerIdentity call")
    System.halt(1)
end
