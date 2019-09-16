defmodule Gearbox do
  @moduledoc """
  -- Insert moduledoc

  If no initial state is defined, the first item in the list of `states` will be used as initial.

  -- show some examples about usage with Ecto usage and with Process-backed usage

  ## Example

     defmodule Gearbox.Order do
        defstruct items: [], total: 0, status: nil
      end


      defmodule Gearbox.OrderMachine do
        use Gearbox,
          field: :status,
          states: ~w(pending_payment cancelled paid pending_collection refunded fulfilled),
          initial: "pending_payment",
          transitions: %{
            "pending_payment" => ~w(cancelled paid),
            "paid" => ~w(pending_collection refunded),
          }
      end

      iex> alias Gearbox.Order # Your struct
      iex> alias Gearbox.OrderMachine # Your machine
      iex> Gearbox.transition(%Order{}, OrderMachine, "paid")
      {:ok, %Gearbox.Order{items: [], status: "paid", total: 0}}
  """

  @doc """
  Hooks that happen *before* a transition happens.

  The function receives struct as the first argument, the current state as
  the second argument, and the desired state as the last argument.

  You can do anything you want, the only requirement is to return a `struct`.

  > Note: This hook only gets triggered if the transition is valid.
  """
  @callback before_transition(
              struct :: struct,
              from :: atom | String.t(),
              to :: atom | String.t()
            ) :: struct

  @doc """
  Hooks that happen *after* a transition happens.

  The function receives struct as the first argument, the current state as
  the second argument, and the desired state as the last argument.

  You can do anything you want, the only requirement is to return a struct.

  > Note: This hook only gets triggered if the transition is valid.
  """
  @callback after_transition(struct :: struct, from :: atom | String.t(), to :: atom | String.t()) ::
              struct

  @doc """
  Add guard conditions before transitioning.

  The function receives struct as the first argument, the current state as
  the second argument, and the desired state as the last argument.

  You can guard on both current_state and next_state, e.g:

  * every time it transits out of `pending`, do X
  * every time it transits into `paid`, do X

  To **allow** a transition, return `{:ok, _anything}` tuple.
  To **disallow** a transition, return `{:halt, reason}` tuple.

  > Note: This hook only gets triggered if the transition is valid.
  """
  @callback guard_transition(struct :: any, from :: any, to :: any) :: {:halt, any} | any

  @wildcard "*"

  defmodule InvalidTransitionError do
    defexception message: "State transition is not allowed."
  end

  defguardp is_guard_allowed?(condition)
            when not (is_tuple(condition) and elem(condition, 0) == :halt and
                        tuple_size(condition) == 2)

  @doc false
  defmacro __using__(opts) do
    field = Keyword.get(opts, :field, :state)
    states = Keyword.get(opts, :states)
    initial = Keyword.get(opts, :initial)
    transitions = Keyword.get(opts, :transitions)

    quote bind_quoted: [
            field: field,
            states: states,
            initial: initial,
            transitions: transitions
          ] do
      @behaviour Gearbox

      @doc false
      def __machine_field__(), do: unquote(field)

      @doc false
      def __machine_states__(:initial), do: unquote(initial || List.first(states))

      @doc false
      def __machine_states__(), do: unquote(states)

      @doc false
      def __machine_transitions__(), do: unquote(Macro.escape(transitions))

      @doc false
      def before_transition(struct, from, to), do: struct

      @doc false
      def after_transition(struct, from, to), do: struct

      @doc false
      def guard_transition(struct, from, to), do: struct

      defoverridable before_transition: 3, after_transition: 3, guard_transition: 3
    end
  end

  @doc """
  Transition a struct to a given state. If transition is invalid, an `InvalidTransitionError` exception is raised.

  Uses `Gearbox.transition/3` under the hood.
  """
  @spec transition!(struct :: struct, machine :: any, next_state :: any) :: struct
  def transition!(struct, machine, next_state) do
    case transition(struct, machine, next_state) do
      {:error, msg} ->
        raise InvalidTransitionError, message: msg

      {:ok, result} ->
        result
    end
  end

  @doc """
  Transition a struct to a given state.

  returns an `{:ok, updated_struct}` or `{:error, message}` tuple.
  """
  @spec transition(struct :: struct, machine :: any, next_state :: any) ::
          {:ok, struct} | {:error, String.t()}
  def transition(struct, machine, next_state) do
    field = machine.__machine_field__
    states = machine.__machine_states__
    initial_state = machine.__machine_states__(:initial)
    current_state = Map.get(struct, field) || initial_state
    transitions = machine.__machine_transitions__

    with candidates <- Map.take(transitions, [current_state, @wildcard]),
         possible_transitions = get_possible_transitions(candidates, states),
         true <- next_state in possible_transitions,
         condition when is_guard_allowed?(condition) <-
           machine.guard_transition(struct, current_state, next_state) do
      struct =
        struct
        |> machine.before_transition(current_state, next_state)
        |> Map.put(field, next_state)
        |> machine.after_transition(current_state, next_state)

      {:ok, struct}
    else
      false ->
        reason = "Cannot transition from `#{current_state}` to `#{next_state}`"

        {:error, reason}

      {:halt, reason} ->
        {:error, reason}
    end
  end

  @spec get_possible_transitions(candidates :: map(), states :: list()) :: list()
  defp get_possible_transitions(candidates, states) do
    Enum.reduce(candidates, [], fn {_k, destination}, acc ->
      destination |> cast_destination(states) |> List.flatten(acc)
    end)
  end

  @spec cast_destination(dest :: list() | String.t(), states :: list()) :: list()
  defp cast_destination(@wildcard, states), do: states
  defp cast_destination(dest, _states) when is_list(dest), do: dest
  defp cast_destination(dest, _states) when is_binary(dest), do: [dest]
end
