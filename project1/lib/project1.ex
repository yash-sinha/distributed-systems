defmodule Project1 do
    def main(args) do
      parse(args)
      Process.sleep(:infinity)
    end

    def parse(args) do
      {_, [str], _} = OptionParser.parse(args)
      k = elem(Integer.parse(str), 0)
      inputString = "#{args}"

      if length(String.split(inputString, "."))>1 do
        k =  "yash@" <> get_my_ip()
        Node.start(String.to_atom(k))
        Node.set_cookie :"monster"
        server_name = "geet@" <> inputString
        Node.connect :"#{server_name}"
        :global.sync()
        pid = spawn(Project1, :spawnafterk, [])
        random_number = :rand.uniform(1000)
        rand_client = "client" <> "#{random_number}"
        this_client = String.to_atom(rand_client)
        :global.register_name(this_client,pid)
        :global.whereis_name(:my_server) |> send({:getk,this_client})

      else
        my_server_name = "geet@"<>get_my_ip()
        Node.start(String.to_atom(my_server_name))
        Node.set_cookie :"monster"
        server_pid = spawn(SERVER, :listen, [k])
        :global.register_name(:my_server,server_pid)
        :global.sync()
        spawn8(k)
      end
    end

    def spawn8(k) do
      Enum.each(1..9, fn(_)->
        spawn(WORKER, :gen_bitcoins, [k])
      end)
    end

    def spawnafterk() do
      receive do
        {:kvalue, k} ->
          spawn8(k)
      end
      spawnafterk()
    end

    defp get_my_ip do
	#ipadd = ""
    {os, _name} = :os.type
    {:ok, ifs} = :inet.getif()
    ips = for {ip, _, _} <- ifs, do: to_string(:inet.ntoa(ip))
    ipadd = if Atom.to_string(os) == ":unix" do
    hd(ips)
	else
    List.last(ips)
	end
	ipadd
 end
end
