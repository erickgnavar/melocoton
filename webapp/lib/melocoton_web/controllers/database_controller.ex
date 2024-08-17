defmodule MelocotonWeb.DatabaseController do
  use MelocotonWeb, :controller

  alias Melocoton.Databases
  alias Melocoton.Databases.Database

  def index(conn, _params) do
    databases = Databases.list_databases()
    render(conn, :index, databases: databases)
  end

  def new(conn, _params) do
    changeset = Databases.change_database(%Database{})
    render(conn, :new, changeset: changeset)
  end

  def create(conn, %{"database" => database_params}) do
    case Databases.create_database(database_params) do
      {:ok, database} ->
        conn
        |> put_flash(:info, "Database created successfully.")
        |> redirect(to: ~p"/databases/#{database}")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :new, changeset: changeset)
    end
  end

  def show(conn, %{"id" => id}) do
    database = Databases.get_database!(id)
    render(conn, :show, database: database)
  end

  def edit(conn, %{"id" => id}) do
    database = Databases.get_database!(id)
    changeset = Databases.change_database(database)
    render(conn, :edit, database: database, changeset: changeset)
  end

  def update(conn, %{"id" => id, "database" => database_params}) do
    database = Databases.get_database!(id)

    case Databases.update_database(database, database_params) do
      {:ok, database} ->
        conn
        |> put_flash(:info, "Database updated successfully.")
        |> redirect(to: ~p"/databases/#{database}")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :edit, database: database, changeset: changeset)
    end
  end

  def delete(conn, %{"id" => id}) do
    database = Databases.get_database!(id)
    {:ok, _database} = Databases.delete_database(database)

    conn
    |> put_flash(:info, "Database deleted successfully.")
    |> redirect(to: ~p"/databases")
  end
end
