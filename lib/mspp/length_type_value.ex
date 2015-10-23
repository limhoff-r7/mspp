defmodule MSPP.LengthTypeValue do
  @moduledoc """
  Meterpreter's version of TLV (Type Length Value), which is actually encoded
  as length, then type, then value, or LTV.
  """

  use Bitwise

  defstruct compress: false, value: nil, type: nil

  @type t :: %__MODULE__{
               compress: boolean,
               value: binary,
               type: MSPP.Type.t
             }

  @doc """
  Compresses `uncompressed` binary if flag is `true`.  Returns {type, binary}
  where type should be `Bitwise.|||/2`ed with original type.
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

  @spec method(String.t) :: t
  def method(method) do
    %__MODULE__{
      value: method,
      type: MSPP.Type.type(:method)
    }
  end

  def request_id do
    %__MODULE__{
      value: request_id_value,
      type: MSPP.Type.type(:request_id)
    }
  end

  def request_id_value do
    Enum.map_join(1..32, fn _ -> random_digit end)
  end

  def to_binary(%__MODULE__{compress: compress, value: value, type: type}) do
    uncompressed = case MSPP.Type.meta(type) do
      :string ->
        << value :: binary, 0 :: size(8) >>
    end

    {compression_type, compressed} = compress(uncompressed, compress)

    to_binary(compression_type ||| type, compressed)
  end

  def to_binary(type, value) when is_integer(type) and
                                  is_binary(value) do
    length = MSPP.Length.byte_size + MSPP.Type.byte_size + byte_size(value)

    MSPP.Length.to_binary(length) <> MSPP.Type.to_binary(type) <> value
  end

  # Private Functions

  defp random_digit do
    to_string(:rand.uniform(10) - 1)
  end
end
