defmodule StandupWeb.ReactIslandDemoLive do
  @moduledoc """
  A development-only page that shows a React island working inside a LiveView.

  It is routed at `/dev/react-island` when `:dev_routes` is enabled.
  """
  use StandupWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, name: "Ada", clicks: 0)}
  end

  @impl true
  def handle_event("clicked", %{"count" => count}, socket) do
    {:noreply, assign(socket, :clicks, count)}
  end

  def handle_event("rename", %{"name" => name}, socket) do
    {:noreply, assign(socket, :name, name)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <h1 class="text-2xl font-semibold">React island</h1>

      <.react_island id="hello" component="Hello" props={%{name: @name}} />

      <p id="server-clicks" class="mt-4">The server has seen {@clicks} clicks.</p>

      <form id="rename-form" phx-change="rename" class="mt-4">
        <.input type="text" name="name" label="Name sent to the island" value={@name} />
      </form>
    </Layouts.app>
    """
  end
end
