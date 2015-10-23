defmodule MSPP.Handler do
  @moduledoc """
  Handles connections to/from payloads
  """

  require Logger

  # Client Interface

  def start_link(ref, socket, transport, opts) do
    pid = spawn_link(__MODULE__, :init, [ref, socket, transport, opts])

    {:ok, pid}
  end

  # Private Functions

  def init(ref, socket, transport, _Opts = []) do
    :ok = :ranch.accept_ack(ref)
    transport.setopts(socket, [nodelay: :true])
    Process.flag(:trap_exit, true)

    request = MSPP.Packet.request("core_machine_id")

    %MSPP.Session{socket: socket, transport: transport}
    |> MSPP.Session.send(request)
    |> loop
  end

  defp loop(session = %MSPP.Session{socket: socket, transport: transport}) do
    case transport.recv(socket, 0, :infinity) do
      {:ok, packet} ->
        Logger.debug "Received #{inspect packet, limit: byte_size(packet)}"
        loop(session)
      unknown ->
        Logger.error "Received #{inspect unknown}"
        shutdown(socket, transport)
    end
  end

  defp shutdown(socket, transport) do
    :ok = transport.close(socket)
  end
end
