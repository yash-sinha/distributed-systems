defmodule Twittersimulator do

  def main(args) do
    processpid = self()
    parse(args, processpid)
    Process.sleep(:infinity)
  end

  def parse(args, processpid) do
    # {_, str, _} = OptionParser.parse(args)
    # k = elem(Integer.parse(str), 0)
    # inputString = "#{args}"
    {_,input,_}  = OptionParser.parse(args)


    if length(input)>1 do
      numusers = Enum.at(input,0)
      {numusers, _} = :string.to_integer(numusers)
      inputString = Enum.at(input,1)      
      k =  "yash@" <> get_my_ip()
      Node.start(String.to_atom(k))
      Node.set_cookie :"monster"
      server_name = "geet@" <> inputString
      Node.connect :"#{server_name}"
      random_number = :rand.uniform(10000)
      rand_client = "client" <> "#{random_number}"
      pid = spawn(ModelT, :listen, [numusers, 0, []])
      this_client = String.to_atom(rand_client)
      :global.register_name(this_client, pid)
      :global.sync()
      :global.whereis_name(this_client) |> send({:startsimulation})

    else
      serverip = get_my_ip()
      my_server_name = "geet@"<>serverip
      IO.puts "Serverip: " <> "#{serverip}"
      # IO.inspect my_server_name
      Node.start(String.to_atom(my_server_name))
      Node.set_cookie :"monster"
      server_pid = spawn(Server, :listen, [processpid, 1, 1, 0, 0])
      :global.register_name(:server,server_pid)
      :global.sync()
      :global.whereis_name(:server) |> send({:createtables})
    end
  end

  defp get_my_ip do
    {os, _name} = :os.type
    {:ok, ifs} = :inet.getif()
    ips = for {ip, _, _} <- ifs, do: to_string(:inet.ntoa(ip))
    ipadd = if Atom.to_string(os) == "unix" do hd(ips) else List.last(ips) end
    ipadd
  end

end
