defmodule Melocoton.ContainerHelper do
  alias Melocoton.Connection

  def start_postgres(seed_sql \\ []) do
    config =
      Testcontainers.PostgresContainer.new()
      |> Testcontainers.PostgresContainer.with_database("melocoton_test")
      |> Testcontainers.PostgresContainer.with_user("postgres")
      |> Testcontainers.PostgresContainer.with_password("postgres")

    {:ok, container} = Testcontainers.start_container(config)
    conn_params = Testcontainers.PostgresContainer.connection_parameters(container)

    {:ok, pid} = Postgrex.start_link(conn_params)
    conn = %Connection{pid: pid, type: :postgres}

    for sql <- seed_sql do
      {:ok, _} = Connection.query(conn, sql)
    end

    {container, conn}
  end

  def start_mysql(seed_sql \\ []) do
    config =
      Testcontainers.MySqlContainer.new()
      |> Testcontainers.MySqlContainer.with_database("melocoton_test")
      |> Testcontainers.MySqlContainer.with_user("test")
      |> Testcontainers.MySqlContainer.with_password("test")

    {:ok, container} = Testcontainers.start_container(config)
    conn_params = Testcontainers.MySqlContainer.connection_parameters(container)

    {:ok, pid} =
      MyXQL.start_link(
        conn_params ++
          [after_connect: fn conn -> MyXQL.query!(conn, "SET sql_mode = 'ANSI_QUOTES'", []) end]
      )

    conn = %Connection{pid: pid, type: :mysql}

    for sql <- seed_sql do
      {:ok, _} = Connection.query(conn, sql)
    end

    {container, conn}
  end
end
