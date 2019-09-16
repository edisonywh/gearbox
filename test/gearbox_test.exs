defmodule GearboxTest do
  use ExUnit.Case
  doctest Gearbox

  alias GearboxTest.GearboxMachine

  defmodule Gear do
    defstruct name: nil, status: nil, state: nil
  end

  test ":field should be customizable" do
    gear = %Gear{status: "neutral"}

    defmodule GearboxMachine do
      use Gearbox,
        field: :status,
        states: ~w(neutral drive),
        transitions: %{
          "neutral" => "drive"
        }
    end

    assert {:ok, gear} = Gearbox.transition(gear, GearboxMachine, "drive")
    assert gear.status == "drive"
  after
    purge(GearboxMachine)
  end

  test ":initial should be customizable" do
    gear = %Gear{status: nil}

    defmodule GearboxMachine do
      use Gearbox,
        field: :status,
        initial: "drive",
        states: ~w(neutral drive),
        transitions: %{
          "neutral" => "drive",
          "drive" => "neutral"
        }
    end

    assert "drive" == GearboxMachine.__machine_states__(:initial)

    assert {:ok, gear} = Gearbox.transition(gear, GearboxMachine, "neutral")
    assert gear.status == "neutral"
  after
    purge(GearboxMachine)
  end

  test ":initial should default to first item in states" do
    gear = %Gear{status: nil}

    defmodule GearboxMachine do
      use Gearbox,
        field: :status,
        states: ~w(neutral drive),
        transitions: %{
          "neutral" => "drive",
          "drive" => "neutral"
        }
    end

    assert "neutral" == GearboxMachine.__machine_states__(:initial)

    assert {:ok, gear} = Gearbox.transition(gear, GearboxMachine, "drive")
    assert gear.status == "drive"
  after
    purge(GearboxMachine)
  end

  test "transition/3 allows valid transition (not in list)" do
    gear = %Gear{state: "neutral"}

    defmodule GearboxMachine do
      use Gearbox,
        states: ~w(neutral drive),
        transitions: %{
          "neutral" => "drive"
        }
    end

    assert {:ok, gear} = Gearbox.transition(gear, GearboxMachine, "drive")
    assert gear.state == "drive"
  after
    purge(GearboxMachine)
  end

  test "transition/3 allows valid transition (in list)" do
    gear = %Gear{state: "neutral"}

    defmodule GearboxMachine do
      use Gearbox,
        states: ~w(neutral drive),
        transitions: %{
          "neutral" => ~w(drive)
        }
    end

    assert {:ok, gear} = Gearbox.transition(gear, GearboxMachine, "drive")
    assert gear.state == "drive"
  after
    purge(GearboxMachine)
  end

  test "transition/3 should allow wildcard neutral" do
    gear = %Gear{state: "neutral"}

    defmodule GearboxMachine do
      use Gearbox,
        states: ~w(neutral drive),
        transitions: %{
          "*" => ~w(drive)
        }
    end

    assert {:ok, gear} = Gearbox.transition(gear, GearboxMachine, "drive")
    assert gear.state == "drive"
  after
    purge(GearboxMachine)
  end

  test "transition/3 should allow wildcard driveination" do
    gear = %Gear{state: "neutral"}

    defmodule GearboxMachine do
      use Gearbox,
        states: ~w(neutral drive),
        transitions: %{
          "neutral" => "*"
        }
    end

    assert {:ok, gear} = Gearbox.transition(gear, GearboxMachine, "drive")
    assert gear.state == "drive"
  after
    purge(GearboxMachine)
  end

  test "transition/3 should allow wildcards" do
    gear = %Gear{state: "neutral"}

    defmodule GearboxMachine do
      use Gearbox,
        states: ~w(neutral parking drive),
        transitions: %{
          "*" => "*"
        }
    end

    with {:ok, gear} <- Gearbox.transition(gear, GearboxMachine, "parking"),
         {:ok, gear} <- Gearbox.transition(gear, GearboxMachine, "drive"),
         {:ok, gear} <- Gearbox.transition(gear, GearboxMachine, "neutral"),
         {:ok, gear} <- Gearbox.transition(gear, GearboxMachine, "parking"),
         {:ok, gear} <- Gearbox.transition(gear, GearboxMachine, "drive") do
      assert gear.state == "drive"
    end
  after
    purge(GearboxMachine)
  end

  test "transition/3 disallow invalid transition" do
    gear = %Gear{state: "neutral"}

    defmodule GearboxMachine do
      use Gearbox,
        states: ~w(neutral drive parking),
        transitions: %{
          "neutral" => ~w(drive)
        }
    end

    assert {:error, msg} = Gearbox.transition(gear, GearboxMachine, "parking")
    assert msg =~ "Cannot transition from"
    assert gear.state == "neutral"
  after
    purge(GearboxMachine)
  end

  test "transition/3 disallow invalid transition (gearndefined neutral)" do
    gear = %Gear{state: "undefined"}

    defmodule GearboxMachine do
      use Gearbox,
        states: ~w(neutral drive),
        transitions: %{
          "neutral" => ~w(drive)
        }
    end

    assert {:error, msg} = Gearbox.transition(gear, GearboxMachine, "drive")
    assert msg =~ "Cannot transition from"
    assert gear.state == "undefined"
  after
    purge(GearboxMachine)
  end

  test "transition/3 disallow invalid transition (undefined destination)" do
    gear = %Gear{state: "neutral"}

    defmodule GearboxMachine do
      use Gearbox,
        states: ~w(neutral drive),
        transitions: %{
          "neutral" => ~w(drive)
        }
    end

    assert {:error, msg} = Gearbox.transition(gear, GearboxMachine, "undefined")
    assert msg =~ "Cannot transition from"
    assert gear.state == "neutral"
  after
    purge(GearboxMachine)
  end

  test "transition!/3 should transition and return without tuple when valid" do
    gear = %Gear{state: "neutral"}

    defmodule GearboxMachine do
      use Gearbox,
        states: ~w(neutral drive),
        transitions: %{
          "neutral" => ~w(drive)
        }
    end

    assert %Gear{} = gear = Gearbox.transition!(gear, GearboxMachine, "drive")
    assert gear.state == "drive"
  after
    purge(GearboxMachine)
  end

  test "transition!/3 should raise error when invalid" do
    gear = %Gear{state: "neutral"}

    defmodule GearboxMachine do
      use Gearbox,
        states: ~w(neutral drive),
        transitions: %{
          "neutral" => ~w(drive)
        }
    end

    assert_raise Gearbox.InvalidTransitionError, ~r/Cannot transition from/, fn ->
      Gearbox.transition!(gear, GearboxMachine, "invalid")
    end
  after
    purge(GearboxMachine)
  end

  test "before_transition/2 should allow override" do
    gear = %Gear{state: "neutral"}

    defmodule GearboxMachine do
      use Gearbox,
        states: ~w(neutral drive),
        transitions: %{
          "neutral" => ~w(drive)
        }

      def before_transition(struct, "neutral", "drive") do
        struct =
          struct
          |> Map.put(:name, "jellybean")

        struct
      end
    end

    assert gear.name == nil
    assert {:ok, gear} = Gearbox.transition(gear, GearboxMachine, "drive")
    assert gear.name == "jellybean"
  after
    purge(GearboxMachine)
  end

  test "after_transition/2 should allow override" do
    gear = %Gear{state: "neutral"}

    defmodule GearboxMachine do
      use Gearbox,
        states: ~w(neutral drive),
        transitions: %{
          "neutral" => ~w(drive)
        }

      def after_transition(struct, "neutral", "drive") do
        struct =
          struct
          |> Map.put(:name, "jellybean")

        struct
      end
    end

    assert gear.name == nil
    assert {:ok, gear} = Gearbox.transition(gear, GearboxMachine, "drive")
    assert gear.name == "jellybean"
  after
    purge(GearboxMachine)
  end

  # Success guard is anything but {:halt, reason}
  test "guard_transition/2 when success guard should transition" do
    gear = %Gear{state: "neutral"}

    defmodule GearboxMachine do
      use Gearbox,
        states: ~w(neutral drive),
        transitions: %{
          "neutral" => ~w(drive)
        }

      def guard_transition(_struct, "neutral", _drive) do
        nil
      end
    end

    assert {:ok, gear} = Gearbox.transition(gear, GearboxMachine, "drive")
    assert gear.state == "drive"
  after
    purge(GearboxMachine)
  end

  test "guard_transition/2 when failed guard should not transition" do
    gear = %Gear{state: "neutral"}

    defmodule GearboxMachine do
      use Gearbox,
        states: ~w(neutral drive),
        transitions: %{
          "neutral" => ~w(drive)
        }

      def guard_transition(_struct, "neutral", _drive) do
        {:halt, "The reason is you"}
      end
    end

    assert {:error, reason} = Gearbox.transition(gear, GearboxMachine, "drive")
    assert gear.state == "neutral"
    assert reason == "The reason is you"
  after
    purge(GearboxMachine)
  end

  defp purge(module) do
    :code.delete(module)
    :code.purge(module)
  end
end
