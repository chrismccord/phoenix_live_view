defmodule Phoenix.LiveViewTest.Router do
  use Phoenix.Router
  import Phoenix.LiveView.Router

  pipeline :browser do
    plug :accepts, ["html"]
  end

  pipeline :layout do
    plug :put_layout, {Phoenix.LiveViewTest.LayoutView, :app}
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
    live "/", ThermostatLive, as: :live_root

    live "/same-child", SameChildLive
    live "/root", RootLive
    live "/counter/:id", ParamCounterLive
    live "/opts", OptsLive
    live "/time-zones", AppendLive
    live "/shuffle", ShuffleLive
    live "/components", WithComponentLive
    live "/layout", LayoutLive
  end

  scope "/alt", Phoenix.LiveViewTest do
    pipe_through [:browser, :layout]

    live "/router/thermo/:id", DashboardLive,
      layout: {Phoenix.LiveViewTest.AlternativeLayout, :layout}

    live "/layout", LayoutLive, layout: {Phoenix.LiveViewTest.AlternativeLayout, :layout}
  end
end
