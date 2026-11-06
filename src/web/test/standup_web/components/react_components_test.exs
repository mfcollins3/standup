defmodule StandupWeb.ReactComponentsTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias StandupWeb.ReactComponents

  describe "react_island/1" do
    test "renders the hook, component name and JSON props" do
      html =
        render_component(&ReactComponents.react_island/1,
          id: "hello",
          component: "Hello",
          props: %{name: "Ada"}
        )

      doc = LazyHTML.from_fragment(html)
      island = LazyHTML.query(doc, "#hello")

      assert LazyHTML.attribute(island, "phx-hook") == ["ReactIsland"]
      assert LazyHTML.attribute(island, "data-component") == ["Hello"]

      assert island |> LazyHTML.attribute("data-props") |> hd() |> Jason.decode!() == %{
               "name" => "Ada"
             }
    end

    test "renders an inner container that LiveView leaves alone" do
      html = render_component(&ReactComponents.react_island/1, id: "hello", component: "Hello")

      root = html |> LazyHTML.from_fragment() |> LazyHTML.query("#hello-root")

      assert LazyHTML.attribute(root, "phx-update") == ["ignore"]
    end

    test "escapes props so they cannot break out of the attribute" do
      html =
        render_component(&ReactComponents.react_island/1,
          id: "hello",
          component: "Hello",
          props: %{name: "\"><script>alert(1)</script>"}
        )

      refute html =~ "<script>alert(1)</script>"
    end

    test "passes extra attributes to the wrapper element" do
      html =
        render_component(&ReactComponents.react_island/1,
          id: "hello",
          component: "Hello",
          class: "mt-4"
        )

      island = html |> LazyHTML.from_fragment() |> LazyHTML.query("#hello")

      assert LazyHTML.attribute(island, "class") == ["mt-4"]
    end
  end
end
