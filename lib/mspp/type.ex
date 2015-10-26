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

  @doc """
  Checks if the a `t` `type` has the given `name` as passed to `type/1`.  Can
  be used in guards.
  """
  @spec type?(t, atom) :: boolean
  defmacro type?(type, name) do
    value = type(name)

    quote do
      (unquote(type) &&& unquote(value)) == unquote(value)
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
  @spec meta(atom) :: t
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

  def to_binary(type) when is_integer(type) and
                           type >= 0 and
                           type <= ((1 <<< @bit_size) - 1) do
    << type :: big-size(@bit_size) >>
  end

  @doc """
  Type includes whether a `MSPP.Packet` is a request (`:request`) or a response
  and also the subsection types, such a `:method` or `:request_id`.
  """
  @spec type(name) :: t when name: atom
  def type(:method), do: meta(:string) ||| 1
  def type(:request_id), do: meta(:string) ||| 2
end
