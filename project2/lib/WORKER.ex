defmodule WORKER do
    def listen(me, ctr, rum, algo, topology, flag, numnodes, s_value, w_value, ratio_list) do
        name = me
        msg = rum
        receive do
            {:exit, reason} -> Process.exit(self(), reason)
            {:ok, response} -> IO.puts "here"
            {:sendmessage, [fromclient, rumor, algo, toplogy]} ->
                            cond do
                              #When the nodes receives message it will keep on sending messages for 10 rounds and checking the condition of convergence
                              #In case of gossip algorithm if all the nodes receives the rumour started by inintial node atleast once, it receives convergence
                              algo == "gossip" ->
                                if ctr > 0 && flag != 1 do
                                  :global.whereis_name(:server) |> send({:check_convergence,me, s_value, w_value})
                                  flag = 1
                                end
                                if (ctr < 10) do
                                    ctr = ctr + 1
                                    msg = rumor
                                    sendrumour(name, rumor, algo, topology, flag, numnodes, s_value, w_value)
                                end
                              algo == "push-sum"  ->
                                #When the nodes receives s,w value, it will update it values and then maintain the list to keep the latest 3 s/w ratio values
                                #It will start to keep on sending rumour (s,v tuple) after it receives first time
                                if flag != 1 do
                                    s_value = s_value + elem(rumor, 0)
                                    w_value = w_value + elem(rumor, 1)

                                    s_value = s_value / 2
                                    w_value = w_value / 2

                                    ratio = s_value / w_value
                                    msg = {s_value, w_value}
                                    #IO.puts(inspect(self()) <> " --- " <> to_string ratio)

                                    if ratio_list == nil || (length ratio_list) < 4 do
                                        ratio_list = ratio_list ++ [ratio]
                                    else
                                        ratio_list = ratio_list ++ [ratio]
                                        ratio_list = List.delete_at(ratio_list, 0)
                                    end

                                    sendrumour(name, msg, algo, topology, flag, numnodes, s_value, w_value)
                                end
                              true -> "Invalid algo"
                            end
              {:pushsuminit} ->
                s_value = s_value / 2
                w_value = w_value / 2
                ratio = s_value / w_value
                msg = {s_value, w_value}
                ratio_list = ratio_list ++ [ratio]
                sendrumour(name, msg, algo, topology, flag, numnodes, s_value, w_value)
              {:sendtonext, [isconverged, neighs, node, name, rumor, algo, topology, flag, numnodes, s_value, w_value]} ->
                if isconverged == true do
                  neighs = neighs -- [node]
                  if length(neighs) == 0  do
                    if !(topology =="line" && numnodes >500) do

                    nodename = "act" <> "#{me}"
                    client = String.to_atom(nodename)
                    :global.whereis_name(client) |> send({:sendmessage, [name, rumor, algo, topology]})
                  end
                  else
                    node = Enum.random(neighs)
                    # nodename = "act" <> "#{node}"
                    sendtoneighbours(neighs, node, name, rumor, algo, topology, flag, numnodes, s_value, w_value)
                  end
                else
                  nodename = "act" <> "#{node}"
                  client = String.to_atom(nodename)
                  :global.whereis_name(client) |> send({:sendmessage, [name, rumor, algo, topology]})
                end

        end
        cond do
          algo == "push-sum" ->
            if ratio_list != nil && (length ratio_list) ==  4 do
                threshold = :math.pow(10, -10)
                if flag != 1 do
                  #flag==1 keeps the track whether node has achieved convergence and then send the status to the main process to update the counter_map
                    if abs((Enum.at(ratio_list, 1) - Enum.at(ratio_list, 0))) <= threshold &&
                        abs((Enum.at(ratio_list, 2) - Enum.at(ratio_list, 1))) <= threshold &&
                        abs((Enum.at(ratio_list, 3) - Enum.at(ratio_list, 2))) <= threshold do
                        flag = 1
                        :global.whereis_name(:server) |> send({:check_convergence,me,  s_value, w_value})
                    end
                else
                    :timer.sleep(100)
                    sendrumour(name, msg, algo, topology, flag, numnodes, s_value, w_value)
                end
            end
          algo == "gossip" && tuple_size(msg)>0  && ctr < 10 ->
            sendrumour(name, msg, algo, topology, flag, numnodes, s_value, w_value)
          true -> ""
        end

      listen(name, ctr, msg, algo, topology, flag, numnodes, s_value, w_value, ratio_list)
    end

   #It will randomly pic neighbour based on the different types of topology built and then keep on sending rumour untill threshold condition is reached
    def sendrumour(name, rumor, algo, topology, flag, numnodes, s_value, w_value) do
      # #IO.puts "I am about to send rumour"
        nodename = ""
        list = []

        #list will have neighbours based on condition selected
        case topology do
          #line topology will have left and right neighbour except ends which will have one neighbour
            "line" ->
                cond do
                    name == 1 ->
                        node = name + 1
                        nodename = "act" <> "#{node}"
                        list = list ++ [node]

                    name == numnodes ->
                        node = name - 1
                        nodename = "act" <> "#{node}"
                        list = list ++ [node]

                    true ->
                        next = name + 1
                        prev = name - 1
                        node = Enum.random([prev, next])
                        nodename="act" <> "#{node}"
                        list = list ++ [node]
                end

            "full" ->
                list = Enum.to_list(1..numnodes) #TODO numnodes is 4
                list = List.delete(list, name)
                node = Enum.random(list)
                nodename = "act" <> "#{node}"

                #2D topology will have all the neighbours in 2D grid (i-1,j) , (i,j+1), (i,j-1), (i+1,j)  for (i,j)
                #Total number nodes have been already adjusted as nearest perfect square while taking input
                #All boundary and edge case i.e Row number starts from 0 and colum starts from 1 has been handles in if condition
            "2D" ->
                list = []
                sqrtnumnodes = round(:math.pow(numnodes, 1/2))
                rows = round(Float.floor(name/sqrtnumnodes, 0)) #TODO sqrtnumnodes
                col = rem(name,sqrtnumnodes)

                #edge case for top left corner and bottom right
                if col == 0 do
                  rows = rows - 1
                  col = sqrtnumnodes #sqrtnumnodes
                end
                neigh1 = -1
                neigh2 = -1
                neigh3 = -1
                neigh4 = -1
                #row number starts from 0
                if rows > 0 do
                  neigh1 = sqrtnumnodes* (rows - 1) + col #converting to id
                end
                #colum number starts from 1
                if col > 1 do
                  neigh2 = sqrtnumnodes* rows + col - 1 #converting to id
                end
                #rows ranges from 0 to n-1
                if rows < sqrtnumnodes - 1 do
                  neigh3 = sqrtnumnodes* (rows + 1) + col #converting to id
                end
                #columns ranges from 1 to n
                if col < sqrtnumnodes do
                  neigh4 = sqrtnumnodes* rows + col + 1 #converting to id
                end

                #Add all the four available neighbours in the list (0 can not be the node neighbour as it starts from 1)
                if neigh1 != -1 && neigh1 != 0 do
                  list = list ++ [neigh1]
                end

                if neigh2 != -1 && neigh2 != 0 do
                  list = list ++ [neigh2]
                end

                if neigh3 != -1 && neigh3 != 0 do
                  list = list ++ [neigh3]
                end

                if neigh4 != -1 && neigh4 != 0 do
                    list = list ++ [neigh4]
                end
                node = Enum.random(list)
                nodename = "act" <> "#{node}"

                #Imp2D topology will have all the neighbours in 2D grid (i-1,j) , (i,j+1), (i,j-1), (i+1,j)  for (i,j) and PLUS one other random node
                #Rest is same as that of 2D
            "imp2D" ->
              #here sqrtnumnodes is 16, so sqrt = 4
              list = []
              sqrtnumnodes = round(:math.pow(numnodes, 1/2))
              rows = round(Float.floor(name/sqrtnumnodes, 0)) #TODO sqrtnumnodes
              col = rem(name,sqrtnumnodes)
              if col == 0 do #edge cases
                rows = rows - 1
                col = sqrtnumnodes #sqrtnumnodes
              end
              neigh1 = -1
              neigh2 = -1
              neigh3 = -1
              neigh4 = -1
              if rows > 0 do
                neigh1 = sqrtnumnodes* (rows - 1) + col #converting to id
              end
              if col > 1 do
                neigh2 = sqrtnumnodes* rows + col - 1 #converting to id
              end
              if rows < sqrtnumnodes - 1 do #TODO
                neigh3 = sqrtnumnodes* (rows + 1) + col #converting to id
              end
              if col < sqrtnumnodes do
                neigh4 = sqrtnumnodes* rows + col + 1 #converting to id
              end

              if neigh1 != -1 && neigh1 != 0 do
                list = list ++ [neigh1]
              end

              if neigh2 != -1 && neigh2 != 0 do
                list = list ++ [neigh2]
              end

              if neigh3 != -1 && neigh3 != 0 do
                list = list ++ [neigh3]
              end

              if neigh4 != -1 && neigh4 != 0 do
                  list = list ++ [neigh4]
              end

              tlist = Enum.to_list(1..numnodes)
              # #IO.puts "tlist before"
              # #IO.inspect(tlist)
              tlist = tlist -- list
              tlist = tlist -- [name]
              if length(tlist) == 0 do
                #IO.inspect(list)
                #IO.puts name
              end
              # #IO.puts "tlist after"
              # #IO.inspect(tlist)
              # #IO.puts "list is"
              # #IO.inspect(list)

              node = Enum.random(tlist)
              list = list ++ [node]
              node = Enum.random(list)
              nodename = "act" <> "#{node}"
            _ -> IO.puts "Invalid Topology"
        end


        #Done with topology
        #send rumor according to algo

        sendtoneighbours(list, node, name, rumor, algo, topology, flag, numnodes, s_value, w_value)

	#sending rumours to neighbours and checknode checkes the convergence condition
	#Here send to neighbour will also keep on monitoring whether the selected neighbours have achieved the convergence or not
	#main project2.ex gets the status of nodes as and when it converges in the counter_map
	#below method will send the neighbour list to the project2 checkupnodes, then it will update the list will the updated neighbours (only the one's which have not converged
	# or are still alive (transmitting messages))
      end

#checknodeup will direct to sendtonext method above which will send the message above (It will consider the node to be converged if neighs updated list is empty or all the neighbours have been converged)
    def sendtoneighbours(neighs, nodename, name, rumor, algo, topology, flag, numnodes, s_value, w_value) do
      :global.whereis_name(:server) |> send({:checknodeup,neighs, nodename, name, rumor, algo, topology, flag, numnodes, s_value, w_value})
    end
end
