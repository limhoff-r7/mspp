defmodule MSPP.LengthTypeValue do
  @moduledoc """
  Meterpreter's version of TLV (Type Length Value), which is actually encoded
  as length, then type, then value, or LTV.
  """

  use Bitwise
  require MSPP.Type

  defstruct compress: false, value: nil, type: nil

  @typedoc """
  * `:compress` - whether to ZLib Deflate the `:value` in `to_binary/1`
  * `:value` - binary content
  * `:type` - bit flags that tag `:value`
  """
  @type t :: %__MODULE__{
               compress: boolean,
               value: binary,
               type: MSPP.Type.t
             }

  @doc """
  Compresses `uncompressed` binary if flag is `true`.  Returns `{type, binary}`
  where `type` should be `Bitwise.|||/2`ed with original `t.type`.
  """
  @spec compress(binary, boolean) :: {MSPP.Type.t, binary}

  def compress(uncompressed, false), do: {0, uncompressed}

  def compress(uncompressed, true) do
    z_stream = :zlib.open
    :ok = :zlib.deflateInit(z_stream)
    compressed = :zlib.deflate(z_stream, uncompressed)
    :zlib.close(z_stream)

    uncompressed_byte_size = byte_size uncompressed
    compressed_byte_size = byte_size compressed

    if compressed_byte_size < uncompressed_byte_size do
      {
        MSSP.Type.meta(:compressed),
        # uncompressed length has to be included for inflation in meterpreter,
        # so it can pre-allocate inflated size buffer.
        << MSP.Length.to_binary(uncompressed_byte_size), compressed >>
      }
    else
      compress(uncompressed, false)
    end
  end

  @doc """
  Decompresses `value` if `type` has compressed meta type set.

  Returns `{ compressed, uncompressed_type, decompressed_value }`.
  """
  @spec decompress(MSPP.Type.t, binary) :: { boolean, MSPP.Type.t, binary }
  def decompress(type, value) when MSPP.Type.meta_name?(type, :compressed) do
    uncompressed_type = type ^^^ MSPP.Type.meta_value(:compressed)

    z_stream = :zlib.open
    :ok = :zlib.inflateInit(z_stream)
    decompressed_value = :zlib.inflate(z_stream, value)
    :zlib.close(z_stream)

    { true, uncompressed_type, decompressed_value }
  end

  def decompress(type, value), do: { false, type, value }

  @doc """
  Methods act like RPC calls where a response is expected matching the request
  method.
  """
  @spec method(String.t) :: t
  def method(method) do
    %__MODULE__{
      value: method,
      type: MSPP.Type.value(:method)
    }
  end

  @doc """
  Parses `buffer` for complete LTV.  The returned tuple `{ltv, rest}` has the
  parsed `t` if `buffer` was long enough or `nil` otherwise.  `rest` is tail of
  `buffer` not consumed by `tlv`.
  """
  @spec parse(binary) :: { t | nil, binary }
  def parse(buffer) do
    case parse_type_value(buffer) do
      { nil, buffer } ->
        { nil, buffer }
      { { type, value }, rest } ->
        { compress, uncompressed_type, decompressed_value } = decompress(type,
                                                                         value)
        parsed_value = parse(uncompressed_type, decompressed_value)

        {
          %__MODULE__{ compress: compress, value: parsed_value, type: type },
          rest
        }
    end
  end

  @doc """
  Parses `buffer` for all LTVs.  `buffer` must not contain any incomplete TLVs.
  """
  @spec parse_all(binary) :: [t]
  def parse_all(buffer) do
    parse_all(buffer, [])
  end

  @doc """
  Parses `bufer` for complete LTV.  The returned tuple `{{type, value}, rest}`
  has the `type` and `value` of a `t` if the buffer was long enough ot `nil`
  otherwise.  `rest` is tail of `buffer` not consumed by LTV.
  """
  @spec parse_type_value(binary) :: { { MSPP.Type.t, binary } | nil, binary }
  def parse_type_value(buffer = << length :: big-size(32),
                                   type_value_rest :: binary >>) do
    value_length = length - MSPP.Length.byte_size - MSPP.Type.byte_size

    case type_value_rest do
      << type :: big-size(32),
         value :: binary-size(value_length),
         rest :: binary >> ->
        {
          { type, value },
          rest
        }
      _ ->
        { nil, buffer }
    end
  end

  def parse_type_value(<< rest :: binary >>) do
    { nil, rest }
  end

  @doc """
  Requests require a unique ID that gets returned with their response so the
  two can be correlated.
  """
  @spec request_id :: %__MODULE__{value: String.t}
  def request_id do
    %__MODULE__{
      value: request_id_value,
      type: MSPP.Type.value(:request_id)
    }
  end

  @doc """
  Requests IDs by convention from the Ruby implementation in
  metasploit-framework are random 32-digit decimal integers in a `String.t`
  """
  @spec request_id_value :: String.t
  def request_id_value do
    Enum.map_join(1..32, fn _ -> random_digit end)
  end

  @doc """
  Converts `%MSPP.LengthTypeValue{}` to its on-the-wire representation for
  sending to the payload.
  """
  @spec to_binary(t) :: binary
  def to_binary(%__MODULE__{compress: compress, value: value, type: type}) do
    uncompressed = case MSPP.Type.meta_name(type) do
      :string ->
        << value :: binary, 0 :: size(8) >>
    end

    {compression_type, compressed} = compress(uncompressed, compress)

    to_binary(compression_type ||| type, compressed)
  end

  @doc """
  Calculates length of `value` and composes that length, the `value`, and the
  `type` into the on-the-wire representation for sending to the payload.
  """
  @spec to_binary(MSPP.Type.t, binary) :: binary
  def to_binary(type, value) when is_integer(type) and
                                  is_binary(value) do
    length = MSPP.Length.byte_size + MSPP.Type.byte_size + byte_size(value)

    MSPP.Length.to_binary(length) <> MSPP.Type.to_binary(type) <> value
  end

  # Private Functions

  @spec parse(MSPP.Type.t, binary) :: binary
  defp parse(type, c_string) when MSPP.Type.meta_name?(type, :string) do
    c_string_byte_size = byte_size(c_string)

    if c_string_byte_size > 0 do
      string_byte_size = c_string_byte_size - 1
      << string :: binary-size(string_byte_size), 0 >> = c_string

      string
    else
      << >>
    end
  end

  defp parse(type, << unsigned_integer :: unsigned-integer-size(32) >>)
       when MSPP.Type.meta_name?(type, :unsigned_integer) do
    unsigned_integer
  end

  defp parse_all(<< buffer :: binary >>, length_type_values) do
    # NOTE: entire buffer will be parsed after all recursion, so don't list
    # `{ nil, << rest :: binary >> }` as that is an error
    case parse(buffer) do
      { nil, << >> } ->
        :lists.reverse length_type_values
      { length_type_value = %__MODULE__{}, << rest :: binary >> } ->
        parse_all(rest, [ length_type_value | length_type_values ])
    end
  end

  @spec random_digit :: String.t
  defp random_digit do
    to_string(:rand.uniform(10) - 1)
  end

  # Implementations

  defimpl Inspect do
    def inspect(packet, opts) do
      Inspect.Algebra.nest inspect(packet, packet.__struct__, opts), 1
    end

    # Private

    defp inspect(%MSPP.LengthTypeValue{type: type, value: value},
                 name,
                 opts) do
      Inspect.Algebra.surround_many(
        "%" <> Inspect.Atom.inspect(name, opts) <> "{",
        [
          type: type,
          value: value
        ],
        "}",
        opts,
        &to_keyword_list/2
      )
    end

    defp key_to_binary(key) do
      case Inspect.Atom.inspect(key) do
        ":" <> right -> right
        other -> other
      end
    end

    defp to_keyword_list({ key = :type, type }, _opts) do
      Inspect.Algebra.concat(
        key_to_binary(key) <> ": ",
        Inspect.Algebra.surround(
          "MSPP.Type.value(",
          type |> MSPP.Type.name |> inspect,
          ")"
        )
      )
    end

    defp to_keyword_list({ key = :value, length_type_values },
                         opts) do
      Inspect.Algebra.concat(
        key_to_binary(key) <> ": ",
        Inspect.Algebra.to_doc(length_type_values, opts)
      )
    end
  end
end
