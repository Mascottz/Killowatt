defmodule Killowatt.Metering.AwsClientTest do
  use ExUnit.Case, async: true

  alias Killowatt.Metering.AwsClient

  defp body(payload), do: :json.encode(payload) |> IO.iodata_to_binary()

  test "groups become one event per service, in cents" do
    json =
      body(%{
        "ResultsByTime" => [
          %{
            "TimePeriod" => %{"Start" => "2026-10-04T06:00:00Z", "End" => "2026-10-04T07:00:00Z"},
            "Groups" => [
              %{"Keys" => ["AmazonEC2"], "Metrics" => %{"UnblendedCost" => %{"Amount" => "12.34"}}},
              %{"Keys" => ["AmazonS3"], "Metrics" => %{"UnblendedCost" => %{"Amount" => "0.56"}}}
            ]
          }
        ]
      })

    events = AwsClient.parse(json, "2026-10-04T06:00:00Z", "2026-10-04T07:00:00Z")
    assert Enum.find(events, &(&1.service == "amazonec2")).cents == 1234
    assert Enum.find(events, &(&1.service == "amazons3")).cents == 56
  end

  test "an empty hour meters as zero events, not an error" do
    json = body(%{"ResultsByTime" => [%{"TimePeriod" => %{"Start" => "x", "End" => "y"}, "Groups" => []}]})
    assert [] = AwsClient.parse(json, "a", "z")
  end

  test "sub-cent amounts are dropped rather than rounded up" do
    json =
      body(%{
        "ResultsByTime" => [
          %{
            "TimePeriod" => %{"Start" => "2026-10-04T06:00:00Z", "End" => "2026-10-04T07:00:00Z"},
            "Groups" => [
              %{"Keys" => ["AmazonS3"], "Metrics" => %{"UnblendedCost" => %{"Amount" => "0.004"}}}
            ]
          }
        ]
      })

    assert [] = AwsClient.parse(json, "2026-10-04T06:00:00Z", "2026-10-04T07:00:00Z")
  end

  test "garbage from the api is zero events, never a crash" do
    assert [] = AwsClient.parse("not json", "a", "z")
    assert [] = AwsClient.parse(body(%{"unexpected" => true}), "a", "z")
  end
end

defmodule Killowatt.Enforcement.Aws.Sigv4JsonTest do
  use ExUnit.Case, async: true

  alias Killowatt.Enforcement.Aws.Sigv4

  # cross-checked against an independent implementation of the same
  # algorithm; same fixed inputs as the docs vectors in aws_sigv4_test.exs.
  test "the json api signature matches the independent cross-check" do
    {auth, _body, _} =
      Sigv4.authorization_json(
        "ce.us-east-1.amazonaws.com",
        ~s({"Granularity":"HOURLY"}),
        "AWSInsightsIndexService.GetCostAndUsage",
        "us-east-1",
        "ce",
        "AKIDEXAMPLE",
        "wJalrXUtnFEMI/K7MDENG+bPxRfiCYEXAMPLEKEY",
        "20150830T123600Z"
      )

    assert auth ==
             "AWS4-HMAC-SHA256 Credential=AKIDEXAMPLE/20150830/us-east-1/ce/aws4_request, " <>
               "SignedHeaders=content-type;host;x-amz-date;x-amz-target, " <>
               "Signature=76b90cc9b6339c05b2bd79d3e0c1c5a352340988a615d1a464bd6c64c29597e2"
  end
end
