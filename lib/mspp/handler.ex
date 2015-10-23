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

  def init(ref, socket, transport, _Opts = []) do
    :ok = :ranch.accept_ack(ref)
    transport.setopts(socket, [nodelay: :true])
    Process.flag(:trap_exit, true)

    transport.send(
      socket,
      MSPP.Packet.request("core_machine_id")
      |> MSPP.Packet.to_binary
    )

    loop(socket, transport)
  end

  def loop(socket, transport) do
    case transport.recv(socket, 0, :infinity) do
      {:ok, packet} ->
        Logger.debug "Received #{inspect packet, limit: byte_size(packet)}"
        loop(socket, transport)
      unknown ->
        Logger.error "Received #{inspect unknown}"
        shutdown(socket, transport)
    end
  end

  # Private Functions

  defp shutdown(socket, transport) do
    :ok = transport.close(socket)
  end
end
