defmodule Project2Bonus do

    def main(args) do
      {_,input,_}  = OptionParser.parse(args)
      numnodes = Enum.at(input,0)
      {numnodes, _} = :string.to_integer(numnodes)
      topology = Enum.at(input,1)
      algo = Enum.at(input,2)
      failures = Enum.at(input,3)
      {failureNodes, _} = :string.to_integer(failures)
      ctr = 0
      rumor = {}

      #Taking 
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
    serverpid = spawn(Project2Bonus, :getk_from_all, [counter_map, processpid, time_start, numnodes,failureNodes,0])
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

  def getk_from_all(counter_map, processpid, time_start, numnodes,failureNodes,deleted) do
     receive do
       {:check_convergence,client} ->
         counter_map = Map.put(counter_map,client,1)
         #counter_map = %{counter_map|client=>1}
         clients = Enum.map_reduce(counter_map, 0, fn({k,v}, acc) -> {v, v + acc} end)
         numdone = elem(clients, 1)
        #  IO.puts "numdone: " <> "#{numdone}" <> " numnodes: " <> "#{numnodes}"
        if numnodes - failureNodes <= 0 do
          IO.puts "All available nodes were killed!"
          percent = 100
        else
          percent = Float.round(numdone*100/numnodes, 0)
          IO.puts "#{client}" <> " received gossip"

        end
        if(numdone + failureNodes >= numnodes) do
          percent = 100
        end
        IO.puts "Percent completed: " <> "#{percent}" <> "%"
         if percent == 100 do
           time_end = Time.utc_now()
           IO.puts "Convergence took " <> "#{Time.diff(time_end,time_start,:millisecond)}" <> " milliseconds"
           IO.puts "Killing server and actors"
          #  sleepnow("kill", numnodes, processpid)
          #  killall(numnodes)
           Process.exit(processpid, :kill)
         end

         #Adding failure cases
       after
         2 ->
           if(deleted == 0) do
           remainingNodes= Enum.to_list(1..numnodes) #initializing remaining nodes as full list
           analyseFailureNodes(failureNodes,remainingNodes)
           deleted=1
          end
     end
     getk_from_all(counter_map, processpid, time_start, numnodes,failureNodes,deleted)
   end


def analyseFailureNodes(failureNodes,numNodes) do
#failure nodes give the number of nodes user entered to fail
if(failureNodes < 1 || length(numNodes) == 0) do
  IO.puts "Showing results after failure node deletion..."
else
  n= Enum.random(numNodes)
  remainingNodes = numNodes -- [n]
  name = "act" <> "#{n}"
  worker = String.to_atom(name)

  if :global.whereis_name(worker) != :undefined  do
      IO.puts "Failure node detected node!! -->" <> "#{name}"
  :global.whereis_name(worker) |> send({:exit, :normal})
  analyseFailureNodes(failureNodes-1,remainingNodes)
else
  analyseFailureNodes(failureNodes,remainingNodes)
end
end
end


end
