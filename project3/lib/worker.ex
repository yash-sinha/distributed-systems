defmodule WORKER do
    def listen(numnodes, numrequests, id, log4, table, numofback, lessleaf, largerleaf, idspace) do

  #     val myID = id;
  # var lessLeaf = new ArrayBuffer[Int]()
  # var largerLeaf = new ArrayBuffer[Int]()
  # var table = new Array[Array[Int]](log4)
  # var numOfBack: Int = 0
  # val IDSpace: Int = pow(4, log4).toInt

  # var i = 0
  # for (i <- 0 until log4)
  #   table(i) = Array(-1, -1, -1, -1)

      receive do
        {:firstjoin, [firstGroup]} ->
          IO.puts "firstjoin"
        {:beginroute} ->
          IO.puts "beginroute"
        {:route, [msg, fromID, toID, hops]} ->
          IO.puts "route"
        # _ -> "Invalid call in worker"
        {:addrow, [rownum, newrow]} ->
          table = addrow(table, rownum, newrow, 3) #TODO get table?
        {:addleaf, [allleaf]} ->
          # addBuffer(allLeaf) TODO
          printinfo(lessleaf, largerleaf, log4, table)
          Enum.each lessleaf,
            fn(x) ->
                numofback = numofback + 1
                messageworker(x, "updateme", [id])
            end

          Enum.each largerleaf,
            fn(x) ->
                numofback = numofback + 1
                messageworker(x, "updateme", [id])
            end

          numofback = multiupdate(numofback, id, log4 - 1, table)
          ilist = Enum.to_list(0..log4)
          Enum.each ilist, fn(i) ->
            jidx = String.to_integer(String.at(toBase4String(id, log4), i))
            val = Enum.at(table, i)
            toreplace = id
            val = List.replace_at(val, jidx, toreplace)
            table = List.replace_at(table, i, val)
          end

          {:updateme, [newnode, sender]} ->
            #addone(newnodeid) TODO
            messageworker(sender, "ack", [])

          {:ack} ->
            numofback = numofback - 1
            if numofback == 0 do
              :global.whereis_name(:server) |> send({"joinfinish"})
            end

          {:beginroute} ->
            ilist = Enum.to_list(1..numrequests)
            Enum.each ilist, fn(i) ->
               :global.whereis_name(self) |> send({:clocktick})
            end

          {:clocktick} ->
            :global.whereis_name(self) |> send({:route, [id, :random.uniform(idspace), -1]})
            :timer.sleep(1000)
            :global.whereis_name(self) |> send({:clocktick})
            #TODO where does this stop?
      end
      listen(numnodes, numrequests, id, log4, table, numofback, lessleaf, largerleaf, idspace)
    end

    def multiupdate(numofback, id, i, table) do
      if i < 0 do
        numofback
      else
        jlist = Enum.to_list(0..3)
        Enum.each jlist, fn(j) ->
          idxval = Enum.at(Enum.at(table, i), j)
          if idxval != -1 do
            numofback = numofback + 1
            messageworker(j, "updateme", [id])
          end
        end
      end
      multiupdate(numofback, id, i-1, table)
    end


    def addrow(table, rownum, newrow, i) do #i starts with 3 TODO
      if(i < 0)do
        IO.puts "Added row"
        table
      else
        idxval = Enum.at(Enum.at(table, rownum), i)
        if idxval == -1 do
          val = Enum.at(table, rownum)
          toreplace = Enum.at(newrow, i)
          val = List.replace_at(val, i, toreplace)
          table = List.replace_at(table, rownum, val)
        end
        addrow(table, rownum, newrow, i-1)
      end
    end

    def toBase4String(raw, length) do
      str = Integer.to_string(raw,4)
      diff = length - String.length(raw)
      if diff > 0 do
        str = createstr(str, 0, diff)
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
      if j < length str1 && String.at(str1, j) == String.at(str2, j) do
        j
      else
        getjsameprefix(str1, str2, j+1)
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
  end
