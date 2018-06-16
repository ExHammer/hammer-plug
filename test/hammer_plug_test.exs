defmodule Hammer.PlugTest do
  use ExUnit.Case, async: true
  use Plug.Test
  import Mock

  @opts Hammer.Plug.init([id: "test", scale: 1_000, limit: 3])

  test "passes the conn through on success" do
    with_mock Hammer, check_rate: fn(_a, _b, _c) -> {:allow, 1} end do
      # Create a test connection
      conn = conn(:get, "/hello")

      # Invoke the plug
      conn = Hammer.Plug.call(conn, @opts)

      # Assert the response and status
      assert conn.status == nil
      assert called(Hammer.check_rate("test:127.0.0.1", 1_000, 3))
    end
  end

  test "halts the conn and sends a 429 on failure" do
    with_mock Hammer, check_rate: fn(_a, _b, _c) -> {:deny, 1} end do
      # Create a test connection
      conn = conn(:get, "/hello")

      # Invoke the plug
      conn = Hammer.Plug.call(conn, @opts)
      IO.inspect conn

      # Assert the response and status
      assert conn.status == 429
      assert conn.halted == true
      assert called(Hammer.check_rate("test:127.0.0.1", 1_000, 3))
    end
  end
end
