defmodule ModelT do
  def listen(numusers, flag_preprocess, active_users) do
    receive do
        {:startsimulation} ->
            create_users_and_followers(numusers)
            fraction = 0.5 #this fraction of users will be live
            starttime = :os.system_time(:millisecond)
            checkserverup(:updatesimulationstarttime, [starttime])
            :global.whereis_name(:server) |> send({:updatesimulationstarttime, [starttime]})
            active_users = simulate_connections(numusers, fraction, flag_preprocess, active_users)
            flag_preprocess = 1
          after
            #disconnect and connect new users
            20_000 ->
              fraction = 0.5 #fraction of active
              active_users = simulate_connections(numusers, fraction, flag_preprocess, active_users)

    end
    listen(numusers, flag_preprocess, active_users)
  end

  def simulate_connections(numusers, fraction, flag_preprocess, active_users) do
    if flag_preprocess == 1 do
      numactive = length(active_users)
      killallactiveusers(active_users, numactive)
    end
    numactive = round(numusers * fraction)
    userlist = 1..numusers
    active_users = Enum.take_random(userlist, numactive)
    create_workers(active_users, numusers) #activeusers created
    active_users
  end

  def killallactiveusers(activeusers, n) do
    if n > 0 do
      my_id = Enum.at(activeusers, n - 1)
      name = "user" <> "#{my_id}"
      worker = String.to_atom(name)
      :global.whereis_name(worker) |> Process.exit(:kill)
      killallactiveusers(activeusers, n - 1)
    end

  end

  def create_users_and_followers(n) do
    Enum.each(1..n, fn(_)->
      checkserverup(:createuser, [])
    end)

    add_followers(n)
  end

  def printets(tablename) do
    checkserverup(:printets, [tablename])
  end

  def get_user_list(numusers, ulist) do
    if(numusers == 0) do
      ulist
    else
      user = "user" <> "#{numusers}"
      ulist = ulist ++ [user]
      get_user_list(numusers - 1, ulist)
    end
  end

  def zipf_constant(sum, numusers) do
    if(numusers > 0) do
      sum = sum + (1/numusers)
      zipf_constant(sum, numusers-1)
    else
      sum
    end
  end

  def add_followers(numusers) do
    user_range = 1..numusers
    IO.puts zipf_constant(0, numusers)
    c = 1/zipf_constant(0, numusers)
    IO.puts "Getting user list"
    user_list = get_user_list(numusers, [])
    Enum.each(user_range, fn(x) ->
      nums = (c/x) * numusers
      num = round(nums)
      IO.puts "x: " <> "#{x}" <> " numusers: " <> "#{numusers}" <> " c: " <> "#{c}" <> " followers: " <> "#{num}"
      key = "user" <> "#{x}"
      foll_list = Enum.take_random(user_list -- [key], num)
      checkserverup(:updatefollowers, ["user", key, foll_list])
    end)
  end

  def create_workers(activeusers, numusers) do
    if length(activeusers) > 0 do
      my_id = Enum.at(activeusers, 0)
      activeusers = activeusers -- [my_id]
      pid = spawn(User, :listen, [my_id, numusers, [], [], []])
      name = "user" <> "#{my_id}"
      worker = String.to_atom(name)
      :global.register_name(worker, pid)
      checkserverup(:updatemyfeed, [name])
      interval = round(100 + (my_id * 100))
      checkclientalive(worker, :userregistered, [numusers, interval])
      create_workers(activeusers, numusers)
    end
  end

  def checkclientalive(user_atom, call_atom, argslist) do
    if :global.whereis_name(user_atom) != :undefined do
      if length(argslist) > 0 do
        :global.whereis_name(user_atom) |> send({call_atom, argslist})
      else
        :global.whereis_name(user_atom) |> send({call_atom})
      end
    end
  end

  def checkserverup(call_atom, arglist) do
    if :global.whereis_name(:server) != :undefined do
      if length(arglist) > 0 do
        :global.whereis_name(:server) |> send({call_atom, arglist})
      else
        :global.whereis_name(:server) |> send({call_atom})
      end
    else
      IO.puts "Server is down.. Retrying.."
    end
  end
end
