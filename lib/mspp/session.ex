defmodule MSPP.Session do
  @moduledoc """
  A session from a payload
  """

  require MSPP.Type

  defstruct machine_id: nil, requests: [], socket: nil, transport: nil
  @type t :: %__MODULE__{
               machine_id: String.t,
               requests: [MSPP.Packet.t],
               socket: any,
               transport: module
             }

  def send(session = %__MODULE__{socket: socket, transport: transport},
           request = %MSPP.Packet{type: type})
           when MSPP.Type.type?(type, :request) do
    transport.send(socket, MSPP.Packet.to_binary(request))

    %{session | requests: [request | session.requests]}
  end
end
