defmodule SERVER do
    def listen(leadingzeroes) do
      k = leadingzeroes
      receive do
        {:ok, response} ->
           IO.puts response
        {:getk, client} ->
        :global.whereis_name(client) |> send({:kvalue,k})
      end
      listen(k)
    end
end
