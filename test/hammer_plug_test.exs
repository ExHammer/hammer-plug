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

  def current_user(conn) do
    conn.assigns[:current_user]
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

  describe "deleted_when: {:status, list}" do
    @opts Hammer.Plug.init(
            rate_limit: {"test", 1_000, 3},
            by: :ip,
            delete_when: {:status, [200, 201]}
          )

    test "when response status is in list it deletes the bucket" do
      with_mock(Hammer,
        check_rate: fn _a, _b, _c -> {:allow, 1} end,
        delete_buckets: fn _a -> :ok end
      ) do
        conn(:get, "/hello")
        |> Hammer.Plug.call(@opts)
        |> send_resp(201, "")

        assert called(Hammer.delete_buckets("test:127.0.0.1"))
      end
    end

    test "when response status is not in the list it keeps the bucket" do
      with_mock(Hammer,
        check_rate: fn _a, _b, _c -> {:allow, 1} end,
        delete_buckets: fn _a -> :ok end
      ) do
        conn(:get, "/hello")
        |> Hammer.Plug.call(@opts)
        |> send_resp(401, "")

        refute called(Hammer.delete_buckets("test:127.0.0.1"))
      end
    end
  end

  describe "deleted_when: {:status, range}" do
    @opts Hammer.Plug.init(
            rate_limit: {"test", 1_000, 3},
            by: :ip,
            delete_when: {:status, 200..201}
          )

    test "when response status is in range it deletes the bucket" do
      with_mock(Hammer,
        check_rate: fn _a, _b, _c -> {:allow, 1} end,
        delete_buckets: fn _a -> :ok end
      ) do
        conn(:get, "/hello")
        |> Hammer.Plug.call(@opts)
        |> send_resp(200, "")

        assert called(Hammer.delete_buckets("test:127.0.0.1"))
      end
    end

    test "when response status is not in the range it keeps the bucket" do
      with_mock(Hammer,
        check_rate: fn _a, _b, _c -> {:allow, 1} end,
        delete_buckets: fn _a -> :ok end
      ) do
        conn(:get, "/hello")
        |> Hammer.Plug.call(@opts)
        |> send_resp(401, "")

        refute called(Hammer.delete_buckets("test:127.0.0.1"))
      end
    end
  end

  describe "deleted_when: {:status, status}" do
    @opts Hammer.Plug.init(
            rate_limit: {"test", 1_000, 3},
            by: :ip,
            delete_when: {:status, 200}
          )

    test "when response status matches it deletes the bucket" do
      with_mock(Hammer,
        check_rate: fn _a, _b, _c -> {:allow, 1} end,
        delete_buckets: fn _a -> :ok end
      ) do
        conn(:get, "/hello")
        |> Hammer.Plug.call(@opts)
        |> send_resp(200, "")

        assert called(Hammer.delete_buckets("test:127.0.0.1"))
      end
    end

    test "when response status does not match it keeps the bucket" do
      with_mock(Hammer,
        check_rate: fn _a, _b, _c -> {:allow, 1} end,
        delete_buckets: fn _a -> :ok end
      ) do
        conn(:get, "/hello")
        |> Hammer.Plug.call(@opts)
        |> send_resp(401, "")

        refute called(Hammer.delete_buckets("test:127.0.0.1"))
      end
    end
  end

  describe "deleted_when: {:conn, function}" do
    @opts Hammer.Plug.init(
            rate_limit: {"test", 1_000, 3},
            by: :ip,
            delete_when: {:conn, &Helpers.current_user/1}
          )

    test "when function returns a truthy value it deletes the bucket" do
      with_mock(Hammer,
        check_rate: fn _a, _b, _c -> {:allow, 1} end,
        delete_buckets: fn _a -> :ok end
      ) do
        conn(:get, "/hello")
        |> Hammer.Plug.call(@opts)
        |> assign(:current_user, "bob")
        |> send_resp(200, "")

        assert called(Hammer.delete_buckets("test:127.0.0.1"))
      end
    end

    test "when function returns falsey value it keeps the bucket" do
      with_mock(Hammer,
        check_rate: fn _a, _b, _c -> {:allow, 1} end,
        delete_buckets: fn _a -> :ok end
      ) do
        conn(:get, "/hello")
        |> Hammer.Plug.call(@opts)
        |> send_resp(401, "")

        refute called(Hammer.delete_buckets("test:127.0.0.1"))
      end
    end
  end
end
