defmodule StandupWeb.ReactIslandDemoLiveTest do
  use StandupWeb.ConnCase

  import Phoenix.LiveViewTest

  test "renders the island with the name from the server", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/dev/react-island")

    island = element(view, "#hello")
    assert render(island) =~ ~s(data-component="Hello")
    assert render(island) =~ "Ada"
  end

  test "sends new props to the island when the name changes", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/dev/react-island")

    view |> form("#rename-form", %{"name" => "Grace"}) |> render_change()

    assert render(element(view, "#hello")) =~ "Grace"
  end

  test "handles events pushed by the island", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/dev/react-island")

    render_hook(view, "clicked", %{"count" => 3})

    assert has_element?(view, "#server-clicks", "3 clicks")
  end
end
