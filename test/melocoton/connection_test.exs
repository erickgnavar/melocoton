defmodule Melocoton.ConnectionTest do
  use ExUnit.Case, async: true

  alias Melocoton.Connection

  describe "quote_identifier/1" do
    test "wraps a simple name in double quotes" do
      assert Connection.quote_identifier("users") == ~s("users")
    end

    test "escapes embedded double quotes by doubling them" do
      assert Connection.quote_identifier(~s(my"table)) == ~s("my""table")
    end

    test "neutralizes SQL injection attempts" do
      malicious = ~s(users"; DROP TABLE users; --)
      quoted = Connection.quote_identifier(malicious)

      assert quoted == ~s("users""; DROP TABLE users; --")
      assert String.starts_with?(quoted, "\"")
      assert String.ends_with?(quoted, "\"")
    end

    test "handles names with spaces" do
      assert Connection.quote_identifier("my table") == ~s("my table")
    end

    test "handles names with multiple double quotes" do
      assert Connection.quote_identifier(~s(a"b"c)) == ~s("a""b""c")
    end
  end
end
