defmodule ExtagramTest do
  use ExUnit.Case
  doctest Extagram

  test "greets the world" do
    assert Extagram.hello() == :world
  end
end
