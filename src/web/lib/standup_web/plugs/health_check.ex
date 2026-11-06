defmodule StandupWeb.Plugs.HealthCheck do
  @moduledoc """
  Answers `GET /healthz` with `200 ok`.

  The Azure Container Apps health probes call this path to find out whether the
  app is running. The plug is near the top of `StandupWeb.Endpoint`, so a probe
  does not run the router, the session, or the request logger, and it does not
  touch the database: it only shows that the app can answer HTTP requests.

  The path is excluded from `force_ssl` in `config/prod.exs`, because the
  probes use plain HTTP.
  """
  @behaviour Plug

  import Plug.Conn

  @path "/healthz"

  @doc "The path that answers the health check."
  @spec path() :: String.t()
  def path, do: @path

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(%Plug.Conn{method: method, request_path: @path} = conn, _opts)
      when method in ["GET", "HEAD"] do
    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(200, "ok")
    |> halt()
  end

  def call(conn, _opts), do: conn
end
