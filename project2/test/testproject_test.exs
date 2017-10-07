defmodule TestprojectTest do
  use ExUnit.Case
  doctest Testproject

  test "greets the world" do
    assert Testproject.hello() == :world
  end
end
