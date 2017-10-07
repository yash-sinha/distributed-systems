defmodule WORKER do
    def listen(me, ctr, rum, algo, topology, flag, numnodes, s_value, w_value, ratio_list) do
        name = me
        msg = rum
        receive do
            {:exit, reason} -> Process.exit(self(), reason)
            {:ok, response} -> IO.puts "here"
            {:sendmessage, [fromclient, rumor, algo, toplogy]} ->
                            cond do
                              algo == "gossip" ->
                                if ctr > 0 && flag != 1 do
                                  :global.whereis_name(:server) |> send({:check_convergence,me})
                                  flag = 1
                                end
                                if (ctr < 10) do
                                    ctr = ctr + 1
                                    msg = rumor
                                    sendrumour(name, rumor, algo, topology, flag, numnodes, s_value, w_value)
                                end
                              algo == "push-sum"  ->
                                if flag!=1 do
                                    s_value = s_value + elem(rumor, 0)
                                    w_value = w_value + elem(rumor, 1)

                                    s_value = s_value / 2
                                    w_value = w_value / 2

                                    ratio = s_value / w_value
                                    msg = {s_value, w_value}

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

        end
        cond do
          algo == "push-sum" ->
            if ratio_list != nil && (length ratio_list) ==  4 do
                threshold = :math.pow(10, -10)
                if flag != 1 do
                    if abs((Enum.at(ratio_list, 1) - Enum.at(ratio_list, 0))) <= threshold &&
                        abs((Enum.at(ratio_list, 2) - Enum.at(ratio_list, 1))) <= threshold &&
                        abs((Enum.at(ratio_list, 3) - Enum.at(ratio_list, 2))) <= threshold do
                        flag = 1
                        IO.puts "Pushsum value for: " <> "#{me}" <> ": " <> "#{s_value/w_value}"
                        :global.whereis_name(:server) |> send({:check_convergence,me})
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

    def sendrumour(name, rumor, algo, topology, flag, numnodes, s_value, w_value) do
        nodename = ""
        list = []
        case topology do
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

            "2D" ->
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
                node = Enum.random(list)
                nodename = "act" <> "#{node}"

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

              tlist = Enum.to_list(1..numnodes) #sqrtnumnodes is 4
              tlist = tlist -- list
              tlist = tlist -- [name]
              node = Enum.random(tlist)
              list = list ++ [node]
              node = Enum.random(list)
              nodename = "act" <> "#{node}"
            _ -> IO.puts "Invalid Topology"
        end
        sendtoneighbours(list, node, name, rumor, algo, topology, flag, numnodes, s_value, w_value)
    end

    def sendtoneighbours(neighs, nodename, name, rumor, algo, topology, flag, numnodes, s_value, w_value) do
      nodename = "act" <> "#{nodename}"
      client = String.to_atom(nodename)
      if :global.whereis_name(client) != :undefined && :global.whereis_name(client) |> Process.alive? == true do
        :global.whereis_name(client) |> send({:sendmessage, [name, rumor, algo, topology]})
      end

    end
end
