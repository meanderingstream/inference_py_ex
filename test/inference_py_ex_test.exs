defmodule InferencePyExTest do
  use ExUnit.Case
  doctest InferencePyEx

  test "greets the world" do
    assert InferencePyEx.hello() == :world
  end
end
