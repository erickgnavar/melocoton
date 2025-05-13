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
    get "/export-csv/:pid", PageController, :export_csv
    live "/databases", DatabaseLive.Index, :index
    live "/databases/new", DatabaseLive.Index, :new
    live "/databases/:id/edit", DatabaseLive.Index, :edit

    live "/groups/new", DatabaseLive.Index, :new_group
    live "/groups/:id/edit", DatabaseLive.Index, :edit_group

    live "/databases/:database_id/run", SQLLive.Run
  end

  # Other scopes may use custom stacks.
  # scope "/api", MelocotonWeb do
  #   pipe_through :api
  # end
end
