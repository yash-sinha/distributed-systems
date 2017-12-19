defmodule Server do
  def listen(processpid, numuserscreated, numtweets, starttime, numtotalactions) do
    receive do
      {:createtables} ->
        Memcache.create_table("user")
        Memcache.create_table("tweet")
        Memcache.create_table("hashtags")
        # IO.inspect :ets.info(:user)

      {:createuser} ->
        username = "user" <> "#{numuserscreated}"
        res = Memcache.insert("user", {username, username, username, [], [], [], []}) #uid, uname, pass, followers, following
        if res == true do
          numuserscreated = numuserscreated + 1
          IO.puts "User with userid: " <> "#{username}" <> " created"
        else
          IO.puts "User exists!"
        end


        {:createretweet, [desc, randomtweetuid, randomtweetid, uid]} ->
          add_to_user_tweets(uid, numtweets)
          update_original_tweet(randomtweetuid, randomtweetid, numtweets)
          tweet = {numtweets, DateTime.to_string(DateTime.utc_now), desc, uid, [randomtweetuid, randomtweetid], []}
          res = Memcache.insert("tweet", tweet) #tweetid, timestamp, desc, uid, hastags, mentions
          notify_alivefollowers_and_mentions(uid, tweet, [])
          # user = "user" <> "#{uid}"
          user_atom = String.to_atom(uid)
          checkclientalive(user_atom, :updatefeed, [[], [tweet], [], "created tweet"])
          numtweets = numtweets + 1
          numtotalactions = numtotalactions + 1

        {:createtweet, [desc, uid]} ->
          hashtags = get_hashtags(desc)
          mentions = get_mentions(desc)
          update_hashtags(hashtags, numtweets)
          update_mentions(mentions, numtweets)
          add_to_user_tweets(uid, numtweets)
          tweet = {numtweets, DateTime.to_string(DateTime.utc_now), desc, uid, [uid, numtweets], []}
          res = Memcache.insert("tweet", tweet) #tweetid, timestamp, desc, uid, hastags, mentions
          notify_alivefollowers_and_mentions(uid, tweet, mentions)
          # user = "user" <> "#{uid}"
          user_atom = String.to_atom(uid)
          # IO.puts "created tweet"
          checkclientalive(user_atom, :updatefeed, [[], [tweet], [], "created tweet"])
          numtweets = numtweets + 1
          numtotalactions = numtotalactions + 1

        {:getrandomtweet, [clientid]} ->
          key = "user" <> "#{clientid}"
          user_tweet_list = Memcache.get("user", key, 5)

          if numtweets > 1  do
            tweetrange = Enum.to_list 1..(numtweets - 1)
            tweetrange = tweetrange -- user_tweet_list
            if length(tweetrange) > 0 do
              randomtweetid = Enum.random(tweetrange)
              randomtweetuid = Memcache.get("tweet", randomtweetid, 3)
              randomtweetdesc = Memcache.get("tweet", randomtweetid, 2)
              user_atom = String.to_atom(key)
              checkclientalive(user_atom, :retweet, [randomtweetuid, randomtweetid, randomtweetdesc])
            end
          end


        {:update, [tablename, key, index, val]} ->
          Memcache.update(tablename, key, index, val)

        {:updatefollowers, [tablename, key, val]} ->
          update_followers(val, key)

        {:addrandomfollow, [clientid]} ->
          key = "user" <> "#{clientid}"
          following_list = Memcache.get("user", key, 4)
          user_range = Enum.to_list 1..(numuserscreated - 1)
          users = Enum.map(user_range, fn(x) -> "user" <> "#{x}" end)
          users = users -- [following_list]
          users = users -- [key]
          tofollow = Enum.random(users)
          follow(key, tofollow)
          numtotalactions = numtotalactions + 1

        {:process_query, [query, args]} ->
            clientid = Enum.at(args, 0)
            key = "user" <> "#{clientid}"
            user_atom = String.to_atom(key)
            tweets = []
            # IO.puts "queryyash: " <> "#{query}"
            case query do
                "tweets_subscribed_to" ->
                  #tweets_subscribed_to -- args = clientid
                  following_list = Memcache.get("user", key, 4)
                  tweets = getusertweets(following_list, [])

                "hashtag" ->
                  #hashtags -- args == clientid, random hashtag
                  hashtag = Enum.at(args, 1)
                  tweetlist = Memcache.get("hashtags", hashtag, 1)
                  tweets = getquerytweets(tweetlist ,[])
                  query = query <> " " <> hashtag

                "mymentions" ->
                  #mymentions -- args = clientid
                  mention_list = Memcache.get("user", key, 6)
                  tweets = getquerytweets(mention_list ,[])
            end
            checkclientalive(user_atom, :query_callback, [query, tweets])
            numtotalactions = numtotalactions + 1



          {:printets, [tablename]} ->
            IO.puts "------------------------------------------- " <> "Printing table: " <> tablename <> " -------------------------------------------"
            Memcache.getetstable(tablename)

          {:updatemyfeed, [username]} ->
            user_atom = String.to_atom(username)
            mention_list = Memcache.get("user", username, 6)
            my_mentions = getquerytweets(mention_list ,[])
            usertweets = Memcache.get("user", username, 5)
            my_tweets = getusertweets(usertweets, [])
            following_list = Memcache.get("user", username, 4)
            following_tweets = getusertweets(following_list, [])
            checkclientalive(user_atom, :updatefeed, [my_mentions, my_tweets, following_tweets, "initial feed"])

            {:updatesimulationstarttime, [time]} ->
              starttime = time
          after
            2_00 ->
              if starttime != 0 do
                current_time = :os.system_time(:millisecond)
                time_elapsed = current_time - starttime
                tweetrate = round(numtweets*1000/time_elapsed) #persecond
                randactionsrate = round(numtotalactions*1000/time_elapsed)
                IO.puts "Time elapsed: #{time_elapsed}, Num users: #{numuserscreated - 1}, Num tweets: #{numtweets - 1}, Tweet rate: #{tweetrate} per second, Num random actions/second = #{randactionsrate}"
              end

    end
    listen(processpid, numuserscreated, numtweets, starttime, numtotalactions)
  end

  def update_original_tweet(randomtweetuid, randomtweetid, retweet_id) do
    retweet_list = Memcache.get("tweet", randomtweetid, 5)
    retweet_list  = retweet_list ++ [retweet_id]
    Memcache.update("tweet", randomtweetid, 5, retweet_list)
  end


  def notify_alivefollowers_and_mentions(uid, usertweet, mentions) do
    emptylist = []
    follower_list = Memcache.get("user", uid, 3)
    if length(follower_list) > 0 do
      notifyfollowersormentions(follower_list, [emptylist, emptylist, [usertweet], "following tweeted"])
    end

    if length(mentions) > 0 do
      notifyfollowersormentions(mentions, [[usertweet], emptylist, emptylist, "mentioned in tweet"])
    end
  end

  def notifyfollowersormentions(userlist, args) do
    #args = my_mentions, my_tweets, following_tweets
    if length(userlist) > 0 do
      user = Enum.at(userlist, 0)
      userlist = userlist -- [user]
      user_atom = String.to_atom(user)
      checkclientalive(user_atom, :updatefeed, args)
      notifyfollowersormentions(userlist, args)
    end
  end

  def getusertweets(userlist, tweets) do
    if length(userlist) > 0 do
      user = Enum.at(userlist, 0)
      userlist = userlist -- [user]
      usertweets = Memcache.get("user", user, 5)
      tweets = tweets ++ getquerytweets(usertweets, [])
      getquerytweets(userlist ,tweets)
    else
      tweets
    end
  end

  def getquerytweets(tweetlist ,tweets) do
    if length(tweetlist) > 0 do
      tweet = Enum.at(tweetlist, 0)
      tweetlist = tweetlist -- [tweet]
      tweetobj = Memcache.getobj("tweet", tweet)
      if tweetobj != nil do
        tweets = tweets ++ [tweetobj]
      end
      getquerytweets(tweetlist ,tweets)
    else
      tweets
    end
  end

  def update_followers(val, me) do
    if length(val) > 0 do
      follower = Enum.at(val, 0)
      follow(follower, me)
      val = val -- [follower]
      update_followers(val, me)
    end
  end

  def follow(follower, tofollow) do
    following_list = Memcache.get("user", follower, 4)
    following_list = checkandappendtolist(following_list, tofollow)
    Memcache.update("user", follower, 4, following_list)

    follower_list_of_tofollow = Memcache.get("user", tofollow, 3)
    follower_list_of_tofollow = checkandappendtolist(follower_list_of_tofollow, follower)
    Memcache.update("user", tofollow, 3, follower_list_of_tofollow)

    following_list_tofollow = Memcache.get("user", tofollow, 4)
  end

  def add_to_user_tweets(uid, tweetid) do
    tweetlist = Memcache.get("user", uid, 5)
    tweetlist = checkandappendtolist(tweetlist, tweetid)
    Memcache.update("user", uid, 5, tweetlist)
  end

  def update_hashtags(hashtags, tweetid) do
    if length(hashtags) >= 1 do
      tag = Enum.at(hashtags, 0)
      hashtags = hashtags -- [tag]
      entry = Memcache.getobj("hashtags", tag)
      tweetlist = []
      if entry != nil do
        tweetlist = Memcache.get("hashtags", tag, 1)
      end
      tweetlist = checkandappendtolist(tweetlist, tweetid)
      Memcache.update("hashtags", tag, 1, tweetlist)
      update_hashtags(hashtags, tweetid)
    end
  end

  def update_mentions(mentions, tweetid) do
    if length(mentions) >= 1 do
      m = Enum.at(mentions, 0)
      mentions = mentions -- [m]
      mentionlist = Memcache.get("user", m, 6)
      mentionlist = checkandappendtolist(mentionlist, tweetid)
      user_atom = String.to_atom(m)

      Memcache.update("user", m, 6, mentionlist)
      update_mentions(mentions, tweetid)
    end
  end

  def get_hashtags(desc) do
    Regex.scan(~r/\S*#(?<tag>:\[[^\]]|[a-zA-Z0-9]+)/, desc, capture: :all_names) |> List.flatten
  end

  def get_mentions(desc) do
    Regex.scan(~r/\S*@(?<mention>:\[[^\]]|[a-zA-Z0-9]+)/, desc, capture: :all_names) |> List.flatten
  end

  def checkandappendtolist(list, item) do
    if Enum.member?(list, item) == false do
      list = list ++ [item]
    end
    list
  end

  def checkclientalive(user_atom, call_atom, argslist) do
    if :global.whereis_name(user_atom) != :undefined do
      :global.whereis_name(user_atom) |> send({call_atom, argslist})
    end
  end

end
