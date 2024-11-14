# Hammer.Plug

[![Build Status](https://github.com/ExHammer/hammer-plug/actions/workflows/ci.yml/badge.svg)](https://github.com/ExHammer/hammer-plug/actions/workflows/ci.yml) [![Hex.pm](https://img.shields.io/hexpm/v/hammer_plug.svg)](https://hex.pm/packages/hammer_plug)
[![Documentation](https://img.shields.io/badge/documentation-gray)](https://hexdocs.pm/hammer_plug)
[![Total Download](https://img.shields.io/hexpm/dt/hammer_plug.svg)](https://hex.pm/packages/hammer_plug)
[![License](https://img.shields.io/hexpm/l/hammer_plug.svg)](https://github.com/ExHammer/hammer-plug/blob/master/LICENSE.md)

[Hammer](https://github.com/ExHammer/hammer) is a rate-limiter for Elixir, with pluggable storage backends.

This library is a [plug](https://hexdocs.pm/plug/readme.html) helper, to easily add rate-limiting to Phoenix applications,
or any Elixir system that uses plug.

Example:

```elixir
# Define your rate limiter
defmodule MyApp.RateLimit do
  use Hammer, backend: :ets
end

# Define your plug
defmodule MyAppWeb.Plugs.VideoRateLimit do
  use Hammer.Plug

  @spec throttle(Plug.Conn.t(), Keyword.t()) :: {:allow, conn} | {:deny, conn}
  def throttle(conn, opts) do
    case conn.remote_ip do
      # allow localhost
      {127, 0, 0, 1} ->
        {:allow, conn}

      # deny some bad ip
      {6, 6, 6, 6} ->
        {:deny, conn}

      # throttle the rest
      remote_ip ->
        key_prefix = 
        key = "" <> List/to_string(:inet.ntoa(remote_ip))
    end
  end
end

# Register the plug in the pipeline
plug MyAppWeb.RateLimitPlug, [
  key_prefix: 
] when action == :upload_video_file

def upload_video_file(conn, _opts) do
  # the action is allowed
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
    {:hammer_plug, "~> 3.0"}
  ]
end
```
