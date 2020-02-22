defmodule Phoenix.LiveView.PlugTest do
  use ExUnit.Case, async: true
  use Phoenix.ConnTest

  alias Phoenix.LiveView.Plug, as: LiveViewPlug
  alias Phoenix.LiveViewTest.{ThermostatLive, DashboardLive, Endpoint}

  defp call(conn, view, opts \\ []) do
    opts = Keyword.merge([router: __MODULE__, layout: false], opts)

    conn
    |> Plug.Test.init_test_session(%{})
    |> Phoenix.LiveView.Router.fetch_live_flash([])
    |> put_private(:phoenix_live_view, {view, opts})
    |> LiveViewPlug.call(view)
  end

  setup config do
    conn =
      build_conn()
      |> fetch_query_params()
      |> Plug.Test.init_test_session(config[:plug_session] || %{})
      |> Plug.Conn.put_private(:phoenix_router, Router)
      |> Plug.Conn.put_private(:phoenix_endpoint, Endpoint)

    {:ok, conn: conn}
  end

  test "with no session opts", %{conn: conn} do
    conn = call(conn, DashboardLive)

    assert conn.resp_body =~ ~s(session: %{})
  end

  test "with existing #{LiveViewPlug.link_header()} header", %{conn: conn} do
    conn =
      conn
      |> put_req_header(LiveViewPlug.link_header(), "some.site.com")
      |> call(DashboardLive)

    assert conn.resp_body =~ ~s(session: %{})
  end

  @tag plug_session: %{user_id: "alex"}
  test "with session opts", %{conn: conn} do
    conn = call(conn, DashboardLive)
    assert conn.resp_body =~ ~s(session: %{"user_id" => "alex"})
  end

  test "with a module container", %{conn: conn} do
    conn = call(conn, ThermostatLive)

    assert conn.resp_body =~
             ~r/<article[^>]*data-phx-view="ThermostatLive"[^>]*>/
  end

  test "with container options", %{conn: conn} do
    conn = call(conn, DashboardLive, container: {:span, style: "phx-flex"})

    assert conn.resp_body =~
             ~r/<span[^>]*data-phx-view="LiveViewTest.DashboardLive"[^>]*style="phx-flex">/
  end
end
