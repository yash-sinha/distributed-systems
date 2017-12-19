defmodule TwitterphxWeb.PageController do
  use TwitterphxWeb, :controller

  def index(conn, _params) do
    render conn, "index.html"
  end

  def home(conn, %{"username" => username}) do
    user = Memcache.get("user", username, 0)
    if user != [] do
      render conn, "home.html", username: username
    else
      render conn, "index.html"
    end
  end
end
