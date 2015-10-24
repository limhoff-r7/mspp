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
      type: MSPP.Type.type(:method)
    }
  end

  @doc """
  Requests require a unique ID that gets returned with their response so the
  two can be correlated.
  """
  @spec request_id :: %__MODULE__{value: String.t}
  def request_id do
    %__MODULE__{
      value: request_id_value,
      type: MSPP.Type.type(:request_id)
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
    uncompressed = case MSPP.Type.meta(type) do
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

  @spec random_digit :: String.t
  defp random_digit do
    to_string(:rand.uniform(10) - 1)
  end
end
