> [!WARNING]
> This library is deprecated.
> 
> Please consider using custom function plugs suggested in the compilation warnings instead.

```elixir
plug :rate_limit_video_upload # when action in ...

defp rate_limit_video_upload(conn, _opts) do
  request_id = get_session(conn, :user_id)

  # note that request_id might be nil
  key = "video:upload:#{request_id}"
  scale = 60000
  limit = 10

  case Hammer.check_rate(key, scale, limit) do
    {:allow, _count} ->
      conn

    {:deny, _limit} ->
      conn |> send_resp(429, "Too Many Requests") |> halt()

    {:error, _reason} ->
      conn |> send_resp(429, "Too Many Requests") |> halt()
  end
end
```

---

# Hammer.Plug

[![Build Status](https://github.com/ExHammer/hammer-plug/actions/workflows/ci.yml/badge.svg)](https://github.com/ExHammer/hammer-plug/actions/workflows/ci.yml) [![Hex.pm](https://img.shields.io/hexpm/v/hammer_plug.svg)](https://hex.pm/packages/hammer_plug) [![Documentation](https://img.shields.io/badge/documentation-gray)](https://hexdocs.pm/hammer_plug)
[![Total Download](https://img.shields.io/hexpm/dt/hammer_plug.svg)](https://hex.pm/packages/hammer_plug)
[![License](https://img.shields.io/hexpm/l/hammer_plug.svg)](https://github.com/ExHammer/hammer-plug/blob/master/LICENSE.md)

[Hammer](https://github.com/ExHammer/hammer) is a rate-limiter for Elixir, with pluggable storage backends.

This library is a [plug](https://hexdocs.pm/plug/readme.html) helper, to easily add rate-limiting to Phoenix applications,
or any Elixir system that uses plug.

Example:

```elixir
# Allow ten uploads per 60 seconds
plug Hammer.Plug, [
  rate_limit: {"video:upload", 60_000, 10},
  by: {:session, :user_id}
] when action == :upload_video_file

def upload_video_file(conn, _opts) do
  # ...
end
```

## Documentation

See the [Hammer documentation page](https://hexdocs.pm/hammer) for more info on Hammer itself.

See the [Hammer.Plug docs](https://hexdocs.pm/hammer_plug) for more info about this library and how to use it, specifically the [Hammer.Plug](https://hexdocs.pm/hammer_plug/Hammer.Plug.html#content) module.


## Installation

Hammer-Plug is avaliable [available in Hex](https://hex.pm/docs/publish), the package can be installed by adding `hammer_plug` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:hammer, "~> 6.0"},
    {:hammer_plug, "~> 3.0"}
  ]
end
```
