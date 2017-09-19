defmodule WORKER do
    def gen_bitcoins(k) do
      inp = :crypto.strong_rand_bytes(20) |> Base.encode64 |> binary_part(0, 20)
      sign_request(inp, k)
  		gen_bitcoins(k)
    end


    def sign_request(inp, k) do
      inp = "geetanjli;" <> inp
      val = Base.encode16(:crypto.hash(:sha256, inp))
      zeros = String.duplicate("0", k)
      cond do
        ("#{zeros}" == String.slice(val, 0, k) && (String.at(val, k) != "0"))
        ->  send((:global.whereis_name(:my_server)), { :ok, Enum.join([inp,val], "\t")})
        true -> ""
      end
    end

  end
