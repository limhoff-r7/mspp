defmodule MSPP.Length do
  @moduledoc """
  The length in `MSPP.LengthTypeValue`.
  """

  use Bitwise

  # CONSTANTS

  @bit_size 32
  @bits_per_byte 8
  @maximum (1 <<< @bit_size) - 1
  @minimum 0

  # Types

  @typedoc """
  32-bit byte count of `MSPP.LengthTypeValue.to_binary/1`.  Includes byte size
  of the length field itself, the type field, and the value.
  """
  @type t :: integer

  # Functions

  @doc """
  Number of bits in length portion of `MSPP.LengthTypeValue.to_binary/1`
  """
  @spec bit_size :: integer
  def bit_size, do: @bit_size

  @doc """
  Number of bytes in length portion of `MSPP.LengthTypeValue.to_binary/1`
  """
  @spec byte_size :: integer
  def byte_size, do: div(@bit_size, @bits_per_byte)

  @doc """
  Converts 32-bit length to its on-the-wire format in
  `MSPP.LengthTypeValue.to_binary/1`.
  """
  def to_binary(length) when is_integer(length) and
                             length >= @minimum and
                             length <= @maximum do
    << length :: big-size(@bit_size) >>
  end
end
