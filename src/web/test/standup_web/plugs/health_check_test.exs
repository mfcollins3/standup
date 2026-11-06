defmodule StandupWeb.Plugs.HealthCheckTest do
  use StandupWeb.ConnCase, async: true

  describe "GET /healthz" do
    test "answers 200 ok", %{conn: conn} do
      conn = get(conn, "/healthz")

      assert response(conn, 200) == "ok"
      assert [content_type] = get_resp_header(conn, "content-type")
      assert content_type =~ "text/plain"
    end

    test "answers HEAD requests", %{conn: conn} do
      conn = head(conn, "/healthz")

      assert response(conn, 200)
    end

    test "does not use the session or run the router", %{conn: conn} do
      conn = get(conn, "/healthz")

      assert get_resp_header(conn, "set-cookie") == []
      refute conn.private[:phoenix_router]
    end

    test "does not answer other methods", %{conn: conn} do
      conn = post(conn, "/healthz")

      assert conn.status == 404 or conn.status == 405
    end

    test "does not answer other paths", %{conn: conn} do
      conn = get(conn, "/healthz/extra")

      assert conn.status == 404
    end
  end
end
