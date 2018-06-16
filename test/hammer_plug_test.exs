defmodule Hammer.PlugTest.IP do
  use ExUnit.Case, async: false
  use Plug.Test
  import Mock

  @opts Hammer.Plug.init(id: "test", scale: 1_000, limit: 3, by: :ip)

  test "passes the conn through on success" do
    with_mock Hammer, check_rate: fn _a, _b, _c -> {:allow, 1} end do
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
    with_mock Hammer, check_rate: fn _a, _b, _c -> {:deny, 1} end do
      # Create a test connection
      conn = conn(:get, "/hello")

      # Invoke the plug
      conn = Hammer.Plug.call(conn, @opts)

      # Assert the response and status
      assert conn.status == 429
      assert conn.halted == true
      assert called(Hammer.check_rate("test:127.0.0.1", 1_000, 3))
    end
  end
end

defmodule Hammer.PlugTest.Session do
  use ExUnit.Case, async: false
  use Plug.Test
  import Mock

  @opts Hammer.Plug.init(id: "test", scale: 1_000, limit: 3, by: {:session, :user_id})

  test "passes the conn through on success" do
    with_mock Hammer, check_rate: fn _a, _b, _c -> {:allow, 1} end do
      # Create a test connection
      conn =
        conn(:get, "/hello")
        |> init_test_session(%{user_id: "123487"})

      # Invoke the plug
      conn = Hammer.Plug.call(conn, @opts)

      # Assert the response and status
      assert conn.status == nil
      assert called(Hammer.check_rate("test:123487", 1_000, 3))
    end
  end

  test "halts the conn and sends a 429 on failure" do
    with_mock Hammer, check_rate: fn _a, _b, _c -> {:deny, 1} end do
      # Create a test connection
      conn =
        conn(:get, "/hello")
        |> init_test_session(%{user_id: "123487"})

      # Invoke the plug
      conn = Hammer.Plug.call(conn, @opts)

      # Assert the response and status
      assert conn.status == 429
      assert conn.halted == true
      assert called(Hammer.check_rate("test:123487", 1_000, 3))
    end
  end
end

defmodule Foo do
  def user_id(user) do
    user.id
  end
end

defmodule Hammer.PlugTest.Session.Func do
  use ExUnit.Case, async: false
  use Plug.Test
  import Mock

  @opts Hammer.Plug.init(
          id: "test",
          scale: 1_000,
          limit: 3,
          by: {:session, :user, &Foo.user_id/1}
        )

  test "passes the conn through on success" do
    with_mock Hammer, check_rate: fn _a, _b, _c -> {:allow, 1} end do
      # Create a test connection
      conn =
        conn(:get, "/hello")
        |> init_test_session(%{user: %{id: "123487"}})

      # Invoke the plug
      conn = Hammer.Plug.call(conn, @opts)

      # Assert the response and status
      assert conn.status == nil
      assert called(Hammer.check_rate("test:123487", 1_000, 3))
    end
  end

  test "halts the conn and sends a 429 on failure" do
    with_mock Hammer, check_rate: fn _a, _b, _c -> {:deny, 1} end do
      # Create a test connection
      conn =
        conn(:get, "/hello")
        |> init_test_session(%{user: %{id: "123487"}})

      # Invoke the plug
      conn = Hammer.Plug.call(conn, @opts)

      # Assert the response and status
      assert conn.status == 429
      assert conn.halted == true
      assert called(Hammer.check_rate("test:123487", 1_000, 3))
    end
  end
end
