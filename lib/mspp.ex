defmodule MSPP do
  @moduledoc """
  Proxy for metasploit-framework payload sessions so you can scale horizontally
  using one msfconsole.
  """

  use Application

  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  @doc """
  Start supervising `MSPP.Worker`.
  """
  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      worker(MSPP.Worker, [])
    ]

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: MSPP.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
