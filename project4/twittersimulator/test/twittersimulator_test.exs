defmodule TwittersimulatorTest do
  use ExUnit.Case
  doctest Twittersimulator

  test "greets the world" do
    assert Twittersimulator.hello() == :world
  end
end
