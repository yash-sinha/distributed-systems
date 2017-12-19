defmodule User do
  def listen(me, numusers, mymentions, mytweets, followingtweets) do
    receive do
      {:userregistered, [id, interval]} ->
       pass()
       :timer.send_interval(interval, self(), {:tick})

      {:updatefeed, [my_mentions, my_tweets, following_tweets, reason]} ->
        updatereason = reason
        mlength = length(my_mentions)
        tlength = length(my_tweets)
        flength = length(following_tweets)

        if mlength > 0 || tlength > 0 || flength > 0 do

          if length(my_mentions) > 0 do
            mymentions = mymentions ++ my_mentions
            # updatereason = "mentioned in tweet"
          end

          if length(my_tweets) > 0 do
            mytweets = mytweets ++ my_tweets
            # updatereason = "self tweeted"
          end

          if length(following_tweets) > 0 do
            followingtweets = followingtweets ++ following_tweets
            # updatereason = "following tweeted"
          end

          formatted_mytweets = formattweets(mytweets, "\n\nUser: user#{me} update: #{updatereason} ------------------------------\nMy tweets (user#{me}):", "mytweets")
          str1 = formatted_mytweets <> "\n-----\nMy mentions(user#{me}): "
          formatted_mymentions = formattweets(mymentions, str1, "mymentions")
          str1 = formatted_mymentions <> "\n----\nMy followings(user#{me}): "
          formatted_followings = formattweets(followingtweets, str1, "followings")
          formatted_followings = formatted_followings <> "\n--------------------------------------------"
          IO.puts(formatted_followings)
        end

      {:retweet, [randomtweetuid, randomtweetid, randomtweetdesc]} ->
        retweet(me, randomtweetuid, randomtweetid, randomtweetdesc)

      {:query_callback, [query, result]} ->
        if length(result) > 0 do
          res = formattweets(result, "", "query")
          IO.puts "\nQuery by user#{me} -- result for query: #{query} --\n #{res}"
        else
          IO.puts "\nQuery by user#{me} -- Zero query result for query: #{query}!"
        end

      {:tick} ->
          rand_action = ["tweet", "retweet", "tweet", "retweet", "tweet", "tweet", "follow", "query", "query", "query"]
          act = Enum.random(rand_action)
          do_action(act, me, numusers)
    end
    listen(me, numusers, mymentions, mytweets, followingtweets)
  end

  def do_action(args, me, numusers) do
    cond do
      args == "tweet" -> send_tweet(me, numusers)
      args == "retweet" -> checkserverup(:getrandomtweet, [me])
      args == "follow" -> checkserverup(:addrandomfollow, [me])
      args == "query" -> do_random_query(me)
    end
  end

  def do_random_query(me) do
    queries = ["tweets_subscribed_to", "hashtag", "mymentions"]
    rand_query = Enum.random(queries)
    cond do

      rand_query == "hashtag" ->
        hashtags = ["dos", "twitter", "uf"]
        rand_hashtag = Enum.random(hashtags)
        checkserverup(:process_query, [rand_query, [me, rand_hashtag]])

      true ->
        checkserverup(:process_query, [rand_query, [me]])
    end
  end

  def retweet(me, randomtweetuid, randomtweetid, desc) do
    name = "user" <> "#{me}"
    checkserverup(:createretweet, [desc, randomtweetuid, randomtweetid, name])
  end

  def send_tweet(me, numusers) do
    words = ["Here ", "I ", "am ", "tweeting! "]
    words = Enum.shuffle(words)
    desc = Enum.join(words, " ")
    hashtags = ["", "",  "", "#dos", "#twitter", "#uf"]
    numhashtags = Enum.random(0..6)
    selected_hashtags = Enum.take_random(hashtags, numhashtags)

    max_mentions = 0..round(0.2 * numusers)
    num_mentions = Enum.random(max_mentions)
    user_list = Enum.to_list 1..numusers
    user_list = user_list -- [me]
    mention_list = Enum.take_random(user_list, num_mentions)

    desc = get_mentions_string(desc, mention_list)
    desc = get_hastags_string(desc, selected_hashtags)
    name = "user" <> "#{me}"
    desc = String.trim(desc)
    checkserverup(:createtweet, [desc, name])
  end

  def get_mentions_string(desc, mention_list) do
    if length(mention_list) < 1 do
      desc
    else
      user = "user" <> "#{Enum.at(mention_list, 0)}"
      desc = desc <> " @" <> "#{user}"
      mention_list = mention_list -- [Enum.at(mention_list, 0)]
      get_mentions_string(desc, mention_list)
    end
  end

  def get_hastags_string(desc, selected_hashtags) do
    if length(selected_hashtags) < 1 do
      desc
    else
      desc = desc <> " " <> Enum.at(selected_hashtags, 0)
      selected_hashtags = selected_hashtags -- [Enum.at(selected_hashtags, 0)]
      get_hastags_string(desc, selected_hashtags)
    end
  end

  def sendmessage(sendto, func, args) do
    rec_atom = String.to_atom(sendto)
    func_atom = String.to_atom(func)
    :global.whereis_name(rec_atom) |> send({func_atom, args})
  end

  def formattweets(tweetlist, tweetliststr, type) do
    if length(tweetlist) > 0 do
    tweet = Enum.at(tweetlist, 0)
    tweetlist = tweetlist -- [tweet]
    tweetstr = elem(tweet, 1) <> " ||| " <> elem(tweet, 2) <> " |||"
    case type do
      "mytweets" ->
        tweetstr = tweetstr <> " Number of retweets: " <> "#{length(elem(tweet, 5))}"
        if Enum.at(elem(tweet, 4), 0) !=  elem(tweet, 3) do
          tweetstr = tweetstr <> " retweet op: " <> "#{Enum.at(elem(tweet, 4), 0)}"
        end
      _ ->
        tweetstr = tweetstr <> " op: " <> "#{Enum.at(elem(tweet, 4), 0)}"
    end
    tweetliststr = Enum.join([tweetliststr, tweetstr], "\n")
    formattweets(tweetlist, tweetliststr, type)
  else
    tweetliststr
    end
  end

  def pass do

  end

  def checkserverup(call_atom, arglist) do
    if :global.whereis_name(:server) != :undefined do
      :global.whereis_name(:server) |> send({call_atom, arglist})
    else
      IO.puts "Server is down.. Retrying.."
    end
  end

end
