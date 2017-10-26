defmodule WORKER do
    def listen(numnodes, numrequests, id, log4, table, numofback, lessleaf, largerleaf, idspace) do
      receive do
        {:firstjoin, [firstgroup, sender]} ->
          ######IO.puts "firstjoin"
          firstgroup = firstgroup -- [id]
          reslist = addbuffer(firstgroup, length(firstgroup) - 1, id, largerleaf, lessleaf, log4, table)
          table = Enum.at(reslist, 0)
          lessleaf = Enum.at(reslist, 1)
          largerleaf = Enum.at(reslist, 2)
          :global.whereis_name(:server) |> send({:joinfinish})

        {:route, [msg, fromid, toid, hops, sender]} ->
          cond do
              msg == "join" ->
                    samePre = sameprefix(toBase4String(id, log4), toBase4String(toid, log4))

                    if(hops == -1 && samePre >0) do
                        j = Enum.to_list(0..(samePre - 1))
                        Enum.each(j, fn(s) ->  messageworker(toid, "addrow", [s, Enum.at(table, s)])  end)
                    end
                    messageworker(toid, "addrow", [samePre,Enum.at(table, samePre)])

                    cond do
                        (length(lessleaf) > 0 && toid >= Enum.min(lessleaf) && toid <= id)  || (length(largerleaf)> 0 && toid <= Enum.max(largerleaf) && toid >= id) ->
                              diff = length(idspace) + 10
                              nearest = -1
                              if(toid < id) do
                                reslist = getnearest(lessleaf, length(lessleaf) - 1, diff, nearest, [], toid)
                                diff = Enum.at(reslist, 0)
                                nearest = Enum.at(reslist, 1)

                              else
                                reslist = getnearest(largerleaf, length(largerleaf) - 1, diff, nearest, [], toid)
                                diff = Enum.at(reslist, 0)
                                nearest = Enum.at(reslist, 1)
                              end

                             if(abs(toid - id) > diff) do
                                messageworker(nearest, "route", [msg, fromid, toid, hops + 1, id])
                             else
                                allleaf = [id] ++ lessleaf ++ largerleaf
                                messageworker(toid, "addleaf", [allleaf])
                             end

                       (length(lessleaf) <= 4 && length(lessleaf) > 0 && toid < Enum.min(lessleaf)) ->
                             messageworker(Enum.min(lessleaf), "route", [msg, fromid, toid, hops+1, id])

                       (length(largerleaf) <= 4 && length(largerleaf) > 0 && toid > Enum.max(largerleaf)) ->
                             messageworker(Enum.max(largerleaf), "route", [msg,fromid, toid, hops+1, id])

                       ((length(lessleaf) == 0 && toid < id) || (length(largerleaf) == 0 && toid > id)) ->
                             allleaf = [id] ++ lessleaf ++ largerleaf
                             messageworker(toid, "addleaf", [allleaf])

                       getfromtable(table, samePre, String.to_integer(String.at(toBase4String(toid, log4), samePre)) != -1) ->
                             value = getfromtable(table, samePre, String.to_integer(String.at(toBase4String(toid, log4), samePre)))
                             messageworker(value, "route", [msg, fromid, toid, hops + 1, id])

                       (toid > id) ->
                             messageworker(Enum.max(largerleaf), "route", [msg,fromid, toid, hops + 1, id])
                             :global.whereis_name(:server) |> send({String.to_atom("notinboth")})

                       (toid < id) ->
                             messageworker(Enum.min(lessleaf), "route", [msg,fromid, toid, hops + 1, id])
                             :global.whereis_name(:server) |> send({String.to_atom("notinboth")})

                       true ->  IO.puts "Something went wrong in Route!"

                    end

              (msg == "route") ->
                    if(id == toid) do
                      :global.whereis_name(:server) |> send({:routefinish, [fromid, toid, hops]})
                    else
                      samePre = sameprefix(toBase4String(id, log4), toBase4String(toid, log4))
                      cond do
                         ((length(lessleaf) > 0 && toid >= Enum.min(lessleaf) && toid < id) ||
                            (length(largerleaf) > 0 && toid <= Enum.max(largerleaf) && toid > id)) ->
                            diff = length(idspace) + 10
                            nearest = -1

                            if (toid < id) do
                              reslist = getnearest(lessleaf, length(lessleaf) - 1, diff, nearest, [], toid)
                              diff = Enum.at(reslist, 0)
                              nearest = Enum.at(reslist, 1)

                              else
                                reslist = getnearest(largerleaf, length(largerleaf) - 1, diff, nearest, [], toid)
                                diff = Enum.at(reslist, 0)
                                nearest = Enum.at(reslist, 1)
                            end
                            if (abs(toid - id) > diff) do
                              messageworker(nearest, "route", [msg, fromid, toid, hops + 1, id])
                            else
                              if hops == -1 do
                                hops = 0
                              end
                              :global.whereis_name(:server) |> send({String.to_atom("routefinish"), [fromid, toid, hops]})
                            end

                            getfromtable(table, samePre, String.to_integer(String.at(toBase4String(toid, log4), samePre))) != -1 ->
                               messageworker(getfromtable(table, samePre, String.to_integer(String.at(toBase4String(toid, log4), samePre))), "route", [msg, fromid, toid, hops + 1, id])

                          (length(lessleaf) <= 4 && length(lessleaf) > 0 && toid < Enum.min(lessleaf)) ->
                             messageworker(Enum.min(lessleaf), "route", [msg, fromid, toid, hops + 1, id])

                          (length(largerleaf) <= 4 && length(largerleaf) > 0 && toid > Enum.max(largerleaf)) ->
                             messageworker(Enum.max(largerleaf), "route", [msg, fromid, toid, hops + 1, id])

                          ((length(lessleaf) == 0 && toid < id) || (length(largerleaf) == 0 && toid > id)) ->
                            if hops == -1 do
                              hops = 0
                            end
                             :global.whereis_name(:server) |> send({String.to_atom("routefinish"), [fromid, toid, hops]})

                          (toid > id) ->
                             messageworker(Enum.max(largerleaf), "route", [msg, fromid, toid, hops + 1, id])
                             :global.whereis_name(:server) |> send({String.to_atom("routenotinboth")})

                          (toid < id) ->
                            messageworker(Enum.min(lessleaf), "route", [msg, fromid, toid, hops + 1, id])
                            :global.whereis_name(:server) |> send({String.to_atom("routenotinboth")})

                          true -> IO.puts "Something went wrong in Route"
                      end
                    end
            end

        {:addrow, [rownum, newrow]} ->
          table = addrow(table, rownum, newrow, 3)

        {:addleaf, [allleaf]} ->
          reslist = addbuffer(allleaf, length(allleaf) - 1, id, largerleaf, lessleaf, log4, table)
          table = Enum.at(reslist, 0)
          lessleaf = Enum.at(reslist, 1)
          largerleaf = Enum.at(reslist, 2)
          printinfo(lessleaf, largerleaf, log4 - 1, table)
          numofback = getnumofback(lessleaf, length(lessleaf) - 1, numofback, id)
          numofback = getnumofback(largerleaf, length(largerleaf) - 1 , numofback, id)
          numofback = multiupdate(numofback, id, log4 - 1, table)
          table = multiupdatetable(log4 - 1, id, log4, table)

          {:updateme, [newnode]} ->
            reslist = addone(newnode, id, largerleaf, lessleaf, log4, table)
            table = Enum.at(reslist, 0)
            lessleaf = Enum.at(reslist, 1)
            largerleaf = Enum.at(reslist, 2)
            messageworkernoargs(newnode, "ack")

          {:ack} ->
            numofback = numofback - 1
            if numofback == 0 do
              :global.whereis_name(:server) |> send({"joinfinish"})
            end

          {:beginroute} ->
            ilist = Enum.to_list(0..(numrequests - 1))
            Enum.each ilist, fn(i) ->
               self() |> send({:clocktick})
               :timer.sleep(1000)
            end

          {:clocktick} ->
            toid = Enum.random(idspace)
            self() |> send({:route, ["route", id, toid, -1, id]})
      end
      listen(numnodes, numrequests, id, log4, table, numofback, lessleaf, largerleaf, idspace)
    end

    def multiupdate(numofback, id, i, table) do
      if i < 0 do
        numofback
      else
        numofback = multiupdate_j(numofback, id, i, 3, table)
      end
      multiupdate(numofback, id, i-1, table)
    end

    def multiupdate_j(numofback, id, i, j, table) do
      if j < 0 do
        numofback
      else
        idxval = Enum.at(Enum.at(table, i), j)
        if idxval != -1 do
          numofback = numofback + 1
          messageworker(getfromtable(table, i, j), "updateme", [id])
        end
      end
      multiupdate_j(numofback, id, i, j - 1, table)
    end

    def addrow(table, rownum, newrow, i) do
      if(i < 0)do
        table
      else
        idxval = Enum.at(Enum.at(table, rownum), i)
        if idxval == -1 do
          table = updatetable(table, rownum, i, Enum.at(newrow, i))
        end
        addrow(table, rownum, newrow, i-1)
      end
    end

    def addbuffer(all, lenall, id, largerleaf, lessleaf, log4, table) do
      if lenall < 0 do
        reslist = [table, lessleaf, largerleaf]
        reslist
      else
        s = Enum.at(all, lenall)
        if s > id && !Enum.member?(largerleaf,s) do
           if(length(largerleaf) < 4) do
              largerleaf = largerleaf ++ [s]
           else
              if(s < Enum.max(largerleaf)) do
               largerleaf = largerleaf -- [Enum.max(largerleaf)]
               largerleaf = largerleaf ++ [s]
              end
           end
        else
          if s < id && !Enum.member?(lessleaf,s) do
             if(length(lessleaf) < 4) do
               lessleaf = lessleaf ++ [s]
             else
               if(s > Enum.min(lessleaf)) do
                 lessleaf = lessleaf -- [Enum.min(lessleaf)]
                 lessleaf = lessleaf ++ [s]
               end
             end
          end
        end
        samePre = sameprefix(toBase4String(id, log4), toBase4String(s, log4))
        if(getfromtable(table, samePre, String.to_integer(String.at(toBase4String(s, log4), samePre))) == -1) do
          tabletemp = table
          table = updatetable(table, samePre, String.to_integer(String.at(toBase4String(s, log4), samePre)), s)
        end
        addbuffer(all, lenall - 1, id, largerleaf, lessleaf, log4, table)
      end
     end

   def addone(one, id, largerleaf, lessleaf, log4, table) do
     if (one > id && !Enum.member?(largerleaf,one)) do
           if (length(largerleaf) < 4) do
             largerleaf = largerleaf ++ [one]
           else
              if (one < Enum.max(largerleaf)) do
                 largerleaf = largerleaf -- [Enum.max(largerleaf)]
                 largerleaf = largerleaf ++ one
              end
           end
      else
           if (one < id && !Enum.member?(lessleaf,one)) do
              if (length(lessleaf) < 4) do
                 lessleaf = lessleaf ++ [one]
              else
                 if (one > Enum.min(lessleaf)) do
                   lessleaf = lessleaf -- [Enum.min(lessleaf)]
                   lessleaf = lessleaf ++ [one]
                 end
              end
            end
      end
     samePre = sameprefix(toBase4String(id, log4), toBase4String(one, log4))

     if(getfromtable(table, samePre, String.to_integer(String.at(toBase4String(one, log4), samePre))) == -1) do
       table = updatetable(table, samePre, String.to_integer(String.at(toBase4String(one, log4), samePre)), one)
     end
     reslist = [table, lessleaf, largerleaf]
     reslist
   end

    def toBase4String(raw, len) do
      str = Integer.to_string(raw,4)
      diff = len - String.length(str)
      if diff > 0 do
        str = createstr(str, 1, diff)
      end
      str
    end

    def createstr(str, j, diff) do
      if j > diff do
        str
      else
        str = "0" <> str
        createstr(str, j+1, diff)
      end
    end

    def sameprefix(str1, str2) do
      j = getjsameprefix(str1, str2, 0)
      j
    end

    def getjsameprefix(str1, str2, j) do
      if j < String.length(str1) && String.at(str1, j) == String.at(str2, j) do
        getjsameprefix(str1, str2, j+1)
      else
        j
      end
    end

    def printinfo(lessleaf, largerleaf, log4, table) do
      if log4 < 0 do
      else
        rowlist = Enum.at(table, log4 - 1)
        Enum.each rowlist, fn row ->
        end
      printinfo(lessleaf, largerleaf, log4 - 1, table)
      end
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

    def updatetable(table, i, j, value) do
      val = Enum.at(table, i)
      toreplace = value
      val = List.replace_at(val, j, toreplace)
      table = List.replace_at(table, i, val)
      table
    end

    def getfromtable(table, i, j) do
      val = Enum.at(Enum.at(table, i), j)
      val
    end

    def firstjointable(table, id, log4, s) do
      if s < 0 do
        table
      else
        jidx = String.to_integer(String.at(toBase4String(id, log4), s))
        table = updatetable(table, s, jidx, id)
        firstjointable(table, id, log4, s-1)
      end
    end

    def getnearest(list, lenlist, diff, nearest, reslist, toid) do
      if lenlist < 0 do
      reslist = [diff, nearest]
      reslist
      else
        if (abs(toid - Enum.at(list, lenlist)) < diff) do
          nearest = Enum.at(list, lenlist)
          diff = abs(toid - Enum.at(list, lenlist))
        end
        getnearest(list, lenlist - 1, diff, nearest, reslist, toid)
      end
    end

    def getnumofback(list, lenlist, numofback, id) do
      if lenlist < 0 do
        numofback
      else
        numofback = numofback + 1
        messageworker(Enum.at(list, lenlist), "updateme", [id])
        getnumofback(list, lenlist - 1, numofback, id)
      end
    end

    def multiupdatetable(lenlist, id, log4, table) do
      if lenlist < 0 do
        table
      else
        jidx = String.to_integer(String.at(toBase4String(id, log4), lenlist))
        table = updatetable(table, lenlist, jidx, id)
        multiupdatetable(lenlist - 1, id, log4, table)
      end
    end
  end
