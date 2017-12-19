defmodule Memcache do
  @doc """
  Retrieve a cached value or apply the given function caching and returning
  the result.
  user
  userid, name, password, followers, following, tweets, mentions_tweets

  tweet
  tweetid, timestamp, tweet, userid, original_opid_tweetid, retweets_list       isrequired? -> hashtags, mentions

  hastags
  hashtag, tweetid
  """

  def create_table(tablename) do
    table = String.to_atom(tablename)
    :ets.new(table, [:set, :protected, :named_table])
  end

  def insert(tablename, obj) do
    #args is an object
    table = String.to_atom(tablename)
    :ets.insert_new(table, obj)
  end

  def update(tablename, key, index, val) do
    table = String.to_atom(tablename)
    obj = getobj(tablename, key)
    if obj != nil do
      obj =  Tuple.delete_at(obj, index)
      obj =  Tuple.insert_at(obj, index, val)
    else
      #handle hashtags
      obj = {key, val}
    end
    :ets.insert(table, obj)
  end

  def get(tablename, key, index) do
    table = String.to_atom(tablename)
    res = :ets.lookup(table, key)
    emptylist = []
    if length(res) > 0 do
      elem(Enum.at(res, 0), index)
    else
      #handle empty username/password/name
      emptylist
    end
  end

  def getobj(tablename, key) do
    table = String.to_atom(tablename)
    res = :ets.lookup(table, key)
    emptylist = []
    if length(res) > 0 do
      Enum.at(res, 0)
    else
      nil
    end
  end

  def getwithfn(tablename, func) do
    #fun = :ets.fun2ms(fn {username, _, langs} when length(langs) > 2 -> username end)
    fun = :ets.fun2ms(func)
    table = String.to_atom(tablename)
    :ets.select(table, fun)
  end

  def delete(tablename, key) do
    table = String.to_atom(tablename)
    :ets.delete(table, key)
  end

  def deltable(tablename) do
    table = String.to_atom(tablename)
    :ets.delete(table)
  end

  def getuserslist() do
    #table users
    :ets.match(:users, {:"$1", :"_", :"_", :"_", :"_", :"_", :"_"})
  end

  def gettweetlists(tablename) do
    :ets.match(:tweet, {:"$1", :"_", :"_", :"_", :"_"})
  end

  def gettaggedtweets(hashtag) do
    res = :ets.lookup(:hashtag, hashtag)
    if length(res) > 0 do
      Enum.at(res, 0)
    end
  end

  def getetstable(tablename) do
    table = String.to_atom(tablename)
    IO.inspect :ets.tab2list(table)
  end

end
