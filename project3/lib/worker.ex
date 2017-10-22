defmodule WORKER do
    def listen(numnodes, numrequests, id, log4, table, numofback, lessleaf, largerleaf, idspace) do
      receive do
        {:firstjoin, [firstgroup, sender]} ->
          IO.puts "firstjoin"
          firstgroup = firstgroup -- [id]
          table = addbuffer(firstgroup, length(firstgroup) - 1, id, largerleaf, lessleaf, log4, table)
          IO.puts "Done add buffer"
          table = firstjointable(table, id, log4, log4 - 1)

          IO.inspect(table)
          :global.whereis_name(:server) |> send({:joinfinish})
          # messageworkernoargs(sender, "joinfinish")

        {:route, [msg, fromid, toid, hops]} ->
          IO.puts "route"
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
                              diff = idspace + 10
                              nearest = -1
                              if(toid < id) do
                                #Check if this works if lessleaf else make it as list
                                reslist = getnearest(lessleaf, length(lessleaf) - 1, diff, nearest, [], toid)
                                diff = Enum.at(reslist, 0)
                                nearest = Enum.at(reslist, 1)

                              else
                                reslist = getnearest(largerleaf, length(largerleaf) - 1, diff, nearest, [], toid)
                                diff = Enum.at(reslist, 0)
                                nearest = Enum.at(reslist, 1)
                              end

                             if(abs(toid - id) > diff) do
                                messageworker(nearest, "route", [msg, fromid, toid, hops + 1])
                             else
                                allleaf = [id] ++ lessleaf ++ largerleaf
                                messageworker(toid, "addleaf", [allleaf])
                             end

                       (length(lessleaf) < 4 && length(lessleaf) > 0 && toid < Enum.min(lessleaf)) ->
                             messageworker(Enum.min(lessleaf), "route", [msg, fromid, toid, hops+1])

                       (length(largerleaf) < 4 && length(largerleaf) > 0 && toid > Enum.max(largerleaf)) ->
                             messageworker(Enum.max(largerleaf), "route", [msg,fromid, toid, hops+1])

                       ((length(lessleaf) == 0 && toid < id) || (length(largerleaf) == 0 && toid > id)) ->
                             allleaf = [id] ++ lessleaf ++ largerleaf
                             messageworker(toid, "addleaf", [allleaf])

                       getfromtable(table, samePre, String.to_integer(String.at(toBase4String(toid, log4), samePre)) != -1) ->
                             value = getfromtable(table, samePre, String.to_integer(String.at(toBase4String(toid, log4), samePre)))
                             messageworker(value, "route", [msg, fromid, toid, hops + 1])

                       (toid > id) ->
                             messageworker(Enum.max(largerleaf), "route", [msg,fromid, toid, hops+1])
                             :global.whereis_name(:server) |> send({String.to_atom("notinboth")})

                       (toid < id) ->
                             messageworker(Enum.min(lessleaf), "route", [msg,fromid, toid, hops+1])
                             :global.whereis_name(:server) |> send({String.to_atom("notinboth")})

                       true ->  IO.puts "Something went wrong in Route!"

                    end

              (msg == "route") ->
                    if(id == toid) do
                      :global.whereis_name(:server) |> send({String.to_atom("routefinish"), [fromid, toid, hops + 1]})
                    else
                      samePre = sameprefix(toBase4String(id, log4), toBase4String(toid, log4))

                      cond do
                         ((length(lessleaf) > 0 && toid >= Enum.min(lessleaf) && toid < id) ||
                            (length(largerleaf) > 0 && toid <= Enum.max(largerleaf) && toid > id)) ->

                            diff = idspace + 10
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
                              messageworker(nearest, "route", [msg, fromid, toid, hops + 1])
                            else
                              :global.whereis_name(:server) |> send({String.to_atom("routefinish"), [fromid, toid, hops + 1]})
                            end


                          (length(lessleaf) < 4 && length(lessleaf) > 0 && toid < Enum.min(lessleaf)) ->
                             messageworker(Enum.min(lessleaf), "route", [msg, fromid, toid, hops + 1])

                          (length(largerleaf) < 4 && length(largerleaf) > 0 && toid > Enum.max(largerleaf)) ->
                             messageworker(Enum.max(largerleaf), "route", [msg, fromid, toid, hops + 1])

                          ((length(lessleaf) == 0 && toid < id) || (length(largerleaf) == 0 && toid > id)) ->
                             :global.whereis_name(:server) |> send({String.to_atom("routefinish"), [fromid, toid, hops + 1]})

                          getfromtable(table, samePre, String.to_integer(String.at(toBase4String(id, log4), samePre))) != -1 ->
                             messageworker(getfromtable(table, samePre, String.to_integer(String.at(toBase4String(id, log4), samePre))), "route", [msg, fromid, toid, hops + 1])

                          (toid > id) ->
                             messageworker(Enum.max(largerleaf), "route", [msg, fromid, toid, hops + 1])
                             :global.whereis_name(:server) |> send({String.to_atom("routenotinboth")})

                          (toid < id) ->
                            messageworker(Enum.min(lessleaf), "route", [msg, fromid, toid, hops + 1])
                            :global.whereis_name(:server) |> send({String.to_atom("routenotinboth")})

                          true -> IO.puts "Something went wrong in Route"
                      end
                    end
            end

        {:addrow, [rownum, newrow]} ->
          table = addrow(table, rownum, newrow, 3)

        {:addleaf, [allleaf]} ->
          table = addbuffer(allleaf, length(allleaf) - 1, id, largerleaf, lessleaf, log4, table)
          printinfo(lessleaf, largerleaf, log4 - 1, table)
          numofback = getnumofback(lessleaf, length(lessleaf) - 1, numofback, id)
          numofback = getnumofback(largerleaf, length(largerleaf) - 1 , numofback, id)
          numofback = multiupdate(numofback, id, log4 - 1, table)
          table = multiupdatetable(log4 - 1, id, log4, table)

          {:updateme, [newnode]} ->
            addone(newnode, id, largerleaf, lessleaf, log4, table)
            messageworkernoargs(newnode, "ack")

          {:ack} ->
            numofback = numofback - 1
            if numofback == 0 do
              :global.whereis_name(:server) |> send({"joinfinish"})
            end

          {:beginroute} ->
            ilist = Enum.to_list(1..numrequests)
            Enum.each ilist, fn(i) ->
               self() |> send({:clocktick})
            end

          {:clocktick} ->
            self() |> send({:route, [id, :random.uniform(idspace), -1]})
            :timer.sleep(1000)
            self() |> send({:clocktick})
            #TODO where does this stop?
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

    def addrow(table, rownum, newrow, i) do #i starts with 3 TODO
      if(i < 0)do
        IO.puts "Added row"
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
        IO.puts "add buffer done"
        table
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
       #  IO.puts "alive"
        samePre = sameprefix(toBase4String(id, log4), toBase4String(s, log4))
       #  IO.puts "alive1"
       IO.puts "id: " <> "#{id}" <>" log4: " <> "#{log4}" <> " tobase: " <> toBase4String(id, log4) <>" samepre: " <> "#{samePre}" <> " tobase id log4: " <> toBase4String(id, log4) <> " tobase s log 4: " <> toBase4String(s, log4)
       IO.puts " String at: " <> String.at(toBase4String(id, log4), samePre)
       # IO.inspect table
        if(getfromtable(table, samePre, String.to_integer(String.at(toBase4String(id, log4), samePre))) != -1) do
         #  IO.puts "alive 1"
          table = updatetable(table, samePre, String.to_integer(String.at(toBase4String(id, log4), samePre)), s)
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
     #check routing table
     samePre = sameprefix(toBase4String(id, log4), toBase4String(one, log4))

     if(getfromtable(table, samePre, String.to_integer(String.at(toBase4String(id, log4), samePre))) == -1) do
       table = updatetable(table, samePre, String.to_integer(String.at(toBase4String(id, log4), samePre)), one)
     end
   end

    def toBase4String(raw, len) do
      str = Integer.to_string(raw,4)
      # IO.puts "str raw: " <> str
      diff = len - String.length(str)
      # IO.puts "diff: " <> "#{diff}"
      if diff > 0 do
        str = createstr(str, 0, diff)
      end
      # IO.puts "createstr: " <> str
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
      j = getjsameprefix(str1, str2, -1)
      j
    end

    def getjsameprefix(str1, str2, j) do
      # IO.puts "str1: " <> str1 <> " str2: " <> str2 <> " j: " <> "#{j}"
      if j < String.length(str1) && String.at(str1, j) == String.at(str2, j) do
        getjsameprefix(str1, str2, j+1)
      else
        j
      end
    end

    def printinfo(lessleaf, largerleaf, log4, table) do
      if log4 < 0 do
        IO.puts "Less Leaf: "  <> "#{lessleaf}"
        IO.puts "Larger leaf: " <> "#{largerleaf}"
      else
        rowlist = Enum.at(table, log4 - 1)
        Enum.each rowlist, fn row ->
          IO.inspect row
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

    # def forloop(from, to, func, args, toupdate) do
    #   if to < 0 do
    #     toupdate
    #   else
    #
    #     forloop(from, to - 1, func, args, toupdate)
    #   end
    # end

    def firstjointable(table, id, log4, s) do
      if s < 0 do
        table
      else
        jidx = String.to_integer(String.at(toBase4String(id, log4), s))
        IO.puts "jidx: " <> "#{jidx}"
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
          nearest = lenlist
          diff = abs(toid - lenlist)
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
