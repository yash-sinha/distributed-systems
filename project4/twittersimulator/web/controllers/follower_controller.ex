defmodule App.FollowerController do
  use App.Web, :controller

  alias App.Follower

  plug App.LoginRequired when action in [:create, :delete]
  plug App.SetUser
  plug :not_following when action in [:create]
  plug :not_current_user when action in [:create, :delete]

  def index(conn, _param) do
    user = conn.assigns[:user]
    followers = user.followers |> Repo.preload(:follower)
    render conn, "index.html", user: user, followers: followers
  end

  def create(conn, _param) do
    user = conn.assigns[:user]
    current_user = conn.assigns[:current_user]
    follower = %Follower{user_id: user.id, follower_id: current_user.id}
    case Repo.insert Follower.changeset(follower, %{}) do
      {:ok, _follower} ->
        redirect conn, to: user_following_path(conn, :index, current_user.id)
      {:error, _changeset} ->
        conn
        |> put_flash(:error, gettext "Unable to follow this user")
        |> redirect(to: user_path(conn, :show, user))
        |> halt
    end
  end

  def delete(conn, _param) do
    user = conn.assigns[:user]
    current_user = conn.assigns[:current_user]
    query = from f in Follower,
            where: f.user_id == ^user.id and f.follower_id == ^current_user.id
    follower = Repo.one! query
    Repo.delete! follower
    redirect conn, to: user_following_path(conn, :index, current_user.id)
  end

  defp not_following(conn, _default) do
    user = conn.assigns[:user]
    current_user = conn.assigns[:current_user]
    query = from f in Follower, where: f.user_id == ^user.id and f.follower_id == ^current_user.id
    if Repo.one(query) do
      conn
      |> put_flash(:error, gettext "You are already following this user")
      |> redirect(to: user_path(conn, :show, user))
      |> halt
    else
      conn
    end
  end

  defp not_current_user(conn, _default) do
    user = conn.assigns[:user]
    current_user = conn.assigns[:current_user]
    if user.id === current_user.id do
      conn
      |> put_flash(:error, gettext "You can't follow yourself, silly")
      |> redirect(to: user_path(conn, :show, user))
      |> halt
    else
      conn
    end
  end
end
