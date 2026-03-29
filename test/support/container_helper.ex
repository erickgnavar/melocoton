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
end
