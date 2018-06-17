# Hammer.Plug

[![Build Status](https://travis-ci.org/ExHammer/hammer-plug.svg?branch=master)](https://travis-ci.org/ExHammer/hammer-plug)


## WARNING: Work in progress, use at your own risk


A plug helper to apply rate-limiting, with
[hammer](https://github.com/ExHammer/hammer)

Example:

```elixir
plug Hammer.Plug, {{"video:upload", 60_000, 10}, by: :ip}
```


## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `hammer_plug` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:hammer_plug, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/hammer_plug](https://hexdocs.pm/hammer_plug).
