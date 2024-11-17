defmodule Hammer.Plug.DeprecationWarningTest do
  use ExUnit.Case
  import ExUnit.CaptureLog

  test "basic" do
    # from the current readme
    options = [
      rate_limit: {"video:upload", 60_000, 10},
      by: {:session, :user_id}
    ]

    config = Hammer.Plug.init(options)

    log =
      capture_log(fn ->
        Hammer.Plug.render_custom_plug(config)
      end)

    assert log == nil
  end
end
