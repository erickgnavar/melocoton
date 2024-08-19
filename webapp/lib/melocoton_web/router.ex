defmodule MelocotonWeb.Router do
  use MelocotonWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {MelocotonWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", MelocotonWeb do
    pipe_through :browser

    get "/", PageController, :home
    live "/databases", DatabaseLive.Index, :index
    live "/databases/new", DatabaseLive.Index, :new
    live "/databases/:id/edit", DatabaseLive.Index, :edit

    live "/databases/:id", DatabaseLive.Show, :show
    live "/databases/:id/show/edit", DatabaseLive.Show, :edit
    live "/databases/:database_id/run", SQLLive.Run
  end

  # Other scopes may use custom stacks.
  # scope "/api", MelocotonWeb do
  #   pipe_through :api
  # end
end
