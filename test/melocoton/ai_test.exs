defmodule Melocoton.AITest do
  use Melocoton.DataCase

  alias Melocoton.AI

  defp test_schema(overrides \\ %{}) do
    Map.merge(
      %{
        type: :sqlite,
        tables: [
          %{
            name: "users",
            cols: [
              %{name: "id", type: "INTEGER"},
              %{name: "name", type: "TEXT"}
            ]
          },
          %{
            name: "posts",
            cols: [
              %{name: "id", type: "INTEGER"},
              %{name: "user_id", type: "INTEGER"},
              %{name: "title", type: "TEXT"}
            ]
          }
        ],
        indexes: [],
        triggers: [],
        functions: []
      },
      overrides
    )
  end

  describe "build_system_prompt/1" do
    test "includes database type" do
      prompt = AI.build_system_prompt(test_schema())

      assert prompt =~ "SQLite"
    end

    test "includes table names and columns" do
      prompt = AI.build_system_prompt(test_schema())

      assert prompt =~ "Table: users"
      assert prompt =~ "id"
      assert prompt =~ "name"
      assert prompt =~ "Table: posts"
      assert prompt =~ "title"
      assert prompt =~ "user_id"
    end

    test "includes SQL generation rules" do
      prompt = AI.build_system_prompt(test_schema())

      assert prompt =~ "```sql code block"
      assert prompt =~ "foreign key"
    end

    test "includes indexes when present" do
      schema = test_schema(%{indexes: [%{name: "idx_posts_user_id", table: "posts"}]})
      prompt = AI.build_system_prompt(schema)

      assert prompt =~ "Indexes:"
      assert prompt =~ "idx_posts_user_id"
    end

    test "includes triggers when present" do
      schema =
        test_schema(%{triggers: [%{id: "t1", name: "update_timestamp", table: "posts"}]})

      prompt = AI.build_system_prompt(schema)

      assert prompt =~ "Triggers:"
      assert prompt =~ "update_timestamp ON posts"
    end

    test "includes functions when present" do
      schema =
        test_schema(%{
          functions: [
            %{
              id: "1",
              name: "calc_total",
              schema: "public",
              kind: :function,
              return_type: "numeric",
              arguments: "order_id integer",
              language: "plpgsql"
            }
          ]
        })

      prompt = AI.build_system_prompt(schema)

      assert prompt =~ "Functions and procedures:"
      assert prompt =~ "function public.calc_total(order_id integer) -> numeric"
    end

    test "omits empty sections" do
      prompt = AI.build_system_prompt(test_schema())

      refute prompt =~ "Indexes:"
      refute prompt =~ "Triggers:"
      refute prompt =~ "Functions"
    end
  end

  describe "chat/3" do
    test "returns error when no model is configured" do
      # Ensure no model is configured
      Application.delete_env(:melocoton, :ai)

      messages = [%{role: "user", content: "show me all users"}]
      assert {:error, message} = AI.chat(test_schema(), messages)
      assert message =~ "No AI model configured"
    end
  end

  describe "build_system_prompt/1 with postgres type" do
    test "uses PostgreSQL label for postgres connections" do
      schema = %{test_schema() | type: :postgres}
      prompt = AI.build_system_prompt(schema)
      assert prompt =~ "PostgreSQL"
      refute prompt =~ "SQLite"
    end
  end
end
