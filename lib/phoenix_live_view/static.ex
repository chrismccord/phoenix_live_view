defmodule Phoenix.LiveView.Static do
  # Holds the logic for static rendering.
  @moduledoc false

  alias Phoenix.LiveView.{Socket, Utils, Diff}

  # Token version. Should be changed whenever new data is stored.
  @token_vsn 2

  # Max session age in seconds. Equivalent to 2 weeks.
  @max_session_age 1_209_600

  @doc """
  Acts as a view via put_view to maintain the
  controller render + instrumentation stack.
  """
  def render("template.html", %{content: content}) do
    content
  end

  def render(_other, _assigns), do: nil

  @doc """
  Verifies the session token.

  Returns the decoded map of session data or an error.

  ## Examples

      iex> verify_session(AppWeb.Endpoint, encoded_token, static_token)
      {:ok, %{} = decoded_session}

      iex> verify_session(AppWeb.Endpoint, "bad token", "bac static")
      {:error, :invalid}

      iex> verify_session(AppWeb.Endpoint, "expired", "expired static")
      {:error, :expired}
  """
  def verify_session(endpoint, session_token, static_token) do
    with {:ok, session} <- verify_token(endpoint, session_token),
         {:ok, static} <- verify_static_token(endpoint, static_token) do
      {:ok, Map.merge(session, static)}
    end
  end

  defp verify_static_token(_endpoint, nil), do: {:ok, %{assigned_new: []}}
  defp verify_static_token(endpoint, token), do: verify_token(endpoint, token)

  defp verify_token(endpoint, token) do
    case Phoenix.Token.verify(endpoint, Utils.salt!(endpoint), token, max_age: @max_session_age) do
      {:ok, {@token_vsn, term}} -> {:ok, term}
      {:ok, _} -> {:error, :outdated}
      {:error, _} = error -> error
    end
  end

  @doc """
  Renders a live view without spawning a LiveView server.

    * `conn` - the Plug.Conn struct form the HTTP request
    * `view` - the LiveView module

  ## Options

    * `:router` - the router the live view was built at
    * `:session` - the required map of session data
    * `:container` - the optional tuple for the HTML tag and DOM attributes to
      be used for the LiveView container. For example: `{:li, style: "color: blue;"}`
  """
  def render(%Plug.Conn{} = conn, view, opts) do
    session = Keyword.get(opts, :session, %{})
    config = load_live!(view, :view)
    {tag, extended_attrs} = container(config, opts)
    router = Keyword.get(opts, :router)
    endpoint = Phoenix.Controller.endpoint_module(conn)
    request_url = Plug.Conn.request_url(conn)

    socket =
      Utils.configure_socket(
        %Socket{endpoint: endpoint, view: view},
        %{assigned_new: {conn.assigns, []}, connect_params: %{}}
      )

    case call_mount_and_handle_params!(socket, router, view, session, conn.params, request_url) do
      {:ok, socket} ->

        data_attrs = [
          phx_view: config.name,
          phx_session: sign_root_session(socket, router, view, session)
        ]

        data_attrs = (if router, do: [phx_main: true], else: []) ++ data_attrs

        attrs = [
          {:id, socket.id},
          {:data, data_attrs}
          | extended_attrs
        ]

        {:ok, to_rendered_content_tag(socket, tag, view, attrs)}

      {:stop, reason} ->
        {:stop, reason}
    end
  end

  @doc """
  Renders only the static container of the LiveView.

  Accepts same options as `static_render/3`.

  This is called by external live links.
  """
  def container_render(%Plug.Conn{} = conn, view, opts) do
    session = Keyword.get(opts, :session, %{})
    config = load_live!(view, :view)
    {tag, extended_attrs} = container(config, opts)
    router = Keyword.get(opts, :router)
    endpoint = Phoenix.Controller.endpoint_module(conn)

    socket =
      Utils.configure_socket(
        %Socket{endpoint: endpoint, view: view},
        %{assigned_new: {conn.assigns, []}, connect_params: %{}}
      )

    session_token = sign_root_session(socket, router, view, session)

    attrs = [
      {:id, socket.id},
      {:data, phx_view: config.name, phx_session: session_token}
      | extended_attrs
    ]

    tag
    |> Phoenix.HTML.Tag.content_tag(attrs, do: nil)
    |> Phoenix.HTML.safe_to_string()
  end

  @doc """
  Renders a nested live view without spawning a server.

    * `parent` - the parent `%Phoenix.LiveView.Socket{}`
    * `view` - the child LiveView module

  Accepts the same options as `static_render/3`.
  """
  def nested_render(%Socket{endpoint: endpoint, connected?: connected?} = parent, view, opts) do
    session = Keyword.get(opts, :session, %{})
    config = load_live!(view, :view)
    container = container(config, opts)

    child_id =
      opts[:id] ||
        raise ArgumentError,
              "an :id is required when rendering child LiveView. " <>
                "The :id must uniquely identify the child."

    socket =
      Utils.configure_socket(
        %Socket{
          id: to_string(child_id),
          endpoint: endpoint,
          root_pid: parent.root_pid,
          parent_pid: self()
        },
        %{assigned_new: {parent.assigns, []}}
      )

    if connected? do
      connected_nested_render(parent, config, socket, view, session, container)
    else
      disconnected_nested_render(parent, config, socket, view, session, container)
    end
  end

  defp disconnected_nested_render(parent, config, socket, view, session, container) do
    {tag, extended_attrs} = container
    socket = Utils.maybe_call_mount!(socket, view, [session, socket])

    if exports_handle_params?(view) do
      raise ArgumentError, "handle_params/3 is not allowed on child LiveViews, only at the root"
    end

    attrs = [
      {:id, socket.id},
      {:data,
       phx_view: config.name,
       phx_session: "",
       phx_static: sign_static_token(socket),
       phx_parent_id: parent.id}
      | extended_attrs
    ]

    to_rendered_content_tag(socket, tag, view, attrs)
  end

  defp connected_nested_render(parent, config, socket, view, session, container) do
    {tag, extended_attrs} = container
    session_token = sign_nested_session(parent, socket, view, session)

    attrs = [
      {:id, socket.id},
      {:data,
       phx_parent_id: parent.id, phx_view: config.name, phx_session: session_token, phx_static: ""}
      | extended_attrs
    ]

    Phoenix.HTML.Tag.content_tag(tag, "", attrs)
  end

  defp to_rendered_content_tag(socket, tag, view, attrs) do
    rendered = Utils.to_rendered(socket, view)
    {_, diff, _} = Diff.render(socket, rendered, Diff.new_components())
    Phoenix.HTML.Tag.content_tag(tag, {:safe, Diff.to_iodata(diff)}, attrs)
  end

  defp load_live!(view_or_component, kind) do
    case view_or_component.__live__() do
      %{kind: ^kind} = config ->
        config

      %{kind: other} ->
        raise "expected #{inspect(view_or_component)} to be a #{kind}, but it is a #{other}"
    end
  end

  defp call_mount_and_handle_params!(socket, router, view, session, params, uri) do
    socket
    |> Utils.maybe_call_mount!(view, [session, socket])
    |> mount_handle_params(router, view, params, uri)
    |> case do
      {:noreply, %Socket{redirected: nil} = new_socket} ->
        {:ok, new_socket}

      {:noreply, %Socket{redirected: redirected}} ->
        {:stop, redirected}

      {:stop, %Socket{redirected: nil}} ->
        Utils.raise_bad_stop_and_no_redirect!()

      {:stop, %Socket{redirected: {:live, _}}} ->
        Utils.raise_bad_stop_and_live_redirect!()

      {:stop, %Socket{redirected: redirected}} ->
        {:stop, redirected}
    end
  end

  defp mount_handle_params(socket, router, view, params, uri) do
    cond do
      not exports_handle_params?(view) ->
        {:noreply, socket}

      router == nil ->
        Utils.live_link_info!(router, view, uri)

      true ->
        view.handle_params(params, uri, socket)
    end
  end

  defp exports_handle_params?(view), do: function_exported?(view, :handle_params, 3)

  defp sign_root_session(%Socket{id: id, endpoint: endpoint}, router, view, session) do
    # IMPORTANT: If you change the third argument, @token_vsn has to be bumped.
    sign_token(endpoint, %{
      id: id,
      view: view,
      router: router,
      parent_pid: nil,
      root_pid: nil,
      session: session
    })
  end

  defp sign_nested_session(%Socket{} = parent, %Socket{} = child, view, session) do
    # IMPORTANT: If you change the third argument, @token_vsn has to be bumped.
    sign_token(parent.endpoint, %{
      id: child.id,
      view: view,
      parent_pid: self(),
      root_pid: parent.root_pid,
      session: session
    })
  end

  defp sign_static_token(%Socket{id: id, endpoint: endpoint} = socket) do
    # IMPORTANT: If you change the third argument, @token_vsn has to be bumped.
    sign_token(endpoint, %{
      id: id,
      assigned_new: assigned_new_keys(socket)
    })
  end

  defp sign_token(endpoint, data) do
    Phoenix.Token.sign(endpoint, Utils.salt!(endpoint), {@token_vsn, data})
  end

  defp container(%{container: {tag, attrs}}, opts) do
    case opts[:container] do
      {tag, extra} -> {tag, Keyword.merge(attrs, extra)}
      nil -> {tag, attrs}
    end
  end

  defp assigned_new_keys(socket) do
    {_, keys} = socket.private.assigned_new
    keys
  end
end
