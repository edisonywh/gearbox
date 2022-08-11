if Code.ensure_loaded?(Ecto) do
  defmodule Gearbox.Ecto do
    @moduledoc """
    Ecto support module for Gearbox.

    This allows creation of Ecto changeset based on the result of the transition.
    """

    import Gearbox, only: [validate_transition: 3]

    @doc """
    Creates a changeset based on the transition outcome of an Ecto struct.

    Returns a tuple containing a changeset:
      - `{:ok, changeset}` with the transitioned field if the transition can be made
      - `{:error, error_changeset}` with an error populated if transition cannot be made.
    """
    @spec transition_changeset(struct :: struct, machine :: any, next_state :: Gearbox.state()) ::
            {:ok, struct | map} | {:error, Ecto.Changeset.t()}
    def transition_changeset(struct, machine, next_state) do
      validation_struct = maybe_apply_changeset_changes(struct)

      case validate_transition(validation_struct, machine, next_state) do
        {:ok, nil} ->
          changeset = Ecto.Changeset.change(struct, %{machine.__machine_field__ => next_state})
          {:ok, changeset}

        {:error, reason} ->
          error_changeset =
            struct
            |> struct()
            |> Ecto.Changeset.change()
            |> Ecto.Changeset.add_error(machine.__machine_field__, reason)

          {:error, error_changeset}
      end
    end

    defp maybe_apply_changeset_changes(%Ecto.Changeset{} = changeset),
      do: Ecto.Changeset.apply_changes(changeset)

    defp maybe_apply_changeset_changes(struct), do: struct
  end
end
