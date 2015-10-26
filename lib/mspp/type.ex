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

  @typedoc """
  32 bitflags representing metatype and type
  of `MSPP.LengthTypeValue.to_binary/1`.
  """
  @type t :: integer

  # Macros

  # **NOTE: Does NOT contain `%{none: 0}` because 0 would win for masking checks
  @meta_value_by_name %{
    compressed:       1 <<< 29,
    none:                    0,
    string:           1 <<< 16,
    unsigned_integer: 1 <<< 17
  }

  @doc """
  **NOTE: Can be used in guards.**

  Checks if the a `t` `type` has the given `name` as passed to `value/1`.
  """
  @spec meta_name?(t, atom) :: boolean
  defmacro meta_name?(type, name) do
    name_meta_value = meta_value(name)

    quote do
      is_integer(unquote(type)) and
      (unquote(type) &&& unquote(name_meta_value)) == unquote(name_meta_value)
    end
  end

  # Functions

  @doc """
  Number of bits in type portion of `MSPP.LengthTypeValue.to_binary/1`
  """
  @spec bit_size :: integer
  def bit_size, do: @bit_size

  @doc """
  Number of bytes in type portion of `MSPP.LengthTypeValue.to_binary/1`
  """
  @spec byte_size :: integer
  def byte_size, do: div(@bit_size, @bits_per_byte)

  @doc """
  Meta type includes whether the value is compressed with ZLib Deflate
  (`:compressed`) and the format, such as `String.t` (`:string`).
  """
  @spec meta_value(atom) :: t

  for { name, value } <- @meta_value_by_name do
    def meta_value(unquote(name)), do: unquote(value)
  end

  @doc """
  Name of meta type (upper 16-bits of type).
  """
  @spec meta_name(t) :: atom

  for { name, value } <- @meta_value_by_name, name != :none do
    def meta_name(type) when is_integer(type) and
                             (type &&& unquote(value)) == unquote(value) do
      unquote(name)
    end
  end

  # MUST be done manually as no bits being set uses a full mask for meta
  # bitfields instead of single-bit mask
  def meta_name(type)
      when is_integer(type) and
           (type &&& 0b1111_1111_1111_1111_0000_0000_0000_000) == 0 do
    :none
  end

  @value_by_name %{
    any:        @meta_value_by_name.none             |||   0,
    machine_id: @meta_value_by_name.string           ||| 460,
    method:     @meta_value_by_name.string           |||   1,
    request_id: @meta_value_by_name.string           |||   2,
    result:     @meta_value_by_name.unsigned_integer |||   4
  }

  for { name, value } <- @value_by_name do
    def name(unquote(value)), do: unquote(name)
  end

  def to_binary(type) when is_integer(type) and
                           type >= 0 and
                           type <= ((1 <<< @bit_size) - 1) do
    << type :: big-size(@bit_size) >>
  end

  @doc """
  The `t` value for the given `name`.
  """
  @spec value(name) :: t when name: atom

  for { name, value } <- @value_by_name do
    def value(unquote(name)), do: unquote(value)
  end
end
