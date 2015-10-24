defmodule MSPP.Session do
  @moduledoc """
  A session from a payload
  """

  require MSPP.Type

  defstruct machine_id: nil, requests: [], socket: nil, transport: nil

  @typedoc """
  State about connected payload session.

  * `:machine_id` - machine id as returned from
    `MSPP.Packet.request("core_machine_id")`
  * `:requests` - requests sent to payload over `:socket` using `:transport`
     that are awaiting a response.
  * `:socket` - ranch listening socket connected to payload.
  * `:transport` - ranch transport Module used to manipulate `:socket`
  """
  @type t :: %__MODULE__{
               machine_id: String.t,
               requests: [MSPP.Packet.t],
               socket: any,
               transport: module
             }

  @doc """
  Sends `request` to `session`.

  Returns new `MSPP.Session.t` with `request` added to `:requests`.
  """
  @spec send(t, MSPP.Packet.t) :: t
  def send(session = %__MODULE__{socket: socket, transport: transport},
           request = %MSPP.Packet{type: type})
           when MSPP.Type.type?(type, :request) do
    transport.send(socket, MSPP.Packet.to_binary(request))

    %{session | requests: [request | session.requests]}
  end
end
