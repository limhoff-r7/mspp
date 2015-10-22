defmodule MSPP.Worker do
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