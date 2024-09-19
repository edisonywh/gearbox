defmodule Gearbox do
  @moduledoc """
  Gearbox is a functional state machine with an easy-to-use API, inspired by both
  [Fsm](https://github.com/sasa1977/fsm) and [Machinery](https://github.com/joaomdmoura/machinery).

  Gearbox does not run in a process, so there's no potential for a GenServer bottleneck.
  This way there's also less overhead as you won't need to setup a supervision tree/manage your state machine processes.

  > Note: Gearbox is heavily inspired by [Machinery](https://github.com/joaomdmoura/machinery),
    and also took inspiration from [Fsm](https://github.com/sasa1977/fsm).

  Gearbox is **very** similar to [Machinery](https://github.com/joaomdmoura/machinery) in term of
  the API usage, however it differs in the ways below:

  - **Gearbox does not use a GenServer as a backing process**.
    Since GenServer can be a potential bottleneck in a system, for that reason I think it's best
    to leave process management to users of the library.
  - **No before/after callbacks**. Callback allow you to add side effects, but side effects violate
    Single Responsibility Principle, and that can bring surprises to your codebase
    (e.g: "How come everytime this transition happens, X happens?"). Gearbox nudges you to keep domain-logic
    callbacks close to your contexts/domain events. Gearbox still ships with a `guard_transition/3` callback,
    as that is intrinsic to state machines.
  - Gearbox does not ship with a `Phoenix Dashboard` view.
    A really cool and great concept, but more often than not it is not needed and the added dependency
    can prove more trouble than worth.

  ## Rationale

  Gearbox operates on the philosophy that it acts purely as a functional state machine, wherein
  it does not care where your state is store (e.g: Ecto, GenServer), all Gearbox does is to help you
  ensure state transitions happen the way you expect it to.

  In most cases like for example `Order`, it is very likely that you don't need a process for that.
  Just get the record out of the database, run it through Gearbox machine, then persist it back to database.

  In some rare cases where you need to have a stateful state machine, for example a traffic light
  that has an internal timer to shift from `red` (30s) -> `green` (30s) -> `yellow` (5s) -> `red`,
  you are better off to use an `Agent`/`GenServer` where you have better control over backpressuring/
  business logics.

  As of now, Gearbox does not provide a way to create `events/actions` in a state machine.
  This is because Gearbox is not a domain/context wrapper, Events and actions that can
  trigger a state change should reside closer to your contexts, therefore I urge users to
  group these events as domain events (contexts), rather than state machine events.

  Gearbox previously shipped with `before_transition/3` and `after_transition/3` in `0.1.0`,
  but after some discussions I have decided to take a deliberate decision to **remove** callbacks.
  This is because callbacks by nature, allow you to add side effects, but side effects violate
  **Single Responsibility Principle**, and callbacks can often bring unintended surprises
  to your codebase (e.g: "How come everytime this transition happens, X happens?").

  Therefore, Gearbox nudges you to keep domain/business-logic callbacks close to your contexts/domain events.
  Gearbox still ships with a `guard_transition/3` callback, as that is intrinsic to state machines.

  ## Options
    - `:field` - used to retrieve the state of the given struct. Defaults to `:state`
    - `:states` - list of finite states in the state machine
    - `:initial` - initial state of the struct, if struct has `nil` state to begin with.
      Defaults to the first item of `:states`
    - `:transitions` - a map of possible transitions from `current_state` to `next_state`.
      `*` wildcard is allowed to indicate any states.

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

  ## Ecto Example

      {:ok, order} = Gearbox.transition(%Order{status: "pending_payment"}, OrderMachine, "paid")
      Repo.insert!(order)

      # or even

      %Order{status: "pending_payment"}
      |> Gearbox.transition!(OrderMachine, "paid")
      |> Repo.insert!()
  """

  @type state() :: atom | String.t()

  @doc """
  Add guard conditions before transitioning.

  The function receives struct as the first argument, the current state as
  the second argument, and the desired state as the last argument.

  You can guard on both `from` and `to` states, e.g:

  * Every time %Order{} transits out of `pending`, do X
  * Every time %Order{} transits into `paid`, do Y

  If this function returns a `{:halt, reason}`, execution of the transition will halt.
  Any other things will allow the transition to go through.

  > Note: This hook only gets triggered if the transition is valid.
  """
  @callback guard_transition(struct :: any, from :: state(), to :: state()) :: {:halt, any} | any

  @wildcard "*"

  defmodule InvalidTransitionError do
    @moduledoc """
    This error is raised when you use `Gearbox.transition!/3`.

    For a non-error raising variant, see `Gearbox.transition/3`
    """
    defexception message: "State transition is not allowed."
  end

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
      def guard_transition(struct, from, to), do: struct

      defoverridable guard_transition: 3
    end
  end

  @doc """
  Transition a struct or map to a given state. If transition is invalid, an `InvalidTransitionError` exception is raised.

  Uses `Gearbox.transition/3` under the hood.
  """
  @spec transition!(struct :: struct | map, machine :: any, next_state :: state()) :: struct | map
  def transition!(struct, machine, next_state) do
    case transition(struct, machine, next_state) do
      {:error, msg} ->
        raise InvalidTransitionError, message: msg

      {:ok, result} ->
        result
    end
  end

  @doc false
  defguardp is_guard_allowed?(condition)
            when not (is_tuple(condition) and elem(condition, 0) == :halt and
                        tuple_size(condition) == 2)

  @doc """
  Transition a struct or a map to a given state.

  Returns an `{:ok, updated_struct_or_map}` or `{:error, message}` tuple.
  """
  @spec transition(struct :: struct | map, machine :: any, next_state :: state()) ::
          {:ok, struct | map} | {:error, String.t()}
  def transition(struct, machine, next_state) do
    case validate_transition(struct, machine, next_state) do
      {:ok, nil} ->
        struct = Map.put(struct, machine.__machine_field__(), next_state)
        {:ok, struct}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Checks if the transition should be made.
  Mainly for internal use to support `transition/3` and other methods performing transition actions.

  Returns a tuple containing the outcome:
    - `{:ok, nil}` if it can transition or,
    - `{:error, reason}` if transition cannot be made.
  """
  @spec validate_transition(struct :: struct | map, machine :: any, next_state :: state()) ::
          {:ok, any} | {:error, String.t()}
  def validate_transition(struct, machine, next_state) do
    field = machine.__machine_field__()
    states = machine.__machine_states__()
    initial_state = machine.__machine_states__(:initial)
    current_state = Map.get(struct, field) || initial_state
    transitions = machine.__machine_transitions__()

    with candidates <- Map.take(transitions, [current_state, @wildcard]),
         possible_transitions = get_possible_transitions(candidates, states),
         true <- next_state in possible_transitions,
         condition when is_guard_allowed?(condition) <-
           machine.guard_transition(struct, current_state, next_state) do
      {:ok, nil}
    else
      false ->
        reason = "Cannot transition from `#{current_state}` to `#{next_state}`"

        {:error, reason}

      {:halt, reason} ->
        {:error, reason}
    end
  end

  @spec get_possible_transitions(candidates :: map(), states :: list(state())) :: list()
  defp get_possible_transitions(candidates, states) do
    Enum.reduce(candidates, [], fn {_k, destination}, acc ->
      destination |> cast_destination(states) |> List.flatten(acc)
    end)
  end

  @spec cast_destination(dest :: list() | String.t() | atom(), states :: list(state())) :: list()
  defp cast_destination(@wildcard, states), do: states
  defp cast_destination(dest, _states) when is_list(dest), do: dest
  defp cast_destination(dest, _states) when is_binary(dest), do: [dest]
  defp cast_destination(dest, _states) when is_atom(dest), do: [dest]
end
