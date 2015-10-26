defmodule MSPP.Packet.Type do
  @moduledoc """
  Type of `MSPP.Packet.t`
  """

  use Bitwise

  # Types

  @typedoc """
  A packet's type is a 32-bit big-endian integer used a bitfield, the same as
  `MSPP.Type`, but the field positions have different meanings.
  """
  @type t :: integer

  # Macros

  @doc """
  **NOTE: Can be used in guards.**

  Checks if the `MSPP.Packet.t` `type` has the given `name` as passed to
  `value/1`.
  """
  @spec type?(t, atom) :: boolean
  defmacro type?(type, name) do
    name_value = value(name)

    quote do
      (unquote(type) &&& unquote(name_value)) == unquote(name_value)
    end
  end

  # Functions

  @doc """
  Name passed to `value/1` to get `value`
  """
  @spec name(integer) :: atom
  def name(0), do: :request
  def name(1), do: :response

  @doc """
  Type value for the given `name`
  """
  def value(:request), do: 0
  def value(:response), do: 1
end