defmodule Helpers do
  import Plug.Conn

  def user_id(user) do
    user.id
  end

  def email_param(conn) do
    conn.params["email"]
  end

  def on_deny(conn, _opts) do
    conn
    |> put_resp_header("x-hammer-test", "yes")
    |> send_resp(404, "Not Found")
    |> halt()
  end
end

defmodule Hammer.PlugTest do
  use ExUnit.Case
  use Plug.Test

  setup do
    case :ets.info(:hammer_ets_buckets) do
      :undefined -> :ok
      _ -> :ets.delete(:hammer_ets_buckets)
    end

    start_supervised!({Hammer.Backend.ETS, cleanup_interval_ms: :timer.seconds(50)})

    :ok
  end

  describe "by ip address" do
    @opts Hammer.Plug.init(rate_limit: {"test", 1_000, 3}, by: :ip)

    test "passes the conn through on success" do
      conn = Hammer.Plug.call(conn(:get, "/hello"), @opts)
      assert conn.status == nil
    end

    test "halts the conn and sends a 429 on failure" do
      conn =
        conn(:get, "/hello")
        |> Hammer.Plug.call(@opts)
        |> Hammer.Plug.call(@opts)
        |> Hammer.Plug.call(@opts)
        |> Hammer.Plug.call(@opts)

      assert conn.status == 429
      assert conn.halted == true
    end
  end

  describe "with custom on_deny handler" do
    @opts Hammer.Plug.init(
            rate_limit: {"test", 1_000, 3},
            by: :ip,
            on_deny: &Helpers.on_deny/2
          )

    test "passes the conn through on success" do
      conn = Hammer.Plug.call(conn(:get, "/hello"), @opts)
      assert conn.status == nil
    end

    test "halts the conn and sends a 404 (non default) on failure" do
      conn =
        conn(:get, "/hello")
        |> Hammer.Plug.call(@opts)
        |> Hammer.Plug.call(@opts)
        |> Hammer.Plug.call(@opts)
        |> Hammer.Plug.call(@opts)

      assert conn.status == 404
      assert get_resp_header(conn, "x-hammer-test") == ["yes"]
      assert conn.halted == true
    end
  end

  describe "by session" do
    @opts Hammer.Plug.init(
            rate_limit: {"test", 1_000, 3},
            by: {:session, :user_id}
          )

    test "passes the conn through on success" do
      conn =
        conn(:get, "/hello")
        |> init_test_session(%{user_id: "123487"})
        |> Hammer.Plug.call(@opts)

      assert conn.status == nil
    end

    test "halts the conn and sends a 429 on failure" do
      conn =
        conn(:get, "/hello")
        |> init_test_session(%{user_id: "123487"})
        |> Hammer.Plug.call(@opts)
        |> Hammer.Plug.call(@opts)
        |> Hammer.Plug.call(@opts)
        |> Hammer.Plug.call(@opts)

      assert conn.status == 429
      assert conn.halted == true
    end
  end

  describe "session, with function" do
    @opts Hammer.Plug.init(
            rate_limit: {"test", 1_000, 3},
            by: {:session, :user, &Helpers.user_id/1}
          )

    test "passes the conn through on success" do
      conn =
        conn(:get, "/hello")
        |> init_test_session(%{user: %{id: "123487"}})
        |> Hammer.Plug.call(@opts)

      assert conn.status == nil
    end

    test "halts the conn and sends a 429 on failure" do
      conn =
        conn(:get, "/hello")
        |> init_test_session(%{user: %{id: "123487"}})
        |> Hammer.Plug.call(@opts)
        |> Hammer.Plug.call(@opts)
        |> Hammer.Plug.call(@opts)
        |> Hammer.Plug.call(@opts)

      assert conn.status == 429
      assert conn.halted == true
    end
  end

  describe "conn with function" do
    @opts Hammer.Plug.init(
            rate_limit: {"test", 1_000, 3},
            by: {:conn, &Helpers.email_param/1}
          )

    test "passes the conn through on success" do
      conn =
        conn(:get, "/hello")
        |> Map.put(:params, %{"email" => "bob@example.com"})
        |> Hammer.Plug.call(@opts)

      assert conn.status == nil
    end

    test "halts the conn and sends a 429 on failure" do
      conn =
        conn(:get, "/hello")
        |> Map.put(:params, %{"email" => "bob@example.com"})
        |> Hammer.Plug.call(@opts)
        |> Hammer.Plug.call(@opts)
        |> Hammer.Plug.call(@opts)
        |> Hammer.Plug.call(@opts)

      assert conn.status == 429
      assert conn.halted == true
    end
  end

  describe "session, when_nil: :use_nil" do
    @opts Hammer.Plug.init(
            rate_limit: {"test", 1_000, 3},
            by: {:session, :user, &Helpers.user_id/1},
            when_nil: :use_nil
          )

    test "passes the conn through on success" do
      conn =
        conn(:get, "/hello")
        |> init_test_session(%{})
        |> Hammer.Plug.call(@opts)

      assert conn.status == nil
    end

    test "halts the conn and sends a 429 on failure" do
      conn =
        conn(:get, "/hello")
        |> init_test_session(%{})
        |> Hammer.Plug.call(@opts)
        |> Hammer.Plug.call(@opts)
        |> Hammer.Plug.call(@opts)
        |> Hammer.Plug.call(@opts)

      assert conn.status == 429
      assert conn.halted == true
    end
  end

  describe "session, when_nil: :pass" do
    @opts Hammer.Plug.init(
            rate_limit: {"test", 1_000, 3},
            by: {:session, :user, &Helpers.user_id/1},
            when_nil: :pass
          )

    test "doesn't call check_rate" do
      conn =
        conn(:get, "/hello")
        |> init_test_session(%{})
        |> Hammer.Plug.call(@opts)
        |> Hammer.Plug.call(@opts)
        |> Hammer.Plug.call(@opts)
        |> Hammer.Plug.call(@opts)

      assert conn.status == nil
    end
  end

  describe "session, when_nil: :raise" do
    @opts Hammer.Plug.init(
            rate_limit: {"test", 1_000, 3},
            by: {:session, :user, &Helpers.user_id/1},
            when_nil: :raise
          )

    test "should raise an exception" do
      assert_raise Hammer.Plug.NilError, fn ->
        conn(:get, "/hello")
        |> init_test_session(%{})
        |> Hammer.Plug.call(@opts)
      end
    end
  end

  describe "when no rate_limit is supplied" do
    @opts [by: :ip]

    test "should raise an exception" do
      assert_raise Hammer.Plug.NoRateLimitError, fn ->
        Hammer.Plug.init(@opts)
      end
    end
  end
end
