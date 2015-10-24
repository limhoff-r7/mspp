defmodule MSPP.Packet do
  @moduledoc """
  Packet sent to or received from a payload.
  """
  defstruct [:method, :length_type_values, :type]

  @typedoc """
  Packet sent to or receive from a payload. Composed of one or more LTV
  (`lenght_type_value`)s with an `type` that distinguished requests and
  responses.  The `method` to run.
  """
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
  A request packet for `method` to send to the payload.
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
