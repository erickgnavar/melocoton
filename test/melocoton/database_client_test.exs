defmodule Melocoton.DatabaseClientTest do
  use ExUnit.Case, async: true

  alias Melocoton.DatabaseClient

  defp make_result(cols, rows) do
    %{columns: cols, rows: rows, num_rows: length(rows)}
  end

  describe "handle_response/2 — array normalization" do
    test "normalizes integer arrays" do
      result = make_result(["ids"], [[[1, 2, 3]]])

      %{rows: [%{"ids" => [1, 2, 3]}]} =
        DatabaseClient.handle_response(result, %{"ids" => "_int4"})
    end

    test "normalizes text arrays" do
      result = make_result(["tags"], [[["elixir", "phoenix"]]])
      %{rows: [%{"tags" => ["elixir", "phoenix"]}]} = DatabaseClient.handle_response(result)
    end

    test "normalizes UUID arrays with element type" do
      raw_uuid = Ecto.UUID.dump!("a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11")
      result = make_result(["ids"], [[[raw_uuid]]])

      %{rows: [%{"ids" => [formatted]}]} =
        DatabaseClient.handle_response(result, %{"ids" => "_uuid"})

      assert formatted == "a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11"
    end

    test "normalizes nested arrays" do
      result = make_result(["matrix"], [[[[1, 2], [3, 4]]]])
      %{rows: [%{"matrix" => [[1, 2], [3, 4]]}]} = DatabaseClient.handle_response(result)
    end

    test "empty array" do
      result = make_result(["tags"], [[[]]])
      %{rows: [%{"tags" => []}]} = DatabaseClient.handle_response(result)
    end
  end

  describe "handle_response/2 — Postgrex struct normalization" do
    test "formats Range with inclusive bounds" do
      range = %Postgrex.Range{lower: 1, upper: 10, lower_inclusive: true, upper_inclusive: true}
      result = make_result(["r"], [[range]])
      %{rows: [%{"r" => "[1,10]"}]} = DatabaseClient.handle_response(result)
    end

    test "formats Range with exclusive upper bound" do
      range = %Postgrex.Range{lower: 1, upper: 10, lower_inclusive: true, upper_inclusive: false}
      result = make_result(["r"], [[range]])
      %{rows: [%{"r" => "[1,10)"}]} = DatabaseClient.handle_response(result)
    end

    test "formats Range with nil bounds (unbounded)" do
      range = %Postgrex.Range{
        lower: nil,
        upper: 10,
        lower_inclusive: false,
        upper_inclusive: false
      }

      result = make_result(["r"], [[range]])
      %{rows: [%{"r" => "(,10)"}]} = DatabaseClient.handle_response(result)
    end

    test "formats INET with netmask" do
      inet = %Postgrex.INET{address: {192, 168, 1, 0}, netmask: 24}
      result = make_result(["ip"], [[inet]])
      %{rows: [%{"ip" => "192.168.1.0/24"}]} = DatabaseClient.handle_response(result)
    end

    test "formats INET without netmask" do
      inet = %Postgrex.INET{address: {10, 0, 0, 1}, netmask: nil}
      result = make_result(["ip"], [[inet]])
      %{rows: [%{"ip" => "10.0.0.1"}]} = DatabaseClient.handle_response(result)
    end

    test "formats IPv6 INET" do
      inet = %Postgrex.INET{address: {0, 0, 0, 0, 0, 0, 0, 1}, netmask: 128}
      result = make_result(["ip"], [[inet]])
      %{rows: [%{"ip" => "::1/128"}]} = DatabaseClient.handle_response(result)
    end

    test "formats MACADDR" do
      mac = %Postgrex.MACADDR{address: {8, 0, 43, 1, 2, 3}}
      result = make_result(["mac"], [[mac]])
      %{rows: [%{"mac" => "08:00:2b:01:02:03"}]} = DatabaseClient.handle_response(result)
    end

    test "formats Point" do
      point = %Postgrex.Point{x: 1.5, y: 2.0}
      result = make_result(["p"], [[point]])
      %{rows: [%{"p" => "(1.5,2.0)"}]} = DatabaseClient.handle_response(result)
    end

    test "formats Interval with all parts" do
      interval = %Postgrex.Interval{months: 3, days: 2, secs: 1, microsecs: 0}
      result = make_result(["i"], [[interval]])
      %{rows: [%{"i" => "3 mon 2 day 1 sec"}]} = DatabaseClient.handle_response(result)
    end

    test "formats Interval with zero values" do
      interval = %Postgrex.Interval{months: 0, days: 0, secs: 0, microsecs: 0}
      result = make_result(["i"], [[interval]])
      %{rows: [%{"i" => "0 sec"}]} = DatabaseClient.handle_response(result)
    end

    test "formats Lexeme with positions" do
      lexeme = %Postgrex.Lexeme{word: "cat", positions: [{1, :A}, {3, nil}]}
      result = make_result(["l"], [[lexeme]])
      %{rows: [%{"l" => "'cat':1,3"}]} = DatabaseClient.handle_response(result)
    end

    test "formats Lexeme without positions" do
      lexeme = %Postgrex.Lexeme{word: "dog", positions: []}
      result = make_result(["l"], [[lexeme]])
      %{rows: [%{"l" => "'dog'"}]} = DatabaseClient.handle_response(result)
    end

    test "formats Multirange" do
      ranges = [
        %Postgrex.Range{lower: 1, upper: 5, lower_inclusive: true, upper_inclusive: false},
        %Postgrex.Range{lower: 10, upper: 20, lower_inclusive: true, upper_inclusive: true}
      ]

      mr = %Postgrex.Multirange{ranges: ranges}
      result = make_result(["mr"], [[mr]])
      %{rows: [%{"mr" => "{[1,5),[10,20]}"}]} = DatabaseClient.handle_response(result)
    end

    test "formats Line" do
      line = %Postgrex.Line{a: 1.0, b: 2.0, c: 3.0}
      result = make_result(["l"], [[line]])
      %{rows: [%{"l" => "{1.0,2.0,3.0}"}]} = DatabaseClient.handle_response(result)
    end

    test "formats LineSegment" do
      seg = %Postgrex.LineSegment{
        point1: %Postgrex.Point{x: 0.0, y: 0.0},
        point2: %Postgrex.Point{x: 1.0, y: 1.0}
      }

      result = make_result(["s"], [[seg]])
      %{rows: [%{"s" => "[(0.0,0.0),(1.0,1.0)]"}]} = DatabaseClient.handle_response(result)
    end

    test "formats Box" do
      box = %Postgrex.Box{
        upper_right: %Postgrex.Point{x: 3.0, y: 4.0},
        bottom_left: %Postgrex.Point{x: 1.0, y: 2.0}
      }

      result = make_result(["b"], [[box]])
      %{rows: [%{"b" => "(3.0,4.0),(1.0,2.0)"}]} = DatabaseClient.handle_response(result)
    end

    test "formats open Path" do
      path = %Postgrex.Path{
        points: [%Postgrex.Point{x: 0.0, y: 0.0}, %Postgrex.Point{x: 1.0, y: 1.0}],
        open: true
      }

      result = make_result(["p"], [[path]])
      %{rows: [%{"p" => "[(0.0,0.0),(1.0,1.0)]"}]} = DatabaseClient.handle_response(result)
    end

    test "formats closed Path" do
      path = %Postgrex.Path{
        points: [
          %Postgrex.Point{x: 0.0, y: 0.0},
          %Postgrex.Point{x: 1.0, y: 0.0},
          %Postgrex.Point{x: 0.0, y: 1.0}
        ],
        open: false
      }

      result = make_result(["p"], [[path]])

      %{rows: [%{"p" => "((0.0,0.0),(1.0,0.0),(0.0,1.0))"}]} =
        DatabaseClient.handle_response(result)
    end

    test "formats Polygon" do
      poly = %Postgrex.Polygon{
        vertices: [
          %Postgrex.Point{x: 0.0, y: 0.0},
          %Postgrex.Point{x: 1.0, y: 0.0},
          %Postgrex.Point{x: 0.0, y: 1.0}
        ]
      }

      result = make_result(["p"], [[poly]])

      %{rows: [%{"p" => "((0.0,0.0),(1.0,0.0),(0.0,1.0))"}]} =
        DatabaseClient.handle_response(result)
    end

    test "formats Circle" do
      circle = %Postgrex.Circle{center: %Postgrex.Point{x: 1.0, y: 2.0}, radius: 5.0}
      result = make_result(["c"], [[circle]])
      %{rows: [%{"c" => "<(1.0,2.0),5.0>"}]} = DatabaseClient.handle_response(result)
    end
  end

  describe "handle_response/2 — existing normalization" do
    test "passes through Date structs unchanged" do
      date = ~D[2024-01-15]
      result = make_result(["d"], [[date]])
      %{rows: [%{"d" => ^date}]} = DatabaseClient.handle_response(result)
    end

    test "passes through NaiveDateTime structs unchanged" do
      ndt = ~N[2024-01-15 10:30:00]
      result = make_result(["ts"], [[ndt]])
      %{rows: [%{"ts" => ^ndt}]} = DatabaseClient.handle_response(result)
    end

    test "encodes plain maps as JSON" do
      result = make_result(["data"], [[%{"key" => "value"}]])
      %{rows: [%{"data" => json}]} = DatabaseClient.handle_response(result)
      assert Jason.decode!(json) == %{"key" => "value"}
    end

    test "formats invalid UTF-8 binary as hex" do
      result = make_result(["bin"], [[<<0xFF, 0xFE>>]])
      %{rows: [%{"bin" => "\\xfffe"}]} = DatabaseClient.handle_response(result)
    end

    test "passes through plain integers" do
      result = make_result(["n"], [[42]])
      %{rows: [%{"n" => 42}]} = DatabaseClient.handle_response(result)
    end

    test "passes through nil" do
      result = make_result(["n"], [[nil]])
      %{rows: [%{"n" => nil}]} = DatabaseClient.handle_response(result)
    end
  end

  describe "map_rows/2" do
    test "maps every row when the input is ok (map rows)" do
      input = {:ok, %{rows: [%{"name" => "a"}, %{"name" => "b"}]}}

      assert {:ok, ["a", "b"]} = DatabaseClient.map_rows(input, & &1["name"])
    end

    test "maps every row when the input is ok (tuple/list rows)" do
      input = {:ok, %{rows: [[1, "a"], [2, "b"]]}}

      assert {:ok, [%{id: 1, name: "a"}, %{id: 2, name: "b"}]} =
               DatabaseClient.map_rows(input, fn [id, name] -> %{id: id, name: name} end)
    end

    test "preserves an empty row list" do
      assert {:ok, []} = DatabaseClient.map_rows({:ok, %{rows: []}}, & &1)
    end

    test "passes errors through unchanged" do
      assert {:error, :boom} = DatabaseClient.map_rows({:error, :boom}, & &1)
    end

    test "does not invoke the mapper on error" do
      mapper = fn _ -> flunk("mapper should not be called") end
      assert {:error, :oops} = DatabaseClient.map_rows({:error, :oops}, mapper)
    end
  end
end
