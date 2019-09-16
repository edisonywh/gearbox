# For doctest purpose
defmodule Gearbox.OrderMachine do
  use Gearbox,
    field: :status,
    states: ~w(pending_payment cancelled paid pending_collection refunded fulfilled),
    initial: "pending_payment",
    transitions: %{
      "pending_payment" => ~w(cancelled paid),
      "paid" => ~w(pending_collection refunded)
    }
end
