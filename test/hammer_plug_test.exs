defmodule Hammer.PlugTest do
  use ExUnit.Case
  doctest Hammer.Plug

  test "greets the world" do
    assert Hammer.Plug.hello() == :world
  end
end
