# defmodule Randomizer do
#
#   def gen_bitcoins(k) do
#     # receive do
# 		#   {:next, k} -> randomizer(20, k)
#     # end
#     randomizer(20, k)
# 		 gen_bitcoins(k)
#   end
#
#
#   def randomizer(length, type \\ :all, k) do
#     alphabets = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
#     numbers = "0123456789"
#
#     lists = alphabets <> String.downcase(alphabets) <> numbers
#       |> String.split("", trim: true)
#
#     do_randomizer(length, lists, k)
#   end
#
#   defp get_range(length) when length > 1, do: (1..length)
#   defp get_range(length), do: [1]
#
#   defp do_randomizer(length, lists, k) do
#     inp =
#       get_range(length)
#       |> Enum.reduce([], fn(_, acc) -> [Enum.random(lists) | acc] end)
#       |> Enum.join("")
#     # IO.puts "GC"
#     sign_request(inp, k)
#   end
#
#   # defp sign_request(inp, k) do
#   #   # IO.puts "YS"
#   #   val = :crypto.hash(:sha256, inp)|> Base.encode16
#   #   zeros = String.duplicate("0", k)
#   #   cond do
#   #     ("#{zeros}" == String.slice(val, 0, k) && (String.at(val, k+1) != "0")) -> IO.puts val
#   #     true -> ""
#   #   end
#   #   #Randomizer.gen_bitcoins(2)
#   # end
# end
# # pids = Enum.map(1..10000, fn (_) -> spawn(Randomizer, :gen_bitcoins, k) end)
# # send(pids, {:next, 2})
# # Parallel.map(1..10000, Randomizer.gen_bitcoins(2))
