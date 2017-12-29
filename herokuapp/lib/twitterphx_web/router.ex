defmodule TwitterphxWeb.Router do
  use TwitterphxWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", TwitterphxWeb do
    pipe_through :browser # Use the default browser stack

    get "/", PageController, :index
    get "/home/:username", PageController, :home

  end

  # Other scopes may use custom stacks.
  # scope "/api", TwitterphxWeb do
  #   pipe_through :api
  # end
end
