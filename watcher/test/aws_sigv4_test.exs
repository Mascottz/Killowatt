defmodule Killowatt.Enforcement.Aws.Sigv4Test do
  use ExUnit.Case

  alias Killowatt.Enforcement.Aws.Sigv4

  # both vectors come from the aws signing documentation example;
  # AKIDEXAMPLE and the matching secret, date 20150830, us-east-1, iam.

  @secret "wJalrXUtnFEMI/K7MDENG+bPxRfiCYEXAMPLEKEY"

  test "signing key derivation matches the aws docs vector" do
    key = Sigv4.signing_key(@secret, "20150830", "us-east-1", "iam")

    assert Base.encode16(key, case: :lower) ==
             "c4afb1cc5771d871763a393e44b703571b55cc28424d1a5e86da6ed3c154a4b9"
  end

  test "the final signature matches the aws docs vector" do
    key = Sigv4.signing_key(@secret, "20150830", "us-east-1", "iam")

    string_to_sign =
      Enum.join(
        [
          "AWS4-HMAC-SHA256",
          "20150830T123600Z",
          "20150830/us-east-1/iam/aws4_request",
          "f536975d06c0309214f805bb90ccff089219ecd68b2577efef23edd43b7e1a59"
        ],
        "\n"
      )

    assert Sigv4.sign_string_to_sign(key, string_to_sign) ==
             "5d672d79c15b13162d9279b0855cfba6789a8edb4c82c400e06b5924a6f2b5d7"
  end

  test "authorization carries the credential scope and a 64 char signature" do
    params = [
      {"Action", "UpdateAutoScalingGroup"},
      {"AutoScalingGroupName", "prod-api-asg"},
      {"DesiredCapacity", "0"},
      {"MinSize", "0"},
      {"Version", "2011-01-01"}
    ]

    {auth, payload, amz_date} =
      Sigv4.authorization(
        "autoscaling.us-east-1.amazonaws.com",
        params,
        "us-east-1",
        "autoscaling",
        "AKIDEXAMPLE",
        @secret,
        "20150830T123600Z"
      )

    assert auth =~ "AWS4-HMAC-SHA256 Credential=AKIDEXAMPLE/20150830/us-east-1/autoscaling/aws4_request"
    assert auth =~ "SignedHeaders=content-type;host;x-amz-date"
    [_, signature] = Regex.run(~r/Signature=([0-9a-f]{64})$/, auth)
    assert String.length(signature) == 64

    # the payload is form-encoded and sorted by parameter name
    assert payload =~ "Action=UpdateAutoScalingGroup"
    assert String.starts_with?(payload, "Action=")
    assert amz_date == "20150830T123600Z"
  end

  test "signatures are deterministic for the same inputs" do
    params = [{"Action", "X"}, {"Version", "2011-01-01"}]

    args = [
      "autoscaling.us-east-1.amazonaws.com",
      params,
      "us-east-1",
      "autoscaling",
      "AKIDEXAMPLE",
      @secret,
      "20150830T123600Z"
    ]

    assert apply(Sigv4, :authorization, args) == apply(Sigv4, :authorization, args)
  end
end
