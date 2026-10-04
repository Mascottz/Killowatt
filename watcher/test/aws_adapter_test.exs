defmodule Killowatt.Enforcement.AwsTest do
  # env mutation is global; keep this suite to itself
  use ExUnit.Case, async: false

  alias Killowatt.Enforcement.Aws

  setup do
    prev =
      for key <- ~w(AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_REGION KILOWATT_ASG_MAP),
          into: %{},
          do: {key, System.get_env(key)}

    on_exit(fn ->
      for {key, value} <- prev do
        if value, do: System.put_env(key, value), else: System.delete_env(key)
      end
    end)

    :ok
  end

  test "missing creds fail before anything is signed" do
    System.delete_env("AWS_ACCESS_KEY_ID")
    assert Aws.scale_to_zero("api") == {:error, {:missing_env, "AWS_ACCESS_KEY_ID"}}
  end

  test "empty creds count as missing too" do
    System.put_env("AWS_ACCESS_KEY_ID", "")
    assert Aws.scale_to_zero("api") == {:error, {:missing_env, "AWS_ACCESS_KEY_ID"}}
  end

  test "without a map, the service name is the group name" do
    System.delete_env("KILOWATT_ASG_MAP")
    assert Aws.asg_for("prod-api-asg") == "prod-api-asg"
  end

  test "the map rewrites known services and leaves the rest alone" do
    System.put_env("KILOWATT_ASG_MAP", "api=prod-api-asg,workers=prod-workers-asg")
    assert Aws.asg_for("api") == "prod-api-asg"
    assert Aws.asg_for("workers") == "prod-workers-asg"
    assert Aws.asg_for("unknown") == "unknown"
  end

  test "malformed pairs are ignored, not fatal" do
    System.put_env("KILOWATT_ASG_MAP", "junk,api=prod-api-asg,=oops")
    assert Aws.asg_for("api") == "prod-api-asg"
    assert Aws.asg_for("junk") == "junk"
  end
end
