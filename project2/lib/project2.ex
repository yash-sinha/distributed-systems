defmodule Project2 do

    def main(args) do
      {_,input,_}  = OptionParser.parse(args)
      numnodes = Enum.at(input,0)
      {numnodes, _} = :string.to_integer(numnodes)
      topology = Enum.at(input,1)
      algo = Enum.at(input,2)
      ctr = 0
      rumor = {}

      #Taking nearest square value according to total number of input nodes
      if(topology == "2D" || topology == "imp2D")
      do
        i= :math.pow(numnodes,1/2)
        i=Float.floor(i,0)
        numnodes = round(i * i)
      end

    processpid = self
    counter_map = %{}

    # spawn all the workers based on number of nodes
    create_workers(numnodes, ctr, rumor, algo, topology, counter_map, numnodes)

    #start time
    time_start = Time.utc_now()

    #spawn server process which will get the status of converged nodes
    serverpid = spawn(Project2, :getk_from_all, [counter_map, processpid, time_start, numnodes, algo])
    :global.register_name(:server, serverpid)

    #Start time
    IO.puts "Started at: " <> "#{time_start}"

    #Start the rumour in one of the nodes to trigger the gossip spreading process / start from mid in push-sum to get the added advantage in line topology
    if algo == "gossip" do
      :global.whereis_name(:act1) |> send({:sendmessage, [2, {"Spread", "rumor"}, algo, topology]})
    else
      mid = round(numnodes/2)
      start = "act" <> "#{mid}"
      client = String.to_atom(start)
      :global.whereis_name(client) |> send({:pushsuminit})
    end

    #To keep the main process running
    Process.sleep(:infinity)
  end


  #Recursive function to spawn all the workers as per given number of nodes
  #We are using rumour as the tuple of s value and w value in case of push sum and combination of strings in case of gossip
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
    :global.register_name(worker, pid)
    create_workers(n-1, ctr, rumor, algo, topology, counter_map, numnodes)
  end

 #Nodes will update the status of convergence in the counter_map to track the percentage of convergence
  def getk_from_all(counter_map, processpid, time_start, numnodes, algo) do
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

         reqnode = "act" <> "#{name}"
         client = String.to_atom(reqnode)
         :global.whereis_name(client) |> send({:sendtonext, [res, neighs, nodename, name, rumor, algo, topology, flag, numnodes, s_value, w_value]})
       {:check_convergence,nodename, s_value, w_value} ->
         if algo == "gossip" do
           counter_map = Map.put(counter_map,nodename,1)
           clients = Enum.map_reduce(counter_map, 0, fn({k,v}, acc) -> {v, v + acc} end)
           numdone = elem(clients, 1)
           percent = Float.round(numdone*100/numnodes, 0)
           IO.puts "Percent completed: " <> "#{percent}" <> "%" <> " Time elapsed: " <> "#{Time.diff(Time.utc_now(),time_start,:millisecond)}" <> " milliseconds"
         else
           clients = Enum.map_reduce(counter_map, 0, fn({k,v}, acc) -> {v, v + acc} end)
           numdone = elem(clients, 1)
           res_haskey = Map.has_key?(counter_map, nodename)
           res_val = 0
           if res_haskey == true do
             res_val = Map.get(counter_map, nodename)
           end
          if res_val == 0 do
           IO.puts "Pushsum value for: " <> "#{nodename}" <> ": " <> "#{s_value/w_value}"
           counter_map = Map.put(counter_map,nodename,1)
           clients = Enum.map_reduce(counter_map, 0, fn({k,v}, acc) -> {v, v + acc} end)
           numdone = elem(clients, 1)
           percent = Float.round(numdone*100/numnodes, 0)
           IO.puts "Percent completed: " <> "#{percent}" <> "%" <> " Time elapsed: " <> "#{Time.diff(Time.utc_now(),time_start,:millisecond)}" <> " milliseconds"
          end
         end

         if numdone == numnodes do
           time_end = Time.utc_now()
           IO.puts "Convergence took " <> "#{Time.diff(time_end,time_start,:millisecond)}" <> " milliseconds"
           IO.puts "Killing server and actors"
           Process.exit(processpid, :kill)
         end
       after 1000 ->
         IO.puts "Time elapsed.. " <> "#{Time.diff(Time.utc_now(),time_start,:millisecond)}" <> " milliseconds"
     end
     getk_from_all(counter_map, processpid, time_start, numnodes, algo)
   end

end
