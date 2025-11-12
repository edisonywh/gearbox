defmodule GearboxTest do
  use ExUnit.Case
  doctest Gearbox

  defmodule Gear do
    defstruct name: nil, status: nil, state: nil
  end

  test ":field should be customizable" do
    gear = %Gear{status: "neutral"}

    defmodule GearboxMachine do
      @behaviour Gearbox.Machine

      def field, do: :status
      def states, do: ~w(neutral drive)
      def initial_state, do: "neutral"
      def transitions, do: %{"neutral" => "drive"}
    end

    assert {:ok, gear} = Gearbox.transition(gear, GearboxMachine, "drive")
    assert gear.status == "drive"
  after
    purge(GearboxMachine)
  end

  test ":initial should be customizable" do
    gear = %Gear{status: nil}

    defmodule GearboxMachine do
      @behaviour Gearbox.Machine

      def field, do: :status
      def initial_state, do: "drive"
      def states, do: ~w(neutral drive)
      def transitions, do: %{"neutral" => "drive", "drive" => "neutral"}
    end

    assert "drive" == GearboxMachine.initial_state()

    assert {:ok, gear} = Gearbox.transition(gear, GearboxMachine, "neutral")
    assert gear.status == "neutral"
  after
    purge(GearboxMachine)
  end

  test "initial state is used when struct field is nil" do
    gear = %Gear{status: nil}

    defmodule GearboxMachine do
      @behaviour Gearbox.Machine

      def field, do: :status
      def states, do: ~w(neutral drive)
      def initial_state, do: "neutral"
      def transitions, do: %{"neutral" => "drive", "drive" => "neutral"}
    end

    assert "neutral" == GearboxMachine.initial_state()

    assert {:ok, gear} = Gearbox.transition(gear, GearboxMachine, "drive")
    assert gear.status == "drive"
  after
    purge(GearboxMachine)
  end

  test "transition/3 works for non-structs" do
    gear = %{state: "neutral"}

    defmodule GearboxMachine do
      @behaviour Gearbox.Machine

      def field, do: :state
      def states, do: ~w(neutral drive)
      def initial_state, do: "neutral"
      def transitions, do: %{"neutral" => "drive"}
    end

    assert {:ok, gear} = Gearbox.transition(gear, GearboxMachine, "drive")
    assert gear.state == "drive"
  after
    purge(GearboxMachine)
  end

  test "transition/3 allows valid transition (not in list)" do
    gear = %Gear{state: "neutral"}

    defmodule GearboxMachine do
      @behaviour Gearbox.Machine

      def field, do: :state
      def states, do: ~w(neutral drive)
      def initial_state, do: "neutral"
      def transitions, do: %{"neutral" => "drive"}
    end

    assert {:ok, gear} = Gearbox.transition(gear, GearboxMachine, "drive")
    assert gear.state == "drive"
  after
    purge(GearboxMachine)
  end

  test "transition/3 allows valid transition (in list)" do
    gear = %Gear{state: "neutral"}

    defmodule GearboxMachine do
      @behaviour Gearbox.Machine

      def field, do: :state
      def states, do: ~w(neutral drive)
      def initial_state, do: "neutral"
      def transitions, do: %{"neutral" => ~w(drive)}
    end

    assert {:ok, gear} = Gearbox.transition(gear, GearboxMachine, "drive")
    assert gear.state == "drive"
  after
    purge(GearboxMachine)
  end

  test "transition/3 should allow wildcard input" do
    gear = %Gear{state: "neutral"}

    defmodule GearboxMachine do
      @behaviour Gearbox.Machine

      def field, do: :state
      def states, do: ~w(neutral drive)
      def initial_state, do: "neutral"
      def transitions, do: %{"*" => ~w(drive)}
    end

    assert {:ok, gear} = Gearbox.transition(gear, GearboxMachine, "drive")
    assert gear.state == "drive"
  after
    purge(GearboxMachine)
  end

  test "transition/3 should allow atoms" do
    gear = %Gear{state: :neutral}

    defmodule GearboxMachine do
      @behaviour Gearbox.Machine

      def field, do: :state
      def states, do: ~w(neutral drive)a
      def initial_state, do: :neutral
      def transitions, do: %{neutral: :drive}
    end

    assert {:ok, gear} = Gearbox.transition(gear, GearboxMachine, :drive)
    assert gear.state == :drive
  after
    purge(GearboxMachine)
  end

  test "transition/3 should allow wildcard destination" do
    gear = %Gear{state: "neutral"}

    defmodule GearboxMachine do
      @behaviour Gearbox.Machine

      def field, do: :state
      def states, do: ~w(neutral drive)
      def initial_state, do: "neutral"
      def transitions, do: %{"neutral" => "*"}
    end

    assert {:ok, gear} = Gearbox.transition(gear, GearboxMachine, "drive")
    assert gear.state == "drive"
  after
    purge(GearboxMachine)
  end

  test "transition/3 should allow wildcards" do
    gear = %Gear{state: "neutral"}

    defmodule GearboxMachine do
      @behaviour Gearbox.Machine

      def field, do: :state
      def states, do: ~w(neutral parking drive)
      def initial_state, do: "neutral"
      def transitions, do: %{"*" => "*"}
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
      @behaviour Gearbox.Machine

      def field, do: :state
      def states, do: ~w(neutral drive parking)
      def initial_state, do: "neutral"
      def transitions, do: %{"neutral" => ~w(drive)}
    end

    assert {:error, msg} = Gearbox.transition(gear, GearboxMachine, "parking")
    assert msg =~ "Cannot transition from"
    assert gear.state == "neutral"
  after
    purge(GearboxMachine)
  end

  test "transition/3 disallow invalid transition (undefined input)" do
    gear = %Gear{state: "undefined"}

    defmodule GearboxMachine do
      @behaviour Gearbox.Machine

      def field, do: :state
      def states, do: ~w(neutral drive)
      def initial_state, do: "neutral"
      def transitions, do: %{"neutral" => ~w(drive)}
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
      @behaviour Gearbox.Machine

      def field, do: :state
      def states, do: ~w(neutral drive)
      def initial_state, do: "neutral"
      def transitions, do: %{"neutral" => ~w(drive)}
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
      @behaviour Gearbox.Machine

      def field, do: :state
      def states, do: ~w(neutral drive)
      def initial_state, do: "neutral"
      def transitions, do: %{"neutral" => ~w(drive)}
    end

    assert %Gear{} = gear = Gearbox.transition!(gear, GearboxMachine, "drive")
    assert gear.state == "drive"
  after
    purge(GearboxMachine)
  end

  test "transition!/3 should raise error when invalid" do
    gear = %Gear{state: "neutral"}

    defmodule GearboxMachine do
      @behaviour Gearbox.Machine

      def field, do: :state
      def states, do: ~w(neutral drive)
      def initial_state, do: "neutral"
      def transitions, do: %{"neutral" => ~w(drive)}
    end

    assert_raise Gearbox.InvalidTransitionError, ~r/Cannot transition from/, fn ->
      Gearbox.transition!(gear, GearboxMachine, "invalid")
    end
  after
    purge(GearboxMachine)
  end

  # Success guard is anything but {:halt, reason}
  test "guard_transition/3 when success guard should transition" do
    gear = %Gear{state: "neutral"}

    defmodule GearboxMachine do
      @behaviour Gearbox.Machine

      def field, do: :state
      def states, do: ~w(neutral drive)
      def initial_state, do: "neutral"
      def transitions, do: %{"neutral" => ~w(drive)}

      def guard_transition(_struct, "neutral", _drive) do
        nil
      end
    end

    assert {:ok, gear} = Gearbox.transition(gear, GearboxMachine, "drive")
    assert gear.state == "drive"
  after
    purge(GearboxMachine)
  end

  test "guard_transition/3 when failed guard should not transition" do
    gear = %Gear{state: "neutral"}

    defmodule GearboxMachine do
      @behaviour Gearbox.Machine

      def field, do: :state
      def states, do: ~w(neutral drive)
      def initial_state, do: "neutral"
      def transitions, do: %{"neutral" => ~w(drive)}

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
