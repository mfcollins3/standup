defmodule StandupWeb.ReactComponents do
  @moduledoc """
  Function components for mounting React components inside LiveView pages.

  A React component is registered by name in `assets/js/components/index.ts`
  and mounted with `<.react_island>`. See `assets/js/hooks/react_island.tsx`
  for how the browser side works.
  """
  use Phoenix.Component

  @doc """
  Renders a React component as an "island" in a LiveView.

  The island's props are encoded as JSON in `data-props`. When the LiveView
  assigns new props, the island is re-rendered with them. The React component
  can send events to the LiveView with the `pushEvent` function it receives.

  The island must have a unique `id`, and it only works inside a LiveView
  because it relies on a LiveView hook.

  ## Examples

      <.react_island id="hello" component="Hello" props={%{name: "Ada"}} />
  """
  attr :id, :string, required: true, doc: "a DOM id that is unique on the page"
  attr :component, :string, required: true, doc: "the name registered in assets/js/components"
  attr :props, :map, default: %{}, doc: "props passed to the component, encoded as JSON"
  attr :rest, :global, doc: "additional HTML attributes for the island's wrapper element"

  def react_island(assigns) do
    ~H"""
    <div
      id={@id}
      phx-hook="ReactIsland"
      data-component={@component}
      data-props={Jason.encode!(@props)}
      {@rest}
    >
      <div id={"#{@id}-root"} phx-update="ignore"></div>
    </div>
    """
  end
end
