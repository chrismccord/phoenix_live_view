defmodule Phoenix.LiveViewTest.Controller do
  use Phoenix.Controller
  import Phoenix.LiveView.Controller

  plug :put_layout, false

  def widget(conn, _) do
    conn
    |> put_view(Phoenix.LiveViewTest.LayoutView)
    |> render("widget.html")
  end

  def incoming(conn, %{"type" => "live-render-2"}) do
    live_render(conn, Phoenix.LiveViewTest.DashboardLive)
  end

  def incoming(conn, %{"type" => "live-render-3"}) do
    live_render(conn, Phoenix.LiveViewTest.DashboardLive, session: %{"custom" => :session})
  end

  def incoming(conn, %{"type" => "live-render-4"}) do
    live_render(conn, Phoenix.LiveViewTest.DashboardLive, session: %{custom: :session})
  end

  def incoming(conn, %{"type" => "live-render-5"}) do
    conn
    |> put_layout({Phoenix.LiveViewTest.AssignsLayoutView, :app})
    |> live_render(Phoenix.LiveViewTest.DashboardLive)
  end
end

defmodule Phoenix.LiveViewTest.Router do
  use Phoenix.Router
  import Phoenix.LiveView.Router

  pipeline :browser do
    plug :accepts, ["html"]
  end

  scope "/", Phoenix.LiveViewTest do
    pipe_through [:browser]

    # controller test
    get "/controller/:type", Controller, :incoming
    get "/widget", Controller, :widget

    # router test
    live "/router/thermo_defaults/:id", DashboardLive
    live "/router/thermo_session/:id", DashboardLive
    live "/router/thermo_container/:id", DashboardLive, container: {:span, style: "flex-grow"}

    live "/router/thermo_layout/:id", DashboardLive,
      layout: {Phoenix.LiveViewTest.AlternativeLayout, :layout}

    live "/thermo", ThermostatLive
    live "/thermo/:id", ThermostatLive
    live "/thermo-container", ThermostatLive, container: {:span, style: "thermo-flex<script>"}

    live "/same-child", SameChildLive
    live "/root", RootLive
    live "/counter/:id", ParamCounterLive
    live "/opts", OptsLive
    live "/time-zones", AppendLive
    live "/shuffle", ShuffleLive
    live "/components", WithComponentLive
  end
end
