defmodule MSPP.Packet do
  @moduledoc """
  Packet sent to or received from a payload.
  """

  # Types

  defstruct [:length_type_values, :type]

  @typedoc """
  Packet sent to or receive from a payload. Composed of one or more LTV
  (`lenght_type_value`)s with an `type` that distinguished requests and
  responses.  The `method` to run.
  """
  @type t :: %__MODULE__{
               length_type_values: [],
               type: integer
             }

  # Functions

  @doc """
  Parses `buffer` for complete packet.  The part of the buffer that was not
  consumed by the returned packet is returned as the element of the returned
  tuple.
  """
  @spec parse(binary) :: { t | nil, binary }
  def parse(buffer) do
    case MSPP.LengthTypeValue.parse_type_value(buffer) do
      { { type, value  }, rest } ->
        {
          %__MODULE__{
            type: type,
            length_type_values: MSPP.LengthTypeValue.parse_all(value)
          },
          rest
        }
      { nil, buffer } ->
        { nil, buffer }
    end
  end

  @doc """
  A request packet for `method` to send to the payload.
  """
  @spec request(String.t) :: t
  def request(method) do
    %__MODULE__{
      length_type_values: [
        MSPP.LengthTypeValue.method(method),
        MSPP.LengthTypeValue.request_id
      ],
      type: MSPP.Type.type(:request)
    }
  end

  @doc """
  Converts the `packet` to binary suitable to sending to the payload
  """
  @spec to_binary(t) :: binary
  def to_binary(%__MODULE__{
                  length_type_values: length_type_values,
                  type: type
                }) do
    value = Enum.map_join(
      length_type_values,
      &MSPP.LengthTypeValue.to_binary/1
    )

    MSPP.LengthTypeValue.to_binary(type, value)
  end

  defimpl Inspect do
    def inspect(packet, opts) do
      Inspect.Algebra.nest inspect(packet, packet.__struct__, opts), 1
    end

    # Private

    defp inspect(%MSPP.Packet{length_type_values: length_type_values,
                              type: type},
                 name,
                 opts) do
      Inspect.Algebra.surround_many(
        "%" <> Inspect.Atom.inspect(name, opts) <> "{",
        [
          length_type_values: length_type_values,
          type: type
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

    defp to_keyword_list({ key = :length_type_values, length_type_values },
                         opts) do
      Inspect.Algebra.concat(
        key_to_binary(key) <> ": ",
        Inspect.Algebra.to_doc(length_type_values, opts)
      )
    end

    defp to_keyword_list({ key = :type, type }, _opts) do
      Inspect.Algebra.concat(
        key_to_binary(key) <> ": ",
        Inspect.Algebra.surround(
          "MSPP.Type.type(",
          type |> MSPP.Type.name |> inspect,
          ")"
        )
      )
    end
  end
end
