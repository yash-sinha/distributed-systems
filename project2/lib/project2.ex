defmodule Project2 do

    def main(args) do
      {_,input,_}  = OptionParser.parse(args)
      numnodes = Enum.at(input,0)
      {numnodes, _} = :string.to_integer(numnodes)
      topology = Enum.at(input,1)
      algo = Enum.at(input,2)
      ctr = 0
      rumor = {}
      #setting default time limt
      #timeLimit = 300 * numNodes

      if(topology == "2D" || topology == "imp2D")
      do
        i= :math.pow(numnodes,1/2)
        i=Float.floor(i,0)
        numnodes = round(i * i)
      end
    IO.puts "Numnodes is: " <>  "#{numnodes}"
    processpid = self
    counter_map = %{}



    create_workers(numnodes, ctr, rumor, algo, topology, counter_map, numnodes)
    #TODO  topology is one of full, 2D, line, imp2D, algorithm is one of gossip, push-sum
    time_start = Time.utc_now() #TODO
    serverpid = spawn(Project2, :getk_from_all, [counter_map, processpid, time_start, numnodes])
    :global.register_name(:server, serverpid)
    IO.puts "Server pid"
    IO.inspect(serverpid)

    #Start time
    IO.puts "Started at: " <> "#{time_start}"

    # if algo == "push-sum" do
    # :global.whereis_name(:act1) |> send({:sendmessage, [2, {1, 0.5}, algo, topology]})
    # else
    if algo == "gossip" do
      :global.whereis_name(:act1) |> send({:sendmessage, [2, {"Spread", "rumor"}, algo, topology]})
    else
      :global.whereis_name(:act1) |> send({:pushsuminit})
    end
    # IO.puts "Sent gossip"
    # sleepnow("start", numnodes, serverpid)
    Process.sleep(:infinity)
  end

  # def sleepnow(val, numnodes, serverpid) do
  #   res = ""
  #   if val == "start" do
  #     Process.sleep(:infinity)
  #   else
  #     killall(numnodes)
  #     Process.exit(serverpid, :kill)
  #   end
  #   res
  # end

  def create_workers(n, ctr, rumor, algo, topology, counter_map, numnodes) when n < 1 do
    IO.puts "Workers created"
  end

  def create_workers(n, ctr, rumor, algo, topology, counter_map, numnodes) do
    if algo == "push-sum" do
      pid = spawn(WORKER, :listen, [n, ctr, {n,1}, algo, topology, 0, numnodes, n, 1, []])
    else
      pid = spawn(WORKER, :listen, [n, ctr, {""}, algo, topology, 0, numnodes, n, 1, []])
    end
    name = "act" <> "#{n}"
    worker = String.to_atom(name)
    #IO.inspect(worker)
    #IO.inspect(pid)
    # IO.puts(n)
    :global.register_name(worker, pid)
    # counter_map = Map.put(counter_map,n,0)
    create_workers(n-1, ctr, rumor, algo, topology, counter_map, numnodes)
  end

  def killall(n) do
    if n < 1 do
      IO.puts "Terminated all actors"
    else
      name = "act" <> "#{n}"
      worker = String.to_atom(name)
      :global.whereis_name(worker) |> send({:exit, :normal})
     killall(n-1)
   end
  end

  def getk_from_all(counter_map, processpid, time_start, numnodes) do
     receive do
       {:checknodeup,neighs, nodename, name, rumor, algo, topology, flag, numnodes, s_value, w_value} ->
        #  IO.puts "Checking convergence. My val: " <> "#{s_value/w_value}" 
         res_haskey = Map.has_key?(counter_map, nodename)
         res_converged = true
         if res_haskey == true do
           res_val = Map.get(counter_map, name)
           if res_val == 0 do
             res_converged = false
           end
         end
         res = res_haskey && res_converged
        #  IO.puts "From: " <> "#{name}" <> " checking convergence of :" <> "#{nodename}" <> " res: " <> "#{res}"
         reqnode = "act" <> "#{name}"
         client = String.to_atom(reqnode)
        #  IO.inspect( client)
         :global.whereis_name(client) |> send({:sendtonext, [res, neighs, nodename, name, rumor, algo, topology, flag, numnodes, s_value, w_value]})
       {:check_convergence,nodename, s_value, w_value} ->
         clients = Enum.map_reduce(counter_map, 0, fn({k,v}, acc) -> {v, v + acc} end)
         numdone = elem(clients, 1)
        #  IO.puts "Checking convergence: " <> "#{nodename}"
         res_haskey = Map.has_key?(counter_map, nodename)
         res_val = 0
         if res_haskey == true do
           res_val = Map.get(counter_map, nodename)
         end
        if res_val == 0 do
         IO.puts "Pushsum value for: " <> "#{nodename}" <> ": " <> "#{s_value/w_value}"
         counter_map = Map.put(counter_map,nodename,1)
         #counter_map = %{counter_map|client=>1}
        #  IO.inspect(counter_map)
         clients = Enum.map_reduce(counter_map, 0, fn({k,v}, acc) -> {v, v + acc} end)
         numdone = elem(clients, 1)
        #  IO.puts "numdone: " <> "#{numdone}" <> " numnodes: " <> "#{numnodes}"
         percent = Float.round(numdone*100/numnodes, 0)
         IO.puts "Percent completed: " <> "#{percent}" <> "%" <> " Time elapsed: " <> "#{Time.diff(Time.utc_now(),time_start,:millisecond)}" <> " milliseconds"
        end

        #  IO.inspect(counter_map)
         if numdone == numnodes do
           time_end = Time.utc_now()
           IO.puts "Convergence took " <> "#{Time.diff(time_end,time_start,:millisecond)}" <> " milliseconds"
           IO.puts "Killing server and actors"
          #  sleepnow("kill", numnodes, processpid)
          #  killall(numnodes)
           Process.exit(processpid, :kill)
         end
     end
     getk_from_all(counter_map, processpid, time_start, numnodes)
   end

end
