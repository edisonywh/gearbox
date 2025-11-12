# For doctest purpose
defmodule Gearbox.OrderMachine do
  @behaviour Gearbox.Machine

  def field, do: :status
  def states, do: ~w(pending_payment cancelled paid pending_collection refunded fulfilled)
  def initial_state, do: "pending_payment"

  def transitions do
    %{
      "pending_payment" => ~w(cancelled paid),
      "paid" => ~w(pending_collection refunded)
    }
  end
end
