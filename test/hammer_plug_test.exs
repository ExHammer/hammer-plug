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
  use ExUnit.Case, async: false
  use Plug.Test
  import Mock

  Application.start(:plug)

  describe "by ip address" do
    @opts Hammer.Plug.init(rate_limit: {"test", 1_000, 3}, by: :ip)

    test "passes the conn through on success" do
      with_mock Hammer, check_rate: fn _a, _b, _c -> {:allow, 1} end do
        conn =
          conn(:get, "/hello")
          |> Hammer.Plug.call(@opts)

        assert conn.status == nil
        assert called(Hammer.check_rate("test:127.0.0.1", 1_000, 3))
      end
    end

    test "halts the conn and sends a 429 on failure" do
      with_mock Hammer, check_rate: fn _a, _b, _c -> {:deny, 1} end do
        conn =
          conn(:get, "/hello")
          |> Hammer.Plug.call(@opts)

        assert conn.status == 429
        assert conn.halted == true
        assert called(Hammer.check_rate("test:127.0.0.1", 1_000, 3))
      end
    end
  end

  describe "with custom on_deny handler" do
    @opts Hammer.Plug.init(
            rate_limit: {"test", 1_000, 3},
            by: :ip,
            on_deny: &Helpers.on_deny/2
          )

    test "passes the conn through on success" do
      with_mock Hammer, check_rate: fn _a, _b, _c -> {:allow, 1} end do
        conn =
          conn(:get, "/hello")
          |> Hammer.Plug.call(@opts)

        assert conn.status == nil
        assert called(Hammer.check_rate("test:127.0.0.1", 1_000, 3))
      end
    end

    test "halts the conn and sends a 404 (non default) on failure" do
      with_mock Hammer, check_rate: fn _a, _b, _c -> {:deny, 1} end do
        conn =
          conn(:get, "/hello")
          |> Hammer.Plug.call(@opts)

        assert conn.status == 404
        assert get_resp_header(conn, "x-hammer-test") == ["yes"]
        assert conn.halted == true
        assert called(Hammer.check_rate("test:127.0.0.1", 1_000, 3))
      end
    end
  end

  describe "by session" do
    @opts Hammer.Plug.init(
            rate_limit: {"test", 1_000, 3},
            by: {:session, :user_id}
          )

    test "passes the conn through on success" do
      with_mock Hammer, check_rate: fn _a, _b, _c -> {:allow, 1} end do
        conn =
          conn(:get, "/hello")
          |> init_test_session(%{user_id: "123487"})
          |> Hammer.Plug.call(@opts)

        assert conn.status == nil
        assert called(Hammer.check_rate("test:123487", 1_000, 3))
      end
    end

    test "halts the conn and sends a 429 on failure" do
      with_mock Hammer, check_rate: fn _a, _b, _c -> {:deny, 1} end do
        conn =
          conn(:get, "/hello")
          |> init_test_session(%{user_id: "123487"})
          |> Hammer.Plug.call(@opts)

        assert conn.status == 429
        assert conn.halted == true
        assert called(Hammer.check_rate("test:123487", 1_000, 3))
      end
    end
  end

  describe "session, with function" do
    @opts Hammer.Plug.init(
            rate_limit: {"test", 1_000, 3},
            by: {:session, :user, &Helpers.user_id/1}
          )

    test "passes the conn through on success" do
      with_mock Hammer, check_rate: fn _a, _b, _c -> {:allow, 1} end do
        conn =
          conn(:get, "/hello")
          |> init_test_session(%{user: %{id: "123487"}})
          |> Hammer.Plug.call(@opts)

        assert conn.status == nil
        assert called(Hammer.check_rate("test:123487", 1_000, 3))
      end
    end

    test "halts the conn and sends a 429 on failure" do
      with_mock Hammer, check_rate: fn _a, _b, _c -> {:deny, 1} end do
        conn =
          conn(:get, "/hello")
          |> init_test_session(%{user: %{id: "123487"}})
          |> Hammer.Plug.call(@opts)

        assert conn.status == 429
        assert conn.halted == true
        assert called(Hammer.check_rate("test:123487", 1_000, 3))
      end
    end
  end

  describe "conn with function" do
    @opts Hammer.Plug.init(
            rate_limit: {"test", 1_000, 3},
            by: {:conn, &Helpers.email_param/1}
          )

    test "passes the conn through on success" do
      with_mock Hammer, check_rate: fn _a, _b, _c -> {:allow, 1} end do
        conn =
          conn(:get, "/hello")
          |> Map.put(:params, %{"email" => "bob@example.com"})
          |> Hammer.Plug.call(@opts)

        assert conn.status == nil
        assert called(Hammer.check_rate("test:bob@example.com", 1_000, 3))
      end
    end

    test "halts the conn and sends a 429 on failure" do
      with_mock Hammer, check_rate: fn _a, _b, _c -> {:deny, 1} end do
        conn =
          conn(:get, "/hello")
          |> Map.put(:params, %{"email" => "bob@example.com"})
          |> Hammer.Plug.call(@opts)

        assert conn.status == 429
        assert conn.halted == true
        assert called(Hammer.check_rate("test:bob@example.com", 1_000, 3))
      end
    end
  end

  describe "session, when_nil: :use_nil" do
    @opts Hammer.Plug.init(
            rate_limit: {"test", 1_000, 3},
            by: {:session, :user, &Helpers.user_id/1},
            when_nil: :use_nil
          )

    test "passes the conn through on success" do
      with_mock Hammer, check_rate: fn _a, _b, _c -> {:allow, 1} end do
        conn =
          conn(:get, "/hello")
          |> init_test_session(%{})
          |> Hammer.Plug.call(@opts)

        assert conn.status == nil
        assert called(Hammer.check_rate("test:", 1_000, 3))
      end
    end

    test "halts the conn and sends a 429 on failure" do
      with_mock Hammer, check_rate: fn _a, _b, _c -> {:deny, 1} end do
        conn =
          conn(:get, "/hello")
          |> init_test_session(%{})
          |> Hammer.Plug.call(@opts)

        assert conn.status == 429
        assert conn.halted == true
        assert called(Hammer.check_rate("test:", 1_000, 3))
      end
    end
  end

  describe "session, when_nil: :pass" do
    @opts Hammer.Plug.init(
            rate_limit: {"test", 1_000, 3},
            by: {:session, :user, &Helpers.user_id/1},
            when_nil: :pass
          )

    test "doesn't call check_rate" do
      with_mock Hammer, check_rate: fn _a, _b, _c -> {:allow, 1} end do
        conn =
          conn(:get, "/hello")
          |> init_test_session(%{})
          |> Hammer.Plug.call(@opts)

        assert conn.status == nil
        assert !called(Hammer.check_rate("test:", 1_000, 3))
        assert !called(Hammer.check_rate(:_, :_, :_))
      end
    end
  end

  describe "session, when_nil: :raise" do
    @opts Hammer.Plug.init(
            rate_limit: {"test", 1_000, 3},
            by: {:session, :user, &Helpers.user_id/1},
            when_nil: :raise
          )

    test "doesn't call check_rate" do
      with_mock Hammer, check_rate: fn _a, _b, _c -> {:allow, 1} end do
        conn =
          conn(:get, "/hello")
          |> init_test_session(%{})

        assert_raise Hammer.Plug.NilError, fn ->
          Hammer.Plug.call(conn, @opts)
        end

        assert conn.status == nil
        assert !called(Hammer.check_rate("test:", 1_000, 3))
        assert !called(Hammer.check_rate(:_, :_, :_))
      end
    end
  end

  describe "when no rate_limit is supplied" do
    @opts [by: :ip]

    test "should raise an exception" do
      with_mock Hammer, check_rate: fn _a, _b, _c -> {:allow, 1} end do
        conn =
          conn(:get, "/hello")
          |> init_test_session(%{})

        assert_raise Hammer.Plug.NoRateLimitError, fn ->
          Hammer.Plug.init(@opts)
        end

        assert conn.status == nil
        assert !called(Hammer.check_rate("test:", 1_000, 3))
        assert !called(Hammer.check_rate(:_, :_, :_))
      end
    end
  end

  describe "on_error, :pass" do
    @opts [
      on_error: :pass,
      rate_limit: {"test", 1_000, 3}
    ]

    test "passes on hammer error" do
      with_mock Hammer, check_rate: fn _a, _b, _c -> {:error, :redis_error} end do
        conn =
          conn(:get, "/hello")
          |> init_test_session(%{})
          |> Hammer.Plug.call(@opts)

        assert conn.status == nil
        assert conn.halted == false
      end
    end
  end

  describe "on_error, :raise" do
    @opts [
      on_error: :raise,
      rate_limit: {"test", 1_000, 3}
    ]

    test "raises on hammer error" do
      with_mock Hammer, check_rate: fn _a, _b, _c -> {:error, :redis_error} end do
        conn =
          conn(:get, "/hello")
          |> init_test_session(%{})

        assert_raise Hammer.Plug.HammerError, fn ->
          Hammer.Plug.call(conn, @opts)
        end

        assert conn.status == nil
        assert called(Hammer.check_rate(:_, :_, :_))
      end
    end
  end

  describe "on_error, :deny" do
    @opts [
      on_error: :deny,
      rate_limit: {"test", 1_000, 3}
    ]

    test "denies on hammer error" do
      with_mock Hammer, check_rate: fn _a, _b, _c -> {:error, :redis_error} end do
        conn =
          conn(:get, "/hello")
          |> Hammer.Plug.call(@opts)
          |> init_test_session(%{})

        assert conn.status == 429
        assert conn.halted == true
        assert called(Hammer.check_rate("test:127.0.0.1", 1_000, 3))
      end
    end
  end

  describe "on_error with invalid option" do
    @opts [
      on_error: :cowbell,
      rate_limit: {"test", 1_000, 3}
    ]

    test "denies request" do
      with_mock Hammer, check_rate: fn _a, _b, _c -> {:error, :redis_error} end do
        conn =
          conn(:get, "/hello")
          |> Hammer.Plug.call(@opts)
          |> init_test_session(%{})

        assert conn.status == 429
        assert conn.halted == true
        assert called(Hammer.check_rate("test:127.0.0.1", 1_000, 3))
      end
    end
  end
end
