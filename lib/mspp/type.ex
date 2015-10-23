defmodule MSPP.Type do
  @moduledoc """
  The types in `MSPP.LengthTypeValue`.
  """

  use Bitwise

  # Constants

  @bit_size 32
  @bits_per_byte 8
  @maximum (1 <<< @bit_size) - 1
  @minimum 0

  # Types

  @type t :: integer

  # Functions

  def bit_size, do: @bit_size
  def byte_size, do: div(@bit_size, @bits_per_byte)

  def meta(:compressed), do: 1 <<< 29
  def meta(:string), do: 1 <<< 16

  @doc """
  Extracts the format metatype from the `type`.
  """
  @spec meta(integer) :: :string | nil
  def meta(type) when is_integer(type) do
    Enum.find(
      [:string],
      fn (meta_name) ->
        meta_type = meta(meta_name)
        (type &&& meta_type) == meta_type
      end
    )
  end

  def type(:method), do: meta(:string) ||| 1
  def type(:request), do: 0
  def type(:request_id), do: meta(:string) ||| 2

  def to_binary(type) when is_integer(type) and
                           type >= 0 and
                           type <= ((1 <<< @bit_size) - 1) do
    << type :: big-size(@bit_size) >>
  end
end
