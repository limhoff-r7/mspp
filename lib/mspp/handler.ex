defmodule MSPP.Handler do
  @moduledoc """
  Handles connections to/from payloads
  """

  @behaviour :ranch_protocol

  require Logger

  # Client Interface

  @doc """
  Starts handler for the given `socket` using the given `transport`.  `socket`
  is accepted (using `:ranch.accept_ack/1`) using `ref`.  `opts` are ignored.
  """
  @spec start_link(:ranch.ref, any, module, any) :: {:ok, pid}
  def start_link(ref, socket, transport, _opts) do
    pid = spawn_link(__MODULE__, :init, [ref, socket, transport])

    {:ok, pid}
  end

  @doc """
  1. Accepts the `socket` using `ref`.
  2. Enable NODELAY.
  3. Sends a "core_machind_id" request to payload to get
     `%MSPP.Session.machine_id`
  4. Enters receive `loop/1`
  """
  @spec init(:ranch.ref, any, module) :: no_return
  def init(ref, socket, transport) do
    :ok = :ranch.accept_ack(ref)
    transport.setopts(socket, [nodelay: :true])
    Process.flag(:trap_exit, true)

    request = MSPP.Packet.request("core_machine_id")

    %MSPP.Session{socket: socket, transport: transport}
    |> MSPP.Session.send(request)
    |> loop
  end

  # Private Functions

  @spec loop(MSPP.Session.t) :: no_return
  defp loop(session = %MSPP.Session{socket: socket, transport: transport}) do
    case transport.recv(socket, 0, :infinity) do
      { :ok, partial_response_tail } ->
        partial_response = session.partial_response <> partial_response_tail

        { packet, new_partial_response } = MSPP.Packet.parse(partial_response)

        if packet do
          Logger.debug "Parsed: #{inspect packet}"
        end

        Logger.debug(
          "New partial response: " <>
          inspect(new_partial_response, limit: byte_size(new_partial_response))
        )

        new_session = %MSPP.Session{
                        session | partial_response: new_partial_response
                      }

        loop(new_session)
      unknown ->
        Logger.error "Received #{inspect unknown}"
        shutdown(socket, transport)
    end
  end

  @spec shutdown(any, module) :: :ok
  defp shutdown(socket, transport) do
    :ok = transport.close(socket)
  end
end
