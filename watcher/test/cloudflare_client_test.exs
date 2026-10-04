defmodule Killowatt.Metering.CloudflareClientTest do
  use ExUnit.Case, async: true

  alias Killowatt.Metering.CloudflareClient

  defp body(payload), do: :json.encode(payload) |> IO.iodata_to_binary()

  test "groups become one event per script" do
    json =
      body(%{
        "data" => %{
          "viewer" => %{
            "accounts" => [
              %{
                "durableObjectsInvocationsAdaptiveGroups" => [
                  %{"dimensions" => %{"scriptName" => "api"}, "sum" => %{"requests" => 3_000_000}},
                  %{"dimensions" => %{"scriptName" => "edge"}, "sum" => %{"requests" => 1_000_000}}
                ]
              }
            ]
          }
        },
        "errors" => nil
      })

    assert {:ok, events} = CloudflareClient.parse(json)
    assert Enum.find(events, &(&1.service == "api")).cents == 150
    assert Enum.find(events, &(&1.service == "edge")).cents == 50
  end

  test "an empty account meters as zero events, not an error" do
    json =
      body(%{
        "data" => %{"viewer" => %{"accounts" => [%{"durableObjectsInvocationsAdaptiveGroups" => []}]}},
        "errors" => nil
      })

    assert {:ok, []} = CloudflareClient.parse(json)
  end

  test "graphql errors surface as errors" do
    json = body(%{"data" => nil, "errors" => [%{"message" => "unknown field"}]})
    assert {:error, {:graphql, "unknown field"}} = CloudflareClient.parse(json)
  end

  test "sub-cent hours are dropped rather than rounded up" do
    json =
      body(%{
        "data" => %{
          "viewer" => %{
            "accounts" => [
              %{"durableObjectsInvocationsAdaptiveGroups" => [
                %{"dimensions" => %{"scriptName" => "tiny"}, "sum" => %{"requests" => 1_000}}
              ]}
            ]
          }
        },
        "errors" => nil
      })

    assert {:ok, []} = CloudflareClient.parse(json)
  end
end
