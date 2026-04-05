defmodule Melocoton.PoolTest do
  use Melocoton.DataCase

  alias Melocoton.Connection

  describe "health check" do
    test "evicts dead connections from pool state" do
      # Spawn a process and immediately kill it to simulate a dead connection
      dead_pid = spawn(fn -> :ok end)
      # Ensure the process is dead
      ref = Process.monitor(dead_pid)
      assert_receive {:DOWN, ^ref, :process, ^dead_pid, _}

      alive_pid = spawn(fn -> Process.sleep(:infinity) end)

      state = %{
        1 => %Connection{pid: dead_pid, type: :sqlite},
        2 => %Connection{pid: alive_pid, type: :sqlite}
      }

      :sys.replace_state(Melocoton.Pool, fn _ -> state end)

      # Trigger health check
      send(Melocoton.Pool, :health_check)

      # Give GenServer time to process the message
      Process.sleep(50)

      new_state = :sys.get_state(Melocoton.Pool)

      refute Map.has_key?(new_state, 1)
      assert Map.has_key?(new_state, 2)
      assert %Connection{pid: ^alive_pid} = new_state[2]

      Process.exit(alive_pid, :kill)
    end

    test "keeps all connections when all are alive" do
      pid1 = spawn(fn -> Process.sleep(:infinity) end)
      pid2 = spawn(fn -> Process.sleep(:infinity) end)

      state = %{
        1 => %Connection{pid: pid1, type: :sqlite},
        2 => %Connection{pid: pid2, type: :postgres}
      }

      :sys.replace_state(Melocoton.Pool, fn _ -> state end)

      send(Melocoton.Pool, :health_check)
      Process.sleep(50)

      new_state = :sys.get_state(Melocoton.Pool)
      assert map_size(new_state) == 2

      Process.exit(pid1, :kill)
      Process.exit(pid2, :kill)
    end

    test "handles empty state" do
      :sys.replace_state(Melocoton.Pool, fn _ -> %{} end)

      send(Melocoton.Pool, :health_check)
      Process.sleep(50)

      assert :sys.get_state(Melocoton.Pool) == %{}
    end
  end
end
