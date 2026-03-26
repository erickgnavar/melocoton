defmodule MelocotonWeb.DatabaseLive.FormComponent do
  use MelocotonWeb, :live_component

  alias Melocoton.Databases

  @impl true
  def render(assigns) do
    ~H"""
    <div class="p-4">
      <.simple_form
        for={@form}
        id="database-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.input
          field={@form[:group_id]}
          type="select"
          label="Group"
          options={Enum.map(@groups, &{&1.name, &1.id})}
          required={true}
        />
        <.input field={@form[:name]} type="text" label="Name" />
        <.input
          field={@form[:type]}
          type="select"
          options={Ecto.Enum.values(Melocoton.Databases.Database, :type)}
          label="Type"
        />

        <%= if @db_type == :postgres do %>
          <fieldset
            class="rounded p-3 space-y-3"
            style="border: 1px solid var(--border-medium);"
          >
            <legend
              class="px-2 text-[10px] uppercase font-semibold tracking-wide"
              style="color: var(--text-tertiary);"
            >
              PostgreSQL Connection
            </legend>
            <.input field={@form[:pg_host]} type="text" label="Host" value={@pg_host} />
            <.input field={@form[:pg_port]} type="text" label="Port" value={@pg_port} />
            <.input field={@form[:pg_user]} type="text" label="User" value={@pg_user} />
            <.input
              field={@form[:pg_password]}
              type="password"
              label="Password"
              value={@pg_password}
            />
            <.input field={@form[:pg_database]} type="text" label="Database" value={@pg_database} />
            <div
              class="px-2.5 py-1.5 rounded text-[11px] font-mono truncate"
              style="background: var(--bg-tertiary); color: var(--text-tertiary); border: 0.5px solid var(--border-medium);"
              title={build_display_url(@pg_host, @pg_port, @pg_user, @pg_password, @pg_database)}
            >
              {build_display_url(@pg_host, @pg_port, @pg_user, @pg_password, @pg_database)}
            </div>
          </fieldset>
        <% else %>
          <fieldset
            class="rounded p-3 space-y-3"
            style="border: 1px solid var(--border-medium);"
          >
            <legend
              class="px-2 text-[10px] uppercase font-semibold tracking-wide"
              style="color: var(--text-tertiary);"
            >
              SQLite Connection
            </legend>
            <.input field={@form[:url]} type="text" label="File path" />
          </fieldset>
        <% end %>

        <:actions>
          <.button phx-disable-with="Saving...">Save Database</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(%{database: database} = assigns, socket) do
    {pg_host, pg_port, pg_user, pg_password, pg_database} = parse_postgres_url(database.url)
    db_type = database.type || :sqlite

    {:ok,
     socket
     |> assign(assigns)
     |> assign(
       db_type: db_type,
       pg_host: pg_host,
       pg_port: pg_port,
       pg_user: pg_user,
       pg_password: pg_password,
       pg_database: pg_database
     )
     |> assign_new(:form, fn ->
       to_form(Databases.change_database(database))
     end)}
  end

  @impl true
  def handle_event("validate", %{"database" => database_params}, socket) do
    db_type = String.to_existing_atom(database_params["type"] || "sqlite")

    socket =
      if db_type == :postgres do
        pg_host = database_params["pg_host"] || socket.assigns.pg_host
        pg_port = database_params["pg_port"] || socket.assigns.pg_port
        pg_user = database_params["pg_user"] || socket.assigns.pg_user
        pg_password = database_params["pg_password"] || socket.assigns.pg_password
        pg_database = database_params["pg_database"] || socket.assigns.pg_database

        assign(socket,
          pg_host: pg_host,
          pg_port: pg_port,
          pg_user: pg_user,
          pg_password: pg_password,
          pg_database: pg_database
        )
      else
        socket
      end

    database_params = maybe_build_url(database_params, db_type, socket.assigns)
    changeset = Databases.change_database(socket.assigns.database, database_params)
    {:noreply, assign(socket, form: to_form(changeset, action: :validate), db_type: db_type)}
  end

  def handle_event("save", %{"database" => database_params}, socket) do
    db_type = String.to_existing_atom(database_params["type"] || "sqlite")
    database_params = maybe_build_url(database_params, db_type, socket.assigns)
    save_database(socket, socket.assigns.action, database_params)
  end

  defp save_database(socket, :edit, database_params) do
    case Databases.update_database(socket.assigns.database, database_params) do
      {:ok, database} ->
        notify_parent({:saved, database})

        {:noreply,
         socket
         |> put_flash(:info, "Database updated successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save_database(socket, :new, database_params) do
    case Databases.create_database(database_params) do
      {:ok, database} ->
        notify_parent({:saved, database})

        {:noreply,
         socket
         |> put_flash(:info, "Database created successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp build_display_url(host, port, user, password, database) do
    masked = if password != "", do: String.duplicate("*", String.length(password)), else: ""
    build_postgres_url(host, port, user, masked, database)
  end

  defp maybe_build_url(params, :postgres, assigns) do
    pg = extract_pg_fields(params, assigns)
    url = build_postgres_url(pg.host, pg.port, pg.user, pg.password, pg.database)
    Map.put(params, "url", url)
  end

  defp maybe_build_url(params, _type, _assigns), do: params

  defp extract_pg_fields(params, assigns) do
    fields = ~w(host port user password database)
    defaults = %{"host" => "localhost", "port" => "5432"}

    Map.new(fields, fn field ->
      pg_key = "pg_#{field}"

      value =
        params[pg_key] || Map.get(assigns, String.to_existing_atom(pg_key)) || defaults[field] ||
          ""

      {String.to_atom(field), value}
    end)
  end

  defp build_postgres_url(host, port, user, password, database) do
    userinfo = format_userinfo(user || "", password || "")
    "postgres://#{userinfo}#{host || "localhost"}:#{port || "5432"}/#{database || ""}"
  end

  defp format_userinfo("", _), do: ""
  defp format_userinfo(user, ""), do: "#{user}@"
  defp format_userinfo(user, pass), do: "#{user}:#{pass}@"

  defp parse_postgres_url(nil), do: {"localhost", "5432", "", "", ""}
  defp parse_postgres_url(""), do: {"localhost", "5432", "", "", ""}

  defp parse_postgres_url(url) do
    case URI.parse(url) do
      %URI{host: host, port: port, path: path, userinfo: userinfo}
      when not is_nil(host) ->
        {user, password} =
          case userinfo do
            nil ->
              {"", ""}

            info ->
              case String.split(info, ":", parts: 2) do
                [u, p] -> {u, p}
                [u] -> {u, ""}
              end
          end

        database = if path, do: String.trim_leading(path, "/"), else: ""
        {host, to_string(port || 5432), user, password, database}

      _ ->
        {"localhost", "5432", "", "", ""}
    end
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
