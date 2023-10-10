alias Phoenix.LiveViewTest.{ClockLive, ClockControlsLive}

defmodule Phoenix.LiveViewTest.ThermostatLive do
  use Phoenix.LiveView, container: {:article, class: "thermo"}, namespace: Phoenix.LiveViewTest

  defmodule Error do
    defexception [:plug_status]
    def message(%{plug_status: status}), do: "error #{status}"
  end

  def render(assigns) do
    ~H"""
    Redirect: <%= @redirect %>
    The temp is: <%= @val %><%= @greeting %>
    <button phx-click="dec">-</button>
    <button phx-click="inc">+</button>
    <%= if @nest do %>
      <%= live_render(@socket, ClockLive, [id: :clock] ++ @nest) %>
      <%= for user <- @users do %>
        <i><%= user.name %> <%= user.email %></i>
      <% end %>
    <% end %>
    """
  end

  def mount(%{"raise_connected" => status}, session, socket) do
    if connected?(socket) do
      raise Error, plug_status: String.to_integer(status)
    else
      mount(%{}, session, socket)
    end
  end

  def mount(%{"raise_disconnected" => status}, session, socket) do
    if connected?(socket) do
      mount(%{}, session, socket)
    else
      raise Error, plug_status: String.to_integer(status)
    end
  end

  def mount(_params, session, socket) do
    nest = Map.get(session, "nest", false)
    users = session["users"] || []
    val = if connected?(socket), do: 1, else: 0

    {:ok, assign(socket, val: val, nest: nest, users: users, greeting: nil)}
  end

  def handle_params(params, _url, socket) do
    {:noreply, assign(socket, redirect: params["redirect"] || "none")}
  end

  def handle_event("key", %{"key" => "i"}, socket) do
    {:noreply, update(socket, :val, &(&1 + 1))}
  end

  def handle_event("key", %{"key" => "d"}, socket) do
    {:noreply, update(socket, :val, &(&1 - 1))}
  end

  def handle_event("save", %{"temp" => new_temp} = params, socket) do
    {:noreply, assign(socket, val: new_temp, greeting: inspect(params["_target"]))}
  end

  def handle_event("save", new_temp, socket) do
    {:noreply, assign(socket, :val, new_temp)}
  end

  def handle_event("inactive", %{"value" => msg}, socket) do
    {:noreply, assign(socket, :greeting, "Tap to wake – #{msg}")}
  end

  def handle_event("active", %{"value" => msg}, socket) do
    {:noreply, assign(socket, :greeting, "Waking up – #{msg}")}
  end

  def handle_event("noop", _, socket), do: {:noreply, socket}

  def handle_event("inc", _, socket), do: {:noreply, update(socket, :val, &(&1 + 1))}

  def handle_event("dec", _, socket), do: {:noreply, update(socket, :val, &(&1 - 1))}

  def handle_call({:set, var, val}, _, socket) do
    {:reply, :ok, assign(socket, var, val)}
  end
end

defmodule Phoenix.LiveViewTest.ClockLive do
  use Phoenix.LiveView, container: {:section, class: "clock"}

  def render(assigns) do
    ~H"""
    time: <%= @time %> <%= @name %>
    <%= live_render(@socket, ClockControlsLive, id: :"#{String.replace(@name, " ", "-")}-controls", sticky: @sticky) %>
    """
  end

  def mount(:not_mounted_at_router, session, socket) do
    {:ok, assign(socket, time: "12:00", name: session["name"] || "NY", sticky: false)}
  end

  def mount(%{} = params, session, socket) do
    {:ok,
     assign(socket, time: "12:00", name: session["name"] || "NY", sticky: !!params["sticky"])}
  end

  def handle_info(:snooze, socket) do
    {:noreply, assign(socket, :time, "12:05")}
  end

  def handle_info({:run, func}, socket) do
    func.(socket)
  end

  def handle_call({:set, new_time}, _from, socket) do
    {:reply, :ok, assign(socket, :time, new_time)}
  end
end

defmodule Phoenix.LiveViewTest.ClockControlsLive do
  use Phoenix.LiveView

  def render(assigns), do: ~H|<button phx-click="snooze">+</button>|

  def mount(_params, _session, socket), do: {:ok, socket}

  def handle_event("snooze", _, socket) do
    send(socket.parent_pid, :snooze)
    {:noreply, socket}
  end
end

defmodule Phoenix.LiveViewTest.DashboardLive do
  use Phoenix.LiveView, container: {:div, class: inspect(__MODULE__)}

  def render(assigns) do
    ~H"""
    session: <%= Phoenix.HTML.raw inspect(@session) %>
    """
  end

  def mount(_params, session, socket) do
    {:ok, assign(socket, %{session: session, title: "Dashboard"})}
  end
end

defmodule Phoenix.LiveViewTest.SameChildLive do
  use Phoenix.LiveView

  def render(%{dup: true} = assigns) do
    ~H"""
    <%= for name <- @names do %>
      <%= live_render(@socket, ClockLive, id: :dup, session: %{"name" => name}) %>
    <% end %>
    """
  end

  def render(%{dup: false} = assigns) do
    ~H"""
    <%= for name <- @names do %>
      <%= live_render(@socket, ClockLive, session: %{"name" => name, "count" => @count}, id: name) %>
    <% end %>
    """
  end

  def mount(_params, %{"dup" => dup}, socket) do
    {:ok, assign(socket, count: 0, dup: dup, names: ~w(Tokyo Madrid Toronto))}
  end

  def handle_event("inc", _, socket) do
    {:noreply, assign(socket, :count, socket.assigns.count + 1)}
  end
end

defmodule Phoenix.LiveViewTest.RootLive do
  use Phoenix.LiveView
  alias Phoenix.LiveViewTest.ChildLive

  def render(assigns) do
    ~H"""
    root name: <%= @current_user.name %>
    <%= live_render(@socket, ChildLive, id: :static, session: %{"child" => :static}) %>
    <%= if @dynamic_child do %>
      <%= live_render(@socket, ChildLive, id: @dynamic_child, session: %{"child" => :dynamic}) %>
    <% end %>
    """
  end

  def mount(_params, %{"user_id" => user_id}, socket) do
    {:ok,
     socket
     |> assign(:dynamic_child, nil)
     |> assign_new(:current_user, fn ->
       %{name: "user-from-root", id: user_id}
     end)}
  end

  def handle_call({:dynamic_child, child}, _from, socket) do
    {:reply, :ok, assign(socket, dynamic_child: child)}
  end
end

defmodule Phoenix.LiveViewTest.ChildLive do
  use Phoenix.LiveView

  def render(assigns) do
    ~H"""
    child <%= @id %> name: <%= @current_user.name %>
    """
  end

  # The "user_id" is carried from the session to the child live view too
  def mount(_params, %{"user_id" => user_id, "child" => id}, socket) do
    {:ok,
     socket
     |> assign(:id, id)
     |> assign_new(:current_user, fn ->
       %{name: "user-from-child", id: user_id}
     end)}
  end
end

defmodule Phoenix.LiveViewTest.OptsLive do
  use Phoenix.LiveView

  def render(assigns), do: ~H|<%= @description %>. <%= @canary %>|

  def mount(_params, %{"opts" => opts}, socket) do
    {:ok, assign(socket, description: "long description", canary: "canary"), opts}
  end

  def handle_call({:exec, func}, _from, socket) do
    func.(socket)
  end
end

defmodule Phoenix.LiveViewTest.RedirLive do
  use Phoenix.LiveView

  def render(assigns) do
    ~H"""
    Title: <%= @title %>
    <%= if @child_params do %>
      <%= live_render(@socket, __MODULE__, id: :child, session: %{"child_redir" => @child_params}) %>
    <% end %>
    """
  end

  def mount(%{"to" => to, "kind" => kind, "during" => during}, _session, socket) do
    cond do
      during == "connected" and connected?(socket) ->
        {:ok, do_redirect(socket, kind, to: to)}

      during == "disconnected" and not connected?(socket) ->
        {:ok, do_redirect(socket, kind, to: to)}

      during == "connected" ->
        {:ok, assign(socket, title: "parent_content", child_params: nil)}
    end
  end

  def mount(%{"child_to" => to, "kind" => kind, "during" => during}, session, socket)
      when session == %{} do
    if socket.parent_pid == nil do
      {:ok,
       assign(socket,
         title: "parent_content",
         child_params: %{"to" => to, "kind" => kind, "during" => during}
       )}
    else
      raise "cannot nest"
    end
  end

  def mount(
        _params,
        %{"child_redir" => %{"to" => to, "kind" => kind, "during" => during}},
        socket
      ) do
    cond do
      during == "connected" and connected?(socket) ->
        {:ok, do_redirect(socket, kind, to: to)}

      during == "disconnected" and not connected?(socket) ->
        {:ok, do_redirect(socket, kind, to: to)}

      during == "connected" ->
        {:ok, assign(socket, title: "child_content", child_params: nil)}
    end
  end

  defp do_redirect(socket, "push_navigate", opts), do: push_navigate(socket, opts)
  defp do_redirect(socket, "redirect", opts), do: redirect(socket, opts)
  defp do_redirect(socket, "external", to: url), do: redirect(socket, external: url)
  defp do_redirect(socket, "push_patch", opts), do: push_patch(socket, opts)
end

defmodule Phoenix.LiveViewTest.AssignsNotInSocketLive do
  use Phoenix.LiveView

  def render(assigns), do: ~H|<%= boom(@socket) %>|
  def mount(_params, _session, socket), do: {:ok, socket}
  defp boom(socket), do: socket.assigns.boom
end

defmodule Phoenix.LiveViewTest.ErrorsLive do
  use Phoenix.LiveView

  alias Phoenix.LiveView.Socket

  def render(assigns), do: ~H|<div>I crash in mount</div>|

  def mount(%{"crash_on" => "disconnected_mount"}, _, %Socket{transport_pid: nil}),
    do: raise("boom disconnected mount")

  def mount(%{"crash_on" => "connected_mount"}, _, %Socket{transport_pid: pid}) when is_pid(pid),
    do: raise("boom connected mount")

  def mount(_params, _session, socket), do: {:ok, socket}

  def handle_params(%{"crash_on" => "disconnected_handle_params"}, _, %Socket{transport_pid: nil}),
    do: raise("boom disconnected handle_params")

  def handle_params(%{"crash_on" => "connected_handle_params"}, _, %Socket{transport_pid: pid})
      when is_pid(pid),
      do: raise("boom connected handle_params")

  def handle_params(_params, _session, socket), do: {:noreply, socket}

  def handle_event("crash", _params, _socket), do: raise("boom handle_event")
end

defmodule Phoenix.LiveViewTest.ClassListLive do
  use Phoenix.LiveView, container: {:span, class: ~w(foo bar)}

  def render(assigns), do: ~H|Some content|
end

defmodule Phoenix.LiveViewTest.AssignAsyncLive do
  use Phoenix.LiveView

  on_mount({__MODULE__, :defaults})

  def on_mount(:defaults, _params, _session, socket) do
    {:cont, assign(socket, lc: false)}
  end

  def render(assigns) do
    ~H"""
    <.live_component :if={@lc} module={Phoenix.LiveViewTest.AssignAsyncLive.LC} test={@lc} id="lc" />

    <div :if={@data.loading}>data loading...</div>
    <div :if={@data.ok? && @data.result == nil}>no data found</div>
    <div :if={@data.ok? && @data.result}>data: <%= inspect(@data.result) %></div>
    <div :if={@data.failed}><%= inspect(@data.failed) %></div>
    """
  end

  def mount(%{"test" => "lc_" <> lc_test}, _session, socket) do
    {:ok,
     socket
     |> assign(lc: lc_test)
     |> assign_async(:data, fn -> {:ok, %{data: :live_component}} end)}
  end

  def mount(%{"test" => "bad_return"}, _session, socket) do
    {:ok, assign_async(socket, :data, fn -> 123 end)}
  end

  def mount(%{"test" => "bad_ok"}, _session, socket) do
    {:ok, assign_async(socket, :data, fn -> {:ok, %{bad: 123}} end)}
  end

  def mount(%{"test" => "ok"}, _session, socket) do
    {:ok, assign_async(socket, :data, fn -> {:ok, %{data: 123}} end)}
  end

  def mount(%{"test" => "raise"}, _session, socket) do
    {:ok, assign_async(socket, :data, fn -> raise("boom") end)}
  end

  def mount(%{"test" => "exit"}, _session, socket) do
    {:ok, assign_async(socket, :data, fn -> exit(:boom) end)}
  end

  def mount(%{"test" => "lv_exit"}, _session, socket) do
    {:ok,
     assign_async(socket, :data, fn ->
       Process.register(self(), :lv_exit)
       Process.sleep(:infinity)
     end)}
  end

  def mount(%{"test" => "cancel"}, _session, socket) do
    {:ok,
     assign_async(socket, :data, fn ->
       Process.register(self(), :cancel)
       Process.sleep(:infinity)
     end)}
  end

  def mount(%{"test" => "trap_exit"}, _session, socket) do
    Process.flag(:trap_exit, true)

    {:ok,
     assign_async(socket, :data, fn ->
       spawn_link(fn -> exit(:boom) end)
       Process.sleep(100)
       {:ok, %{data: 0}}
     end)}
  end

  def handle_info(:boom, _socket), do: exit(:boom)

  def handle_info(:cancel, socket) do
    {:noreply, cancel_async(socket, socket.assigns.data)}
  end

  def handle_info({:EXIT, pid, reason}, socket) do
    send(:trap_exit_test, {:exit, pid, reason})
    {:noreply, socket}
  end

  def handle_info(:renew_canceled, socket) do
    {:noreply,
     assign_async(socket, :data, fn ->
       Process.sleep(100)
       {:ok, %{data: 123}}
     end)}
  end
end

defmodule Phoenix.LiveViewTest.AssignAsyncLive.LC do
  use Phoenix.LiveComponent

  def render(assigns) do
    ~H"""
    <div>
      <.async_result :let={data} assign={@lc_data}>
        <:loading>lc_data loading...</:loading>
        <:failed :let={{kind, reason}}><%= kind %>: <%= inspect(reason) %></:failed>

        lc_data: <%= inspect(data) %>
      </.async_result>
    </div>
    """
  end

  def update(%{test: "bad_return"}, socket) do
    {:ok, assign_async(socket, :lc_data, fn -> 123 end)}
  end

  def update(%{test: "bad_ok"}, socket) do
    {:ok, assign_async(socket, :lc_data, fn -> {:ok, %{bad: 123}} end)}
  end

  def update(%{test: "ok"}, socket) do
    {:ok, assign_async(socket, :lc_data, fn -> {:ok, %{lc_data: 123}} end)}
  end

  def update(%{test: "raise"}, socket) do
    {:ok, assign_async(socket, :lc_data, fn -> raise("boom") end)}
  end

  def update(%{test: "exit"}, socket) do
    {:ok, assign_async(socket, :lc_data, fn -> exit(:boom) end)}
  end

  def update(%{test: "lv_exit"}, socket) do
    {:ok,
     assign_async(socket, :lc_data, fn ->
       Process.register(self(), :lc_exit)
       Process.sleep(:infinity)
     end)}
  end

  def update(%{test: "cancel"}, socket) do
    {:ok,
     assign_async(socket, :lc_data, fn ->
       Process.register(self(), :lc_cancel)
       Process.sleep(:infinity)
     end)}
  end

  def update(%{action: :boom}, _socket), do: exit(:boom)

  def update(%{action: :cancel}, socket) do
    {:ok, cancel_async(socket, socket.assigns.lc_data)}
  end

  def update(%{action: :renew_canceled}, socket) do
    {:ok,
     assign_async(socket, :lc_data, fn ->
       Process.sleep(100)
       {:ok, %{lc_data: 123}}
     end)}
  end
end

defmodule Phoenix.LiveViewTest.StartAsyncLive do
  use Phoenix.LiveView

  on_mount({__MODULE__, :defaults})

  def on_mount(:defaults, _params, _session, socket) do
    {:cont, assign(socket, lc: false)}
  end

  def render(assigns) do
    ~H"""
    <.live_component :if={@lc} module={Phoenix.LiveViewTest.StartAsyncLive.LC} test={@lc} id="lc" />
    result: <%= inspect(@result) %>
    """
  end

  def mount(%{"test" => "lc_" <> lc_test}, _session, socket) do
    {:ok, assign(socket, lc: lc_test, result: :loading)}
  end

  def mount(%{"test" => "ok"}, _session, socket) do
    {:ok,
     socket
     |> assign(result: :loading)
     |> start_async(:result_task, fn -> :good end)}
  end

  def mount(%{"test" => "raise"}, _session, socket) do
    {:ok,
     socket
     |> assign(result: :loading)
     |> start_async(:result_task, fn -> raise("boom") end)}
  end

  def mount(%{"test" => "exit"}, _session, socket) do
    {:ok,
     socket
     |> assign(result: :loading)
     |> start_async(:result_task, fn -> exit(:boom) end)}
  end

  def mount(%{"test" => "lv_exit"}, _session, socket) do
    {:ok,
     socket
     |> assign(result: :loading)
     |> start_async(:result_task, fn ->
       Process.register(self(), :start_async_exit)
       Process.sleep(:infinity)
     end)}
  end

  def mount(%{"test" => "cancel"}, _session, socket) do
    {:ok,
     socket
     |> assign(result: :loading)
     |> start_async(:result_task, fn ->
       Process.register(self(), :start_async_cancel)
       Process.sleep(:infinity)
     end)}
  end

  def mount(%{"test" => "trap_exit"}, _session, socket) do
    Process.flag(:trap_exit, true)

    {:ok,
     socket
     |> assign(result: :loading)
     |> assign_async(:result_task, fn ->
       spawn_link(fn -> exit(:boom) end)
       Process.sleep(100)
       :good
     end)}
  end

  def handle_async(:result_task, {:ok, result}, socket) do
    {:noreply, assign(socket, result: result)}
  end

  def handle_async(:result_task, {:exit, {error, [_ | _] = _stack}}, socket) do
    {:noreply, assign(socket, result: {:exit, error})}
  end

  def handle_async(:result_task, {:exit, reason}, socket) do
    {:noreply, assign(socket, result: {:exit, reason})}
  end

  def handle_info(:boom, _socket), do: exit(:boom)

  def handle_info(:cancel, socket) do
    {:noreply, cancel_async(socket, :result_task)}
  end

  def handle_info(:renew_canceled, socket) do
    {:noreply,
     start_async(socket, :result_task, fn ->
       Process.sleep(100)
       :renewed
     end)}
  end

  def handle_info({:EXIT, pid, reason}, socket) do
    send(:start_async_trap_exit_test, {:exit, pid, reason})
    {:noreply, socket}
  end
end

defmodule Phoenix.LiveViewTest.StartAsyncLive.LC do
  use Phoenix.LiveComponent

  def render(assigns) do
    ~H"""
    <div>
      lc: <%= inspect(@result) %>
    </div>
    """
  end

  def update(%{test: "ok"}, socket) do
    {:ok,
     socket
     |> assign(result: :loading)
     |> start_async(:result_task, fn -> :good end)}
  end

  def update(%{test: "raise"}, socket) do
    {:ok,
     socket
     |> assign(result: :loading)
     |> start_async(:result_task, fn -> raise("boom") end)}
  end

  def update(%{test: "exit"}, socket) do
    {:ok,
     socket
     |> assign(result: :loading)
     |> start_async(:result_task, fn -> exit(:boom) end)}
  end

  def update(%{test: "lv_exit"}, socket) do
    {:ok,
     socket
     |> assign(result: :loading)
     |> start_async(:result_task, fn ->
       Process.register(self(), :start_async_exit)
       Process.sleep(:infinity)
     end)}
  end

  def update(%{test: "cancel"}, socket) do
    {:ok,
     socket
     |> assign(result: :loading)
     |> start_async(:result_task, fn ->
       Process.register(self(), :start_async_cancel)
       Process.sleep(:infinity)
     end)}
  end

  def update(%{action: :cancel}, socket) do
    {:ok, cancel_async(socket, :result_task)}
  end

  def update(%{action: :renew_canceled}, socket) do
    {:ok,
     start_async(socket, :result_task, fn ->
       Process.sleep(100)
       :renewed
     end)}
  end

  def handle_async(:result_task, {:ok, result}, socket) do
    {:noreply, assign(socket, result: result)}
  end

  def handle_async(:result_task, {:exit, {error, [_ | _] = _stack}}, socket) do
    {:noreply, assign(socket, result: {:exit, error})}
  end

  def handle_async(:result_task, {:exit, reason}, socket) do
    {:noreply, assign(socket, result: {:exit, reason})}
  end
end
