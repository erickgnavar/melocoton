defmodule Melocoton.AITest do
  use Melocoton.DataCase

  alias Melocoton.AI

  defp test_schema do
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
      ]
    }
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
