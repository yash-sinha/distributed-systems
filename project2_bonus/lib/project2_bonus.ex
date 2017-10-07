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
    if algo == "gossip" do
      :global.whereis_name(:act1) |> send({:sendmessage, [2, {"Spread", "rumor"}, algo, topology]})
    else
      :global.whereis_name(:act1) |> send({:pushsuminit})
    end

    Process.sleep(:infinity)
  end

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

  def getk_from_all(counter_map, processpid, time_start, numnodes,failureNodes,deleted) do
     receive do
       {:check_convergence,client} ->
         counter_map = Map.put(counter_map,client,1)
         clients = Enum.map_reduce(counter_map, 0, fn({k,v}, acc) -> {v, v + acc} end)
         numdone = elem(clients, 1)
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
           Process.exit(processpid, :kill)
         end

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
