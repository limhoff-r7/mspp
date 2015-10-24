defmodule MSPP.Worker do
  @moduledoc """
  Supervised worker that acts as ranch listener.
  """

  @doc """
  Starts ranch TCP listener using `MSPP.Handler`
  """
  @spec start_link :: no_return
  def start_link do
    opts = [port: 8005]
    {:ok, _} = :ranch.start_listener(
      __MODULE__,
      100,
      :ranch_tcp,
      opts,
      MSPP.Handler,
      []
    )
  end
end
