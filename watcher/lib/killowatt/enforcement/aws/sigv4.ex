defmodule Killowatt.Enforcement.Aws.Sigv4 do
  @moduledoc """
  aws signature version 4, the small piece that lets the watcher call aws
  without pulling in an sdk. verified against the vectors in the aws signing
  documentation; see test/aws_sigv4_test.exs.

  parameter values are expected to be plain; the form encoding step does not
  percent-escape beyond application/x-www-form-urlencoded, which is fine for
  action names, group names, and numbers. if you sign anything stranger,
  harden this first.
  """

  def sha256_hex(data) do
    :crypto.hash(:sha256, data) |> Base.encode16(case: :lower)
  end

  def hmac_sha256(key, data) do
    :crypto.mac(:hmac, :sha256, key, data)
  end

  # the four-step hmac chain from the signing docs.
  def signing_key(secret, date, region, service) do
    k_date = hmac_sha256("AWS4" <> secret, date)
    k_region = hmac_sha256(k_date, region)
    k_service = hmac_sha256(k_region, service)
    hmac_sha256(k_service, "aws4_request")
  end

  def sign_string_to_sign(signing_key, string_to_sign) do
    signing_key |> hmac_sha256(string_to_sign) |> Base.encode16(case: :lower)
  end

  # builds the authorization header and the form payload for a post against
  # the aws query api; params is a keyword-style list of {name, value}.
  def authorization(host, params, region, service, access_key, secret, amz_date) do
    date = String.slice(amz_date, 0, 8)
    payload = params |> Enum.sort() |> URI.encode_query()
    payload_hash = sha256_hex(payload)

    canonical_headers =
      "content-type:application/x-www-form-urlencoded\n" <>
        "host:#{host}\n" <>
        "x-amz-date:#{amz_date}\n"

    signed_headers = "content-type;host;x-amz-date"

    canonical_request =
      Enum.join(["POST", "/", "", canonical_headers, signed_headers, payload_hash], "\n")

    scope = "#{date}/#{region}/#{service}/aws4_request"

    string_to_sign =
      Enum.join(["AWS4-HMAC-SHA256", amz_date, scope, sha256_hex(canonical_request)], "\n")

    signature =
      signing_key(secret, date, region, service)
      |> sign_string_to_sign(string_to_sign)

    auth =
      "AWS4-HMAC-SHA256 Credential=#{access_key}/#{scope}, " <>
        "SignedHeaders=#{signed_headers}, Signature=#{signature}"

    {auth, payload, amz_date}
  end

  # builds the authorization header and the json payload for a post against
  # an aws json api (cost explorer and friends); the x-amz-target header
  # names the operation and rides along as a signed header.
  def authorization_json(host, body, target, region, service, access_key, secret, amz_date) do
    date = String.slice(amz_date, 0, 8)
    payload_hash = sha256_hex(body)

    canonical_headers =
      "content-type:application/x-amz-amz-json-1.1\n" <>
        "host:#{host}\n" <>
        "x-amz-date:#{amz_date}\n" <>
        "x-amz-target:#{target}\n"

    signed_headers = "content-type;host;x-amz-date;x-amz-target"

    canonical_request =
      Enum.join(["POST", "/", "", canonical_headers, signed_headers, payload_hash], "\n")

    scope = "#{date}/#{region}/#{service}/aws4_request"

    string_to_sign =
      Enum.join(["AWS4-HMAC-SHA256", amz_date, scope, sha256_hex(canonical_request)], "\n")

    signature =
      signing_key(secret, date, region, service)
      |> sign_string_to_sign(string_to_sign)

    auth =
      "AWS4-HMAC-SHA256 Credential=#{access_key}/#{scope}, " <>
        "SignedHeaders=#{signed_headers}, Signature=#{signature}"

    {auth, body, amz_date}
  end

  def timestamp(now \\ DateTime.utc_now()) do
    Calendar.strftime(now, "%Y%m%dT%H%M%SZ")
  end
end
