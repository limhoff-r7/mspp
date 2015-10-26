defmodule MSPP.LengthTypeValue do
  @moduledoc """
  Meterpreter's version of TLV (Type Length Value), which is actually encoded
  as length, then type, then value, or LTV.
  """

  use Bitwise

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
        {
          %__MODULE__{ value: value, type: type },
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
end
