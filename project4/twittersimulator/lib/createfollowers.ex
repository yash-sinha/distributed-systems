defmodule Followers do
  def listen(user_list, numusers, c, x) do
    receive do
      {:createfollowers} ->
        key = x #{}"user" <> "#{x}"
        IO.puts "#{c}" <> " " <> "#{x}"
        nums = (c/x) * numusers
        num = round(nums)
        foll_list = Enum.take_random(user_list -- [key], num)
        # foll_list = create_foll_list(foll_list_ids, [])
        IO.puts "x: " <> "#{x}" <> " numusers: " <> "#{numusers}" <> " c: " <> "#{c}" <> " followers: " <> "#{num}"
        checkserverup(:updatefollowers, ["user", key, foll_list])
      end
      listen(user_list, numusers, c, x)
    end

    # def add_followers(numusers) do
    #   user_range = 1..numusers
    #   IO.puts zipf_constant(0, numusers)
    #   c = 1/zipf_constant(0, numusers)
    #   user_list = get_user_list(numusers, [])
    #   Enum.each(user_range, fn(x) ->
    #     nums = (c/x) * numusers
    #     num = round(nums)
    #     IO.puts "x: " <> "#{x}" <> " numusers: " <> "#{numusers}" <> " c: " <> "#{c}" <> " followers: " <> "#{num}"
    #     key = "user" <> "#{x}"
    #
    #   end)
    # end
    def create_foll_list(foll_list_ids, foll_list) do
      if length(foll_list_ids) > 0 do
        id = Enum.at(foll_list, 0)
        user = "user" <> "#{id}"
        foll_list = foll_list ++ [user]
        create_foll_list(foll_list_ids, foll_list)
      else
        foll_list
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
