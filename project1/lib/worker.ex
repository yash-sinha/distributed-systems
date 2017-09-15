defmodule WORKER do

    # def gen_bitcoin(user_input, i, k, k_zeros, server_pid) do
    #     input = user_input <> Integer.to_string(i)
    #     hash = Base.encode16(:crypto.hash(:sha256, input))
    #
    #     if String.slice(hash, 0..k-1) == k_zeros do
    #         send server_pid, { :ok, Enum.join([input,hash], "\t") }
    #     end
    #     print_bitcoins(user_input, i + 1, k, k_zeros, server_pid)
    # end
    def gen_bitcoins(k, server_pid) do
      # receive do
  		#   {:next, k} -> randomizer(20, k)
      # end
      randomizer(20, k, server_pid)
  		gen_bitcoins(k, server_pid)
    end

    def randomizer(length, type \\ :all, k, server_pid) do
      alphabets = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
      numbers = "0123456789"

      lists = alphabets <> String.downcase(alphabets) <> numbers
        |> String.split("", trim: true)

      do_randomizer(length, lists, k, server_pid)
    end

    defp get_range(length) when length > 1, do: (1..length)
    defp get_range(length), do: [1]

    defp do_randomizer(length, lists, k, server_pid) do
      inp =
        get_range(length)
        |> Enum.reduce([], fn(_, acc) -> [Enum.random(lists) | acc] end)
        |> Enum.join("")
      # IO.puts "GC"
      sign_request(inp, k, server_pid)
    end

    def sign_request(inp, k, server_pid) do
      inp = "geetanjli;" <> inp
      val = :crypto.hash(:sha256, inp)|> Base.encode16
      zeros = String.duplicate("0", k)
      cond do
        ("#{zeros}" == String.slice(val, 0, k) && (String.at(val, k+1) != "0"))
        -> send server_pid, { :ok, Enum.join([inp,val], "\t") }
        true -> ""
      end
      #Randomizer.gen_bitcoins(2)
    end

  end
