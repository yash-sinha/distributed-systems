defmodule Project3 do

  def main(args) do
    processpid = self()
    if length(args) != 2 do
      pastry(1000, 10, processpid)
    else
      {_,input,_}  = OptionParser.parse(args)
      numnodes = Enum.at(input,0)
      {numnodes, _} = :string.to_integer(numnodes)
      numrequests = Enum.at(input,1)
      {numrequests, _} = :string.to_integer(numrequests)
      pastry(numnodes, numrequests, processpid)
    end
    Process.sleep(:infinity)
  end

  def pastry(numnodes, numrequests, processpid) do
    log4 = round(Float.ceil(:math.log(numnodes) / :math.log(4)))
    nodeidspace = round(:math.pow(4, log4))
    ranlist = []
    firstgroup = []
    numfirstgroup = numnodes
    # numfirstgroup =  if numnodes <= 1024 do
    #   numnodes
    # else
    #   1024
    # end
    IO.puts "Number of nodes: " <> "#{numnodes}"
    IO.puts "Node ID space: 0 - " <> "#{nodeidspace - 1}"
    IO.puts "Number Of Request Per Node: " <> "#{numrequests}"
    IO.puts "log4: " <> "#{log4}"
    ranlist = populaterandomlist(nodeidspace - 1, ranlist)
    ranlist = Enum.shuffle ranlist
    IO.inspect(ranlist)

    firstgroup = populatefirstgroup(numfirstgroup - 1, ranlist, firstgroup)
    firstgroup = Enum.reverse firstgroup

    IO.inspect(firstgroup)
    spawnserver(ranlist, numfirstgroup, firstgroup, numnodes, numrequests, processpid)
    create_workers(numnodes, numrequests, ranlist, numnodes-1, log4)
    :global.whereis_name(:server) |> send({:go})
  end

  def populaterandomlist(nodeidspace, randomlist) when nodeidspace < 0 do
     randomlist
  end

  def populaterandomlist(nodeidspace, randomlist) do
    randomlist = randomlist ++ [nodeidspace]
    populaterandomlist(nodeidspace - 1, randomlist)
  end

  def populatefirstgroup(numFirstGroup, randomlist, firstgroup) when numFirstGroup < 0 do
     firstgroup
  end

  def populatefirstgroup(numFirstGroup, randomlist, firstgroup) do
    firstgroup = firstgroup ++ [Enum.at(randomlist, numFirstGroup)]
    populatefirstgroup(numFirstGroup - 1, randomlist, firstgroup)
  end

  def serve(ranlist, numfirstgroup, firstgroup, numjoined, numnodes, numnotinboth, numrouted, numhops, numrequests, numroutenotinboth, processpid) do
    receive do
        {:go} ->
          IO.puts "Join starts..."
          messageallworkers("firstjoin", ranlist, numfirstgroup - 1, [firstgroup, "server"])

        {:joinfinish} ->
          numjoined = numjoined + 1
          if numjoined == numfirstgroup do
            IO.puts "First group join finished for -- " <> "#{numjoined}" <> " nodes."
            if numjoined >= numnodes do
              :global.whereis_name(:server) |> send({:beginroute})
            else
              :global.whereis_name(:server) |> send({:secondjoin})
            end
          end

          if numjoined > numfirstgroup do
            if numjoined == numnodes do
              IO.puts "Routing not in both count: " <> "#{numnotinboth}"
              :global.whereis_name(:server) |> send({:beginroute})
            else
              :global.whereis_name(:server) |> send({:secondjoin})
            end
          end

        {:secondjoin} ->
          startid = :rand.uniform(numjoined)
          messageworker(startid, "route", ["join", startid, Enum.at(ranlist, numjoined), -1, -1])

        {:beginroute} ->
          IO.puts "Join finished"
          IO.puts "Routing begins"
          messageallworkers("beginroute", ranlist, numnodes - 1, [])

        {:notinboth} ->
          numnotinboth = numnotinboth + 1

        {:routefinish, [fromid, toid, hops]} ->
          numrouted = numrouted + 1
          numhops = numhops + hops
          if numrouted == numnodes * numrequests do
            IO.puts "Number of total routes: " <> "#{numrouted}"
            IO.puts "Number of total hops: " <> "#{numhops}"
            IO.puts "Average hops per route: " <> "#{numhops / numrouted}"
            Process.exit(processpid, :kill)
          end

        {:routenotinboth} ->
          numroutenotinboth = numroutenotinboth + 1
    end
    serve(ranlist, numfirstgroup, firstgroup, numjoined, numnodes, numnotinboth, numrouted, numhops, numrequests, numroutenotinboth, processpid)
  end

  def create_workers(numnodes, numrequests, ranlist, id, log4) when id < 0 do
    IO.puts "Workers created"
  end

  def create_workers(numnodes, numrequests, ranlist, id, log4) do
    lessleaf = []
    largerleaf = []
    numofback = 0
    total = round(:math.pow(4, log4))
    idspace = Enum.to_list(0..(total - 1))#round(:math.pow(4, log4))
    idspace = idspace -- [Enum.at(ranlist, id)]
    table = []
    sublist = [-1, -1, -1, -1]
    table = for i <- 0..(log4 - 1), do: table = table ++ sublist
    pid = spawn(WORKER, :listen, [numnodes, numrequests, Enum.at(ranlist, id), log4, table, numofback, lessleaf, largerleaf, idspace])
    name = "act" <> "#{Enum.at(ranlist, id)}"
    worker = String.to_atom(name)
    :global.register_name(worker, pid)
    create_workers(numnodes, numrequests, ranlist, id - 1, log4)
  end

  def messageworker(id, func, args) do
    name = "act" <> "#{id}"
    worker = String.to_atom(name)
    funcatom = String.to_atom(func)
    :global.whereis_name(worker) |> send({funcatom, args})
  end

  def messageworkernoargs(id, func) do
    name = "act" <> "#{id}"
    worker = String.to_atom(name)
    funcatom = String.to_atom(func)
    :global.whereis_name(worker) |> send({funcatom})
  end

  def messageallworkers(func, ranlist, numnodes, args) when numnodes < 0 do
    IO.puts "Message sent to all workers"
  end

  def messageallworkers(func, ranlist, numnodes, args) do
    if length(args) == 0 do
      messageworkernoargs(Enum.at(ranlist, numnodes), func)
    else
      messageworker(Enum.at(ranlist, numnodes), func, args)
    end
    messageallworkers(func, ranlist, numnodes - 1, args)
  end

  def spawnserver(ranlist, numfirstgroup, firstgroup, numnodes, numrequests, processpid) do
    numjoined = 0
    numnotinboth = 0
    numrouted = 0
    numhops = 0
    numroutenotinboth = 0
    pid = spawn(Project3, :serve, [ranlist, numfirstgroup, firstgroup, numjoined, numnodes, numnotinboth, numrouted, numhops, numrequests, numroutenotinboth, processpid])
    :global.register_name(:server, pid)
    pid
  end
end
