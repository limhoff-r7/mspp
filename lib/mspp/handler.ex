defmodule MSPP.Handler do
  @moduledoc """
  Handles connections to/from payloads
  """

  # Client Interface

  def start_link(ref, socket, transport, opts) do
    pid = spawn_link(__MODULE__, :init, [ref, socket, transport, opts])

    {:ok, pid}
  end

  def init(ref, socket, transport, _Opts = []) do
    :ok = :ranch.accept_ack(ref)
    transport.setopts(socket, [nodelay: :true])
    responder_pid = spawn_link(
      __MODULE__,
      :responder,
      [socket, transport, <<>>, []]
    )
    Process.flag(:trap_exit, true)

    loop(socket, transport, responder_pid)
  end

  def loop(socket, transport, responder_pid) do
    case transport.recv(socket, 0, 5000) do
      {:ok, packet} ->
        IO.puts "got packet (#{inspect packet})"
        send responder_pid, {:message, packet}
        loop(socket, transport, responder_pid)
      {:error, :timeout} ->
        IO.puts "Timed out"
        shutdown(socket, transport, responder_pid)
      _ ->
        IO.puts "Unknown message"
        shutdown(socket, transport, responder_pid)
    end
  end

  def responder(socket, transport, yet_to_parse, ack_list) do
    receive do
      {:message, packet} ->
        IO.puts "received message"

        case parse(yet_to_parse <> packet, << >>, 0) do
          {not_yet_parsed, {id, skipped} } ->
            new_ack_list = [{id, skipped} | ack_list]
            responder(socket, transport, not_yet_parsed, new_ack_list)

          {not_yet_parsed, {} } ->
            responder(socket, transport, not_yet_parsed, ack_list)
        end

      {:stop} ->
        IO.puts "received stop"
        :stop
    end
  end

  # Private Functions

  defp parse(<< >>, << >>, _skipped ) do
     { << >>, {} }
  end

  defp parse(<< >>, last_id, skipped ) do
    { << >>, { last_id, skipped } }
  end

  defp parse(packet, << >>, 0) do
    case packet do
      # TODO : revise this 1MB safeguard against garbage here
      << id :: binary-size(8),
         sz :: little-size(32) ,
         _data :: binary-size(sz) >> when sz < 1_000_000 ->
        { << >>, { id, 0 } }

      << id :: binary-size(8),
         sz :: little-size(32) ,
         _data :: binary-size(sz) ,
         rest :: binary >> when sz < 100 ->
        parse(rest, id, 0)

      unparsed ->
        { unparsed, {} }
    end
  end

  defp parse(packet, last_id, skipped) do
    case packet do
      # TODO : revise this 1MB safeguard against garbage here
      << id :: binary-size(8),
         sz :: little-size(32),
         _data :: binary-size(sz) >> when sz < 1_000_000  ->
        { << >>, { id, skipped+1 } }

      << id :: binary-size(8),
         sz :: little-size(32),
         _data :: binary-size(sz),
         rest :: binary >> when sz < 100 ->
        parse(rest, id, skipped+1)

      unparsed ->
        { unparsed, {last_id, skipped} }
    end
  end

  defp shutdown(socket, transport, responder_pid) do
    send responder_pid, {:stop}

    receive do
      {:EXIT, ^responder_pid, :normal} -> :ok
    end

    :ok = transport.close(socket)
  end
end
