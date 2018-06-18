# Hammer.Plug

[![Build Status](https://travis-ci.org/ExHammer/hammer-plug.svg?branch=master)](https://travis-ci.org/ExHammer/hammer-plug)

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

See the [Hammer documentation page](https://hexdocs.pm/hammer) for more info on Hammer itself.

See the [Hammer.Plug docs](https://hexdocs.pm/hammer_plug) for more info about this library and how to use it.


## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `hammer_plug` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:hammer, "~> 5.0"}
    {:hammer_plug, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the
