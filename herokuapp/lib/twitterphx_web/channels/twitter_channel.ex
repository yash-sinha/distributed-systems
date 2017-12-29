defmodule TwitterphxWeb.TwitterChannel do
    use Phoenix.Channel

    def join("twitter", _payload, socket) do
      {:ok, socket}
    end

    def handle_in("register_account", payload, socket) do
        username = payload["username"]
        password = payload["password"]
        res = Server.createuser(username, password)
        if res == true do
          Server.update("socketmaps", username, 1, socket)
        end
        push socket, "signupres", %{res: res, user: username}
        {:noreply, socket}
    end

    def handle_in("signin", payload, socket) do
        username = payload["username"]
        password = payload["password"]
        current_time = DateTime.utc_now()
        login_pwd = if Memcache.get("user", username, 2) != [] do
            Memcache.get("user", username, 2)
        else
            ""
        end

        IO.inspect login_pwd
        IO.inspect password
        if login_pwd != "" && login_pwd == password do
            Server.update("socketmaps", username, 1, socket)
            push socket, "signin", %{status: "Logged in"}
        else
            IO.puts "failure"
            push socket, "signin", %{status: "Login failure. Please check username/password."}
        end
        {:noreply, socket}
    end

    def handle_in("updatemyfeed", payload, socket) do
      username = payload["username"]
      tweets = Server.updatemyfeed(username)
      tweetjson = tweetjson(tweets, [])
      # IO.inspect tweetjson
      push socket, "updatefeed", %{tweets: tweetjson}
      {:noreply, socket}
    end

    def handle_in("tweet", payload, socket) do
      username = payload["username"]
      desc = payload["desc"]
      res = Server.createtweet(desc, username)
      mentions = Enum.at(res, 0)
      time = Enum.at(res, 1)
      tweetid = Enum.at(res, 2)
      payload = %{time: time, tweeter: username, tweetText: desc, isRetweet: false, org: nil, tweetID: tweetid}
      push socket, "gettweet", payload
      sendToFollowers(username, payload, mentions)
      {:noreply, socket}
  end

    def handle_in("retweet", payload, socket) do
      username = payload["username"]
      desc = payload["tweet"]
      # desc = "RT " <> desc
      org_user = payload["org"]
      tweetid = payload["tweetID"]
      tweetid = String.to_integer(tweetid)
      time = Server.createretweet(desc, org_user, tweetid, username)
      mentions = []
      payload = %{time: time, tweeter: username, tweetText: desc, isRetweet: true, org: org_user, tweetID: tweetid}
      push socket, "gettweet", payload
      sendToFollowers(username, payload, mentions)
      {:noreply, socket}
    end

    def handle_in("follow", payload, socket) do
      tofollow = payload["tofollow"]
      follower = payload["me"]
      res = Server.follow(follower, tofollow)
      push socket, "followres", %{status: res}
      {:noreply, socket}
    end

    def handle_in("getmentions", payload, socket) do
      username = payload["username"]
      tweets = Server.process_query("mymentions", [username])
      tweetjson = tweetjson(tweets, [])
      # IO.inspect tweetjson
      push socket, "getmentions", %{tweets: tweetjson}
      {:noreply, socket}
    end

    def handle_in("gethashtag", payload, socket) do
        hashtag = payload["hashtag"]
        IO.inspect payload
        tweets = Server.process_query("hashtag", ["", hashtag])
        tweetjson = tweetjson(tweets, [])
        # IO.inspect tweetjson
        push socket, "gethashtag", %{tweets: tweetjson}
        {:noreply, socket}
    end

    def handle_in("update_socket", payload, socket) do
        username = payload["username"]
        Server.update("socketmaps", username, 1, socket)
        {:noreply, socket}
    end

    def handle_in("remove_socket", payload, socket) do
      username = payload["username"]
      Server.update("socketmaps", username, 1, nil)
      {:noreply, socket}
    end

    def sendToFollowers(uid, usertweet, mentions) do
      emptylist = []
      follower_list = Memcache.get("user", uid, 3)
      IO.inspect follower_list
      # => [1, 4, 5]
      follow_plus_mentions =  MapSet.union(MapSet.new(follower_list), MapSet.new(mentions))
      follow_plus_mentions = MapSet.to_list(follow_plus_mentions)
      if length(follow_plus_mentions) > 0 do
        notifyfollowersormentions(follow_plus_mentions, usertweet)
      end
    end

    def notifyfollowersormentions(userlist, args) do
      #args = my_mentions, my_tweets, following_tweets
      if length(userlist) > 0 do
        user = Enum.at(userlist, 0)
        userlist = userlist -- [user]
        socket =  Memcache.get("socketmaps", user, 1)
        if socket != nil do
          push socket, "gettweet", args
        end
        notifyfollowersormentions(userlist, args)
      end
    end

    def isretweet(tweetid) do
      tweet_opid_origid = Memcache.get("tweet", tweetid, 4)
      origid = Enum.at(tweet_opid_origid, 1)
      if origid == tweetid do
        false
      else
        true
      end
    end

    def tweetjson(tweets, res) do
      if length(tweets) > 0 do
        tweet = Enum.at(tweets, 0)
        tweets = tweets -- [tweet]
        tweetid = elem(tweet, 0)
        username = elem(tweet, 3)
        datetime = elem(tweet, 1)
        desc = elem(tweet, 2)
        isRetweet = isretweet(tweetid)
        if isRetweet == false do
          res = List.insert_at(res, 0, %{tweetID: tweetid, tweeter: username, time: datetime, tweetText: desc, isRetweet: false, org: nil})
       else
         tweet_opid_origid = Memcache.get("tweet", tweetid, 4)
         org = Enum.at(tweet_opid_origid, 0)
         res = List.insert_at(res, 0 , %{tweetID: tweetid,tweeter: username, time: datetime, tweetText: desc, isRetweet: true, org: org})
       end
       tweetjson(tweets, res)
     else
       res
     end
    end

    def checkclientonline(username) do
      socket = Memcache.get("socketmaps", username, 1)
      if(socket == nil) do
        false
      else
        true
      end
    end

  end
