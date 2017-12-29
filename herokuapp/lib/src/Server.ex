defmodule Server do

  def printets(tablename) do
      IO.puts "------------------------------------------- " <> "Printing table: " <> tablename <> " -------------------------------------------"
      Memcache.getetstable(tablename)
  end

  def updatemyfeed(username) do
      mentiontweets = Memcache.get("user", username, 6)
      mytweets = Memcache.get("user", username, 5)
      tweetlist =  MapSet.union(MapSet.new(mytweets), MapSet.new(mentiontweets))
      followingtweets = Memcache.get("user", username, 4)
      tweetlist =  MapSet.union(tweetlist, MapSet.new(followingtweets))
      tweetlist = MapSet.to_list(tweetlist) |> Enum.sort |> Enum.reverse
      tweets = getquerytweets(tweetlist ,[])
      tweets
  end

  def process_query(query, args) do
        clientid = Enum.at(args, 0)
        key = clientid
        tweets = []
        case query do
            "tweets_subscribed_to" ->
              following_list = Memcache.get("user", key, 4)
              tweets = getusertweets(following_list, [])

            "hashtag" ->
              hashtag = Enum.at(args, 1)
              tweetlist = Memcache.get("hashtags", hashtag, 1)
              tweets = getquerytweets(tweetlist ,[])

            "mymentions" ->
              mention_list = Memcache.get("user", key, 6)
              tweets = getquerytweets(mention_list ,[])
        end
        tweets
  end

  def update(tablename, key, index, val) do
      Memcache.update(tablename, key, index, val)
  end

  def updatefollowers(tablename, key, val) do
      update_followers(val, key)
  end

  def createtweet(desc, uid) do
      tweetid = Memcache.nextid("tweet")
      hashtags = get_hashtags(desc)
      mentions = get_mentions(desc)
      update_hashtags(hashtags, tweetid)
      update_mentions(mentions, tweetid)
      add_to_user_tweets(uid, tweetid)
      time = DateTime.to_string(DateTime.utc_now)
      tweet = {tweetid, time, desc, uid, [uid, tweetid], []}
      res = Memcache.insert("tweet", tweet) #tweetid, timestamp, desc, uid, hastags, mentions
      [mentions, time, tweetid]
  end

  def createuser(username, password) do
    res = Memcache.insert("user", {username, username, password, [], [], [], []}) #uid, uname, pass, followers, following
    if res == true do
      IO.puts "User with userid: " <> "#{username}" <> " created"
    else
      IO.puts "User exists!"
    end
    res
  end

  def createretweet(desc, randomtweetuid, randomtweetid, uid) do
    tweetid = Memcache.nextid("tweet")
    add_to_user_tweets(uid, tweetid)
    update_original_tweet(randomtweetuid, randomtweetid, tweetid)
    time = DateTime.to_string(DateTime.utc_now)
    tweet = {tweetid, time, desc, uid, [randomtweetuid, randomtweetid], []}
    res = Memcache.insert("tweet", tweet) #tweetid, timestamp, desc, uid, hastags, mentions
    time
  end

  def update_original_tweet(randomtweetuid, randomtweetid, retweet_id) do
    IO.inspect randomtweetid
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
    if Memcache.get("user", tofollow, 0) == [] do
      res = "Invalid user"
    else
      if follower == tofollow do
        res = "Can't follow yourself"
      else
        following_list = Memcache.get("user", follower, 4)
        if Enum.member?(following_list, tofollow) == true do
          res = "Already followed"
        else
          following_list = checkandappendtolist(following_list, tofollow)
          Memcache.update("user", follower, 4, following_list)
          follower_list_of_tofollow = Memcache.get("user", tofollow, 3)
          follower_list_of_tofollow = checkandappendtolist(follower_list_of_tofollow, follower)
          Memcache.update("user", tofollow, 3, follower_list_of_tofollow)
          following_list_tofollow = Memcache.get("user", tofollow, 4)
          res = "Followed " <> "#{tofollow}"
        end
      end
    end
    res
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
