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

  @type t :: integer

  # Functions

  def bit_size, do: @bit_size
  def byte_size, do: div(@bit_size, @bits_per_byte)

  def to_binary(length) when is_integer(length) and
                             length >= @minimum and
                             length <= @maximum do
    << length :: big-size(@bit_size) >>
  end
end
