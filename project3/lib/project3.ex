defmodule Project3 do

  def main(args) do
    if length args != 2 do
      pastry(1000, 10)
    else
      {_,input,_}  = OptionParser.parse(args)
      numnodes = Enum.at(input,0)
      {numnodes, _} = :string.to_integer(numnodes)
      numrequests = Enum.at(input,1)
      {numrequests, _} = :string.to_integer(numrequests)
      pastry(numnodes, numrequests)
    end
    Process.sleep(:infinity)
  end

  def pastry(numnodes, numrequests) do
    log4 = Float.ceil(:math.log(numnodes) / :math.log(4))
    nodeIDSpace = round(:math.pow(4, log4))
    ranlist = []
    firstgroup = []

    numfirstgroup =  if numnodes <= 1024 do
      numnodes
    else
      1024
    end
    IO.puts "Number of nodes" <> "#{numnodes}"
    IO.puts "Node ID space: 0 - " <> "#{nodeIDSpace - 1}"
    IO.puts "Number Of Request Per Node: " <> "#{numrequests}"

    ranlist = populaterandomlist(numnodes, ranlist)

    ranlist = Enum.shuffle ranlist
    # ranlist = Enum.reverse ranlist
    IO.inspect(ranlist)

    firstgroup = populatefirstgroup(numfirstgroup - 1, ranlist, firstgroup)
    firstgroup = Enum.reverse firstgroup

    IO.inspect(firstgroup)
    create_workers(numnodes, numrequests, ranlist, numnodes-1, log4)
    spawnserver(ranlist, numfirstgroup, firstgroup, numnodes, numrequests)
    :global.whereis_name(:server) |> send({:go})
  end

  def populaterandomlist(nodeidspace, randomlist) when nodeidspace < 1 do
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

  def serve(ranlist, numfirstgroup, firstgroup, numjoined, numnodes, numnotinboth, numrouted, numhops, numrequests, numroutenotinboth) do
    receive do
        {:go} ->
          IO.puts "Join starts..."
          messageallworkers("firstjoin", ranlist, numfirstgroup - 1, [firstgroup])
        # case Go =>
        #   println("Join Begins...")
        #   for (i <- 0 until numFirstGroup)
        #     context.system.actorSelection("/user/master/" + ranlist(i)) ! FirstJoin(firstGroup.clone)

        {:joinfinish} ->
          IO.puts "First group join finished"
          numjoined = numjoined + 1
          if numjoined == numfirstgroup do
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
        #
        # case JoinFinish =>
        #   numJoined += 1
        #   if (numJoined == numFirstGroup) {
        #     //println("First Group Join Finished!")
        #     if (numJoined >= numNodes) {
        #       self ! BeginRoute
        #     } else {
        #       self ! SecondJoin
        #     }
        #   }

          # if (numJoined > numFirstGroup) {
          #   if (numJoined == numNodes) {
          #     //println("Routing Not In Both Count: " + numNotInBoth)
          #     //println("Ratio: " + (100 * numNotInBoth.toDouble / numNodes.toDouble) + "%")
          #     self ! BeginRoute
          #   } else {
          #     self ! SecondJoin
          #   }
          #
          # }

        {:secondjoin} ->
          startid = :rand.uniform(numjoined)
          messageworker(startid, "route", ["join", startid, Enum.at(ranlist, numjoined), -1])

        # case SecondJoin =>
        #   val startID = ranlist(Random.nextInt(numJoined))
        #   context.system.actorSelection("/user/master/" + startID) ! Route("Join", startID, ranlist(numJoined), -1)

        {:beginroute} ->
          IO.puts "Join finished"
          IO.puts "Routing begins"
          messageallworkers("beginroute", ranlist, numnodes - 1, [])

        # case BeginRoute =>
    	  # println("Join Finished!")
        #   println("Routing Begins...")
        #   context.system.actorSelection("/user/master/*") ! BeginRoute
        {:notinboth} ->
          numnotinboth = numnotinboth + 1

        # case NotInBoth =>
        #   numNotInBoth += 1

        {:routefinish, [fromid, toid, hops]} ->
          numrouted = numrouted + 1
          numhops = numhops + hops
          if numrouted >= numnodes * numrequests do
            IO.puts "Number of total routes: " <> "#{numrouted}"
            IO.puts "Number of total hops: " <> "#{numhops}"
            IO.puts "Average hops per route: " <> "#{numhops / numrouted}"
            Process.exit(self, :kill)
          end
        #
        # case RouteFinish(fromID, toID, hops) =>
        #   numRouted += 1
        #   numHops += hops
        #   for (i <- 1 to 10)
        #     if (numRouted == numNodes * numRequests * i / 10)
        #       println(i + "0% Routing Finished...")
        #
        #   if (numRouted >= numNodes * numRequests) {
        #     println("Number of Total Routes: " + numRouted)
        #     println("Number of Total Hops: " + numHops)
        #     println("Average Hops Per Route: " + numHops.toDouble / numRouted.toDouble)
        #     //println("Route Not In Both Count: " + numRouteNotInBoth)
        #     context.system.shutdown()
        #   }

        {:routenotinboth} ->
          numroutenotinboth = numroutenotinboth + 1
      #   case RouteNotInBoth =>
      #     numRouteNotInBoth += 1
      # }
    end
    serve(ranlist, numfirstgroup, firstgroup, numjoined, numnodes, numnotinboth, numrouted, numhops, numrequests, numroutenotinboth)
  end

  def create_workers(numnodes, numrequests, ranlist, id, log4) when id < 0 do
    IO.puts "Workers created"
  end

  def create_workers(numnodes, numrequests, ranlist, id, log4) do
    #     val myID = id;
    # var lessLeaf = new ArrayBuffer[Int]()
    # var largerLeaf = new ArrayBuffer[Int]()
    # var table = new Array[Array[Int]](log4)
    # var numOfBack: Int = 0
    # val IDSpace: Int = pow(4, log4).toInt

    # var i = 0
    # for (i <- 0 until log4)
    #   table(i) = Array(-1, -1, -1, -1)

    # numNodes, numRequests, id, log4, table, numofback, lessleaf, largerleaf, idspace
    lessleaf = []
    largerleaf = []
    numofback = 0
    idspace = round(:math.pow(4, log4))
    table = []
    sublist = [-1, -1, -1, -1]
    for i <- 0..log4, do: table = table ++ sublist
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

  def messageallworkers(func, ranlist, numnodes, args) when numnodes < 0 do
    IO.puts "Message sent to all workers"
  end

  def messageallworkers(func, ranlist, numnodes, args) do
    messageworker(Enum.at(ranlist, numnodes), func, args)
    messageallworkers(func, ranlist, numnodes - 1, args)
  end

  def spawnserver(ranlist, numfirstgroup, firstgroup, numnodes, numrequests) do
    numjoined = 0
    numnotinboth = 0
    numrouted = 0
    numhops = 0
    numroutenotinboth = 0
    pid = spawn(Proect3, :serve, [ranlist, numfirstgroup, firstgroup, numjoined, numnodes, numnotinboth, numrouted, numhops, numrequests, numroutenotinboth])
    :global.register_name(:server, pid)
    pid
  end
end
