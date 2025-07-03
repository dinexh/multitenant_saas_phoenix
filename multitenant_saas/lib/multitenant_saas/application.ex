defmodule MultitenantSaas.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      MultitenantSaasWeb.Telemetry,
      MultitenantSaas.Repo,
      {DNSCluster, query: Application.get_env(:multitenant_saas, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: MultitenantSaas.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: MultitenantSaas.Finch},
      # Start a worker by calling: MultitenantSaas.Worker.start_link(arg)
      # {MultitenantSaas.Worker, arg},
      # Start to serve requests, typically the last entry
      MultitenantSaasWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: MultitenantSaas.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    MultitenantSaasWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
