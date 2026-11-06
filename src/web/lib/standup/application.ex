defmodule Standup.Application do
  # See https://elixir.hexdocs.pm/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      StandupWeb.Telemetry,
      Standup.Repo,
      {DNSCluster, query: Application.get_env(:standup, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Standup.PubSub},
      # Start a worker by calling: Standup.Worker.start_link(arg)
      # {Standup.Worker, arg},
      # Start to serve requests, typically the last entry
      StandupWeb.Endpoint
    ]

    # See https://elixir.hexdocs.pm/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Standup.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    StandupWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
