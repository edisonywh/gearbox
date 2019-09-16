# Gearbox

Gearbox is a functional state machine with an easy-to-use API, inspired by both
[Fsm](https://github.com/sasa1977/fsm) and [Machinery](https://github.com/joaomdmoura/machinery).

Gearbox does not run in a process, so there's no potential for a GenServer bottleneck.
This way there's also less overhead as you won't need to setup a supervision tree/manage your state machine processes.

> Note: Gearbox is heavily inspired by [Machinery](https://github.com/joaomdmoura/machinery),
> and also took inspiration from [Fsm](https://github.com/sasa1977/fsm).

Gearbox is **very** similar to [Machinery](https://github.com/joaomdmoura/machinery) in term of
the API usage, however it differs in the ways below:

- **Gearbox does not use a GenServer as a backing process**.
  Since GenServer can be a potential bottleneck in a system, for that reason I think it's best
  to leave process management to users of the library.
- `before_transition/3` and `after_transition/3` exposes the `current_state` and also `next_state`,
  providing more options when defining callbacks.
- Gearbox does not ship with a `Phoenix Dashboard` view.
  A really cool and great concept, but more often than not it is not needed and the added dependency
  can prove more trouble than worth.

For a more detailed documentation, checkout the HexDoc - [https://hexdocs.pm/gearbox](https://hexdocs.pm/gearbox).

## Installation

Get the latest version from [Hex](https://hex.pm/packages/gearbox)

```elixir
def deps do
  [
    {:gearbox, "~> 0.1.0"}
  ]
end
```

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
This is because Gearbox is not a domain/context wrapper, I feel events/actions
that can trigger a state change should reside closer to your contexts, therefore I urge
users to group these events as domain events (contexts), rather than state machine events.

## Features
Below lists a couple of features that Gearbox currently have.

### State Transitions
The core of Gearbox. Allows you to transition a state from one to another (managed by your own machine).

```elixir
defmodule Commerce do
  def pay(user, order) do
    # ...
    # Your payment logic
    {:ok, updated_order} = Gearbox.transition(order, PaymentMachine, "paid")
    # ...
  end
end
```

There's also a `bang!` variant of transition, `Gearbox.transition!/3`, so you can rewrite your code to like so:

```elixir
defmodule Commerce do
  def pay(user, order) do
    # ...
    # Your payment logic
    order
    |> Gearbox.transition!(PaymentMachine, "paid")
    |> Repo.insert!
  end
end
```

### Callbacks (Before & After)
Callbacks provide you hooks to execute `before` and `after` a transition happens/happened.

- `before_transition/3`
- `after_transition/3`

> **Note** that callbacks should always return `struct`, and callbacks will only be run if transition is valid.

### Guard Transitions
Guard transitions enforces a condition to be passed before a transitions is committed.

A transition is halted if the function returns `{:halt, reason}`, it continues otherwise.
It will then return `{:error, reason}` for `Gearbox.transition/3`

```elixir
# You can match on both `from` and `to` states.
def guard_transition(struct, _from, _to) do
  case :rand.uniform() do
    val when val >= 0.5 ->
      # You can return anything
    _ ->
      {:halt, "You have been snapped."}
  end
end
```

> **Note** that guard transitions will only be run if transition is valid.

## Contributions
Contributions are very welcomed, but please first [open an issue](https://github.com/edisonywh/gearbox/issues/new) so we can align and discuss before any development begins.

## License

View [License](https://github.com/edisonywh/gearbox/blob/master/LICENSE)
