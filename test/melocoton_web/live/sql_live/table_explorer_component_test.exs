defmodule MelocotonWeb.SqlLive.TableExplorerComponentTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest
  import Phoenix.Component, only: [to_form: 1]

  alias MelocotonWeb.SqlLive.TableExplorerComponent
  alias Phoenix.LiveView.AsyncResult

  defp database(color \\ "#22cc66") do
    %{name: "test_db", type: :sqlite, group: %{name: "Default", color: color}}
  end

  defp data_result(cols \\ ["id", "name"], rows \\ [%{"id" => 1, "name" => "alice"}]) do
    AsyncResult.ok(%{cols: cols, rows: rows, num_rows: length(rows), query_error: nil})
  end

  defp structure_result(attrs \\ %{}) do
    default = %{
      columns: [
        %{"name" => "id", "data_type" => "INTEGER", "is_nullable" => "NO"},
        %{"name" => "name", "data_type" => "TEXT", "is_nullable" => "YES"}
      ],
      pk_columns: ["id"],
      foreign_keys: [],
      unique_constraints: [],
      check_constraints: [],
      indexes: [],
      referenced_by: [],
      create_statement: "CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT)",
      size: %{}
    }

    AsyncResult.ok(Map.merge(default, attrs))
  end

  defp base_assigns(overrides \\ %{}) do
    overrides = if is_list(overrides), do: Map.new(overrides), else: overrides

    %{
      database: database(),
      table_name: "users",
      active_tab: "data",
      myself: %Phoenix.LiveComponent.CID{cid: 1},
      pk_columns: ["id"],
      adding_row: nil,
      add_row_error: nil,
      add_row_sql_fields: MapSet.new(),
      columns: ["id", "name"],
      columns_dropdown_open: false,
      visible_columns: MapSet.new(["id", "name"]),
      filter_panel_open: false,
      filters: [],
      pending_changes: %{},
      apply_error: nil,
      filter: "",
      result: data_result(),
      page: 1,
      limit: 20,
      total_count: 1,
      total_pages: 1,
      sort_column: nil,
      sort_direction: nil,
      editing_cell: nil,
      limit_form: to_form(%{"limit" => 20}),
      column_types: %{}
    }
    |> Map.merge(overrides)
  end

  describe "render/1 data tab" do
    test "renders table with column headers and rows" do
      html =
        base_assigns()
        |> TableExplorerComponent.render()
        |> rendered_to_string()

      assert html =~ "id"
      assert html =~ "name"
      assert html =~ "alice"
    end

    test "shows pagination controls" do
      html =
        base_assigns(total_count: 100, total_pages: 5)
        |> TableExplorerComponent.render()
        |> rendered_to_string()

      assert html =~ "Showing"
      assert html =~ "1-20"
      assert html =~ "of"
      assert html =~ "~100"
    end

    test "shows ascending sort indicator" do
      html =
        base_assigns(sort_column: "name", sort_direction: :asc)
        |> TableExplorerComponent.render()
        |> rendered_to_string()

      assert html =~ "lucide-arrow-up"
    end

    test "shows descending sort indicator" do
      html =
        base_assigns(sort_column: "name", sort_direction: :desc)
        |> TableExplorerComponent.render()
        |> rendered_to_string()

      assert html =~ "lucide-arrow-down"
    end

    test "shows disabled add row button when table has no primary key" do
      html =
        base_assigns(pk_columns: [])
        |> TableExplorerComponent.render()
        |> rendered_to_string()

      assert html =~ "Editing disabled: table has no primary key"
    end

    test "shows column visibility dropdown when open" do
      html =
        base_assigns(
          columns_dropdown_open: true,
          visible_columns: MapSet.new(["id"])
        )
        |> TableExplorerComponent.render()
        |> rendered_to_string()

      assert html =~ "lucide-check-square"
      assert html =~ "lucide-square"
    end

    test "shows column count badge when columns are hidden" do
      html =
        base_assigns(
          visible_columns: MapSet.new(["id"]),
          columns_dropdown_open: true
        )
        |> TableExplorerComponent.render()
        |> rendered_to_string()

      assert html =~ ">1</span>"
    end

    test "shows filter panel when open" do
      html =
        base_assigns(
          filter_panel_open: true,
          filters: [%{id: "1", column: "name", operator: "contains", value: "", sql: false}]
        )
        |> TableExplorerComponent.render()
        |> rendered_to_string()

      assert html =~ "Where"
      assert html =~ "contains"
    end

    test "shows active filter count badge" do
      html =
        base_assigns(
          filter_panel_open: true,
          filters: [%{id: "1", column: "name", operator: "equals", value: "alice", sql: false}]
        )
        |> TableExplorerComponent.render()
        |> rendered_to_string()

      assert html =~ ">1</span>"
    end

    test "shows apply and discard changes buttons when there are pending changes" do
      html =
        base_assigns(pending_changes: %{{%{"id" => 1}, "name"} => "changed"})
        |> TableExplorerComponent.render()
        |> rendered_to_string()

      assert html =~ "Apply changes"
      assert html =~ "Discard"
      assert html =~ ">1</span>"
    end

    test "shows apply error banner" do
      html =
        base_assigns(apply_error: "constraint failed")
        |> TableExplorerComponent.render()
        |> rendered_to_string()

      assert html =~ "Changes rolled back"
      assert html =~ "constraint failed"
    end

    test "shows query error in results" do
      result = AsyncResult.ok(%{cols: [], rows: [], num_rows: 0, query_error: "syntax error"})

      html =
        base_assigns(result: result)
        |> TableExplorerComponent.render()
        |> rendered_to_string()

      assert html =~ "syntax error"
    end

    test "hides columns not in visible_columns" do
      html =
        base_assigns(visible_columns: MapSet.new(["id"]))
        |> TableExplorerComponent.render()
        |> rendered_to_string()

      refute html =~ "alice"
      assert html =~ "id"
    end

    test "does not show edit-cell click handler when table has no pk" do
      html =
        base_assigns(pk_columns: [])
        |> TableExplorerComponent.render()
        |> rendered_to_string()

      refute html =~ "phx-click=\"edit-cell\""
    end

    test "shows cell editor when editing_cell matches" do
      html =
        base_assigns(editing_cell: %{row_idx: 0, column: "name"})
        |> TableExplorerComponent.render()
        |> rendered_to_string()

      assert html =~ "cell-editor-0-name"
      assert html =~ ~s(value="alice")
    end

    test "shows pending cell value with undo button" do
      html =
        base_assigns(pending_changes: %{{%{"id" => 1}, "name"} => "pending_name"})
        |> TableExplorerComponent.render()
        |> rendered_to_string()

      assert html =~ "pending_name"
      assert html =~ "lucide-undo-2"
    end

    test "shows null placeholder for nil values" do
      result = data_result(["id", "name"], [%{"id" => 1, "name" => nil}])

      html =
        base_assigns(result: result)
        |> TableExplorerComponent.render()
        |> rendered_to_string()

      assert html =~ "cell-null"
    end
  end

  describe "render/1 structure tab" do
    test "renders structure with columns" do
      html =
        base_assigns(
          active_tab: "structure",
          structure: structure_result()
        )
        |> TableExplorerComponent.render()
        |> rendered_to_string()

      assert html =~ "Columns"
      assert html =~ "id"
      assert html =~ "name"
      assert html =~ "INTEGER"
      assert html =~ "TEXT"
    end

    test "shows foreign keys section when present" do
      structure =
        structure_result(%{
          foreign_keys: [
            %{name: "fk_user", column: "user_id", foreign_table: "users", foreign_column: "id"}
          ]
        })

      html =
        base_assigns(
          active_tab: "structure",
          structure: structure
        )
        |> TableExplorerComponent.render()
        |> rendered_to_string()

      assert html =~ "Foreign Keys"
      assert html =~ "user_id"
      assert html =~ "users"
    end

    test "shows error state" do
      html =
        base_assigns(
          active_tab: "structure",
          structure: AsyncResult.failed(AsyncResult.loading(), "boom")
        )
        |> TableExplorerComponent.render()
        |> rendered_to_string()

      assert html =~ "boom"
    end
  end

  describe "render/1 indexes tab" do
    test "shows indexes when present" do
      structure =
        structure_result(%{
          indexes: [
            %{name: "idx_name", columns: ["name"], unique: false},
            %{name: "idx_id", columns: ["id"], unique: true}
          ]
        })

      html =
        base_assigns(
          active_tab: "indexes",
          structure: structure
        )
        |> TableExplorerComponent.render()
        |> rendered_to_string()

      assert html =~ "idx_name"
      assert html =~ "idx_id"
      assert html =~ "name"
      assert html =~ "id"
    end

    test "shows empty state when no indexes" do
      html =
        base_assigns(
          active_tab: "indexes",
          structure: structure_result(%{indexes: []})
        )
        |> TableExplorerComponent.render()
        |> rendered_to_string()

      assert html =~ "No indexes found"
    end
  end

  describe "render/1 relations tab" do
    test "shows outgoing foreign keys" do
      structure =
        structure_result(%{
          foreign_keys: [
            %{name: "fk_posts", column: "user_id", foreign_table: "posts", foreign_column: "id"}
          ]
        })

      html =
        base_assigns(
          active_tab: "relations",
          structure: structure
        )
        |> TableExplorerComponent.render()
        |> rendered_to_string()

      assert html =~ "References (outgoing)"
      assert html =~ "user_id"
      assert html =~ "posts"
    end

    test "shows incoming references" do
      structure =
        structure_result(%{
          referenced_by: [
            %{name: "fk_user", column: "id", foreign_table: "posts", foreign_column: "user_id"}
          ]
        })

      html =
        base_assigns(
          active_tab: "relations",
          structure: structure
        )
        |> TableExplorerComponent.render()
        |> rendered_to_string()

      assert html =~ "Referenced by (incoming)"
      assert html =~ "posts"
    end

    test "shows empty state for no outgoing references" do
      html =
        base_assigns(
          active_tab: "relations",
          structure: structure_result(%{foreign_keys: []})
        )
        |> TableExplorerComponent.render()
        |> rendered_to_string()

      assert html =~ "This table does not reference other tables"
    end

    test "shows relation diagram when there are relationships" do
      structure =
        structure_result(%{
          foreign_keys: [
            %{name: "fk_posts", column: "user_id", foreign_table: "posts", foreign_column: "id"}
          ]
        })

      html =
        base_assigns(
          active_tab: "relations",
          structure: structure
        )
        |> TableExplorerComponent.render()
        |> rendered_to_string()

      assert html =~ "Diagram"
      assert html =~ "<svg"
    end
  end

  describe "render/1 add row modal" do
    test "shows modal when adding row" do
      html =
        base_assigns(adding_row: %{})
        |> TableExplorerComponent.render()
        |> rendered_to_string()

      assert html =~ "Add row to users"
      assert html =~ "Insert Row"
    end

    test "shows all columns as form fields" do
      html =
        base_assigns(
          adding_row: %{},
          columns: ["id", "name", "email"]
        )
        |> TableExplorerComponent.render()
        |> rendered_to_string()

      assert html =~ "id"
      assert html =~ "name"
      assert html =~ "email"
    end

    test "shows add row error" do
      html =
        base_assigns(
          adding_row: %{"name" => "test"},
          add_row_error: "NOT NULL constraint failed"
        )
        |> TableExplorerComponent.render()
        |> rendered_to_string()

      assert html =~ "NOT NULL constraint failed"
    end
  end

  describe "render/1 status bar" do
    test "shows status bar with database info and connected indicator" do
      html =
        base_assigns()
        |> TableExplorerComponent.render()
        |> rendered_to_string()

      assert html =~ "Default"
      assert html =~ "test_db"
      assert html =~ "sqlite"
      assert html =~ "connected"
      assert html =~ "bg-green-500"
    end
  end

  describe "render/1 pagination edge cases" do
    test "shows ellipsis for large page counts" do
      html =
        base_assigns(page: 5, total_pages: 20)
        |> TableExplorerComponent.render()
        |> rendered_to_string()

      assert html =~ "…"
    end
  end
end
