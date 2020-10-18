defmodule GearboxTest.Ecto do
  use ExUnit.Case
  doctest Gearbox.Ecto

  alias GearboxTest.Ecto.GearboxMachine

  defmodule GearSchema do
    use Ecto.Schema

    schema "gears" do
      field :name, :string
      field :status, :string
      field :state, :string
    end
  end

  test "transition_changeset/3 should return an Ecto changeset with changed state when valid" do
    gear = %GearSchema{state: "neutral"}

    defmodule GearboxMachine do
      use Gearbox,
        states: ~w(neutral drive),
        transitions: %{
          "neutral" => ~w(drive)
        }
    end

    assert {:ok, %Ecto.Changeset{} = gear_changeset} = Gearbox.Ecto.transition_changeset(gear, GearboxMachine, "drive")
    assert gear_changeset.valid?
    assert Ecto.Changeset.get_change(gear_changeset, :state) == "drive"
  after
    purge(GearboxMachine)
  end

  test "transition_changeset/3 should return an Ecto changeset with error when invalid transition" do
    gear = %GearSchema{state: "neutral"}

    defmodule GearboxMachine do
      use Gearbox,
        states: ~w(neutral drive parking),
        transitions: %{
          "neutral" => ~w(drive)
        }
    end

    assert {:error, %Ecto.Changeset{} = err_changeset} = Gearbox.Ecto.transition_changeset(gear, GearboxMachine, "parking")
    assert Keyword.has_key?(err_changeset.errors, :state)
    assert !err_changeset.valid?
    {msg, _addl} = err_changeset.errors[:state]
    assert msg =~ "Cannot transition from"
  after
    purge(GearboxMachine)
  end

  test "transition_changeset/3 should return an Ecto changeset with error when invalid transition (undefined input)" do
    gear = %GearSchema{state: "undefined"}

    defmodule GearboxMachine do
      use Gearbox,
        states: ~w(neutral drive),
        transitions: %{
          "neutral" => ~w(drive)
        }
    end

    assert {:error, %Ecto.Changeset{} = err_changeset} = Gearbox.Ecto.transition_changeset(gear, GearboxMachine, "drive")
    assert !err_changeset.valid?
    assert Keyword.has_key?(err_changeset.errors, :state)
    {msg, _addl} = err_changeset.errors[:state]
    assert msg =~ "Cannot transition from"
  after
    purge(GearboxMachine)
  end

  test "transition_changeset/3 should return an Ecto changeset with error when invalid transition (undefined destination)" do
    gear = %GearSchema{state: "neutral"}

    defmodule GearboxMachine do
      use Gearbox,
        states: ~w(neutral drive),
        transitions: %{
          "neutral" => ~w(drive)
        }
    end

    assert {:error, %Ecto.Changeset{} = err_changeset} = Gearbox.Ecto.transition_changeset(gear, GearboxMachine, "undefined")
    assert !err_changeset.valid?
    assert Keyword.has_key?(err_changeset.errors, :state)
    {msg, _addl} = err_changeset.errors[:state]
    assert msg =~ "Cannot transition from"
  after
    purge(GearboxMachine)
  end

  defp purge(module) do
    :code.delete(module)
    :code.purge(module)
  end
end
