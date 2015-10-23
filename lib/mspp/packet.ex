defmodule MSPP.Packet do
  @moduledoc """
  Packet sent to or received from a packet.  Composed of one or more TLVs.
  """
  defstruct [:method, :length_type_values, :type]

  @type t :: %__MODULE__{
               method: String.t,
               length_type_values: [],
               type: integer
             }

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

  @doc """
  A request packet to send to the payload.
  """
  @spec request(method) :: %__MODULE__{method: method} when method: String.t
  def request(method) do
    %__MODULE__{
      length_type_values: [
        MSPP.LengthTypeValue.method(method),
        MSPP.LengthTypeValue.request_id
      ],
      type: MSPP.Type.type(:request)
    }
  end
end
