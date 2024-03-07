defmodule Phoenix.LiveViewTest.ExpensiveRuntimeChecksTest do
  # this is intentionally async: false as we change the application
  # environment and recompile files!
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  import Phoenix.ConnTest

  import Phoenix.LiveViewTest
  alias Phoenix.LiveViewTest.Endpoint

  @endpoint Endpoint

  setup_all do
    # silence redefining module warnings
    Application.put_env(:phoenix_live_view, :enable_expensive_runtime_checks, true)
    base = Phoenix.LiveView.__info__(:compile)[:source] |> Path.dirname()

    # TODO: can we make this better?
    #       can we get rid of the redefining module warnings?
    Code.compile_file(Path.join([base, "/phoenix_live_view/async.ex"]))

    on_exit(fn ->
      Application.put_env(:phoenix_live_view, :enable_expensive_runtime_checks, false)
      Code.compile_file(Path.join([base, "/phoenix_live_view/async.ex"]))
    end)
  end

  setup do
    {:ok, conn: Plug.Test.init_test_session(Phoenix.ConnTest.build_conn(), %{})}
  end

  describe "async" do
    for fun <- [:start_async, :assign_async] do
      test "#{fun} warns when accessing socket in function at runtime", %{conn: conn} do
        _ =
          capture_io(:stderr, fn ->
            {:ok, lv, _html} = live(conn, "/expensive-runtime-checks")
            render_async(lv)

            send(self(), {:lv, lv})
          end)

        lv =
          receive do
            {:lv, lv} -> lv
          end

        warnings =
          capture_io(:stderr, fn ->
            render_hook(lv, "expensive_#{unquote(fun)}")
          end)

        assert warnings =~
                 "you are accessing the LiveView Socket inside a function given to #{unquote(fun)}"
      end

      test "#{fun} does not warns when doing it the right way", %{conn: conn} do
        _ =
          capture_io(:stderr, fn ->
            {:ok, lv, _html} = live(conn, "/expensive-runtime-checks")
            render_async(lv)

            send(self(), {:lv, lv})
          end)

        lv =
          receive do
            {:lv, lv} -> lv
          end

        warnings =
          capture_io(:stderr, fn ->
            render_hook(lv, "good_#{unquote(fun)}")
          end)

        assert warnings == ""
      end
    end
  end
end
