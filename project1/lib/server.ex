defmodule SERVER do
    def listen do
      receive do
        {:ok, response} -> IO.puts response
      end
      listen()
    end
end
