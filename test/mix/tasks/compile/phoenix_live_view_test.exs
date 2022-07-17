defmodule Mix.Tasks.Compile.PhoenixLiveViewTest do
  use ExUnit.Case, async: true
  use Phoenix.Component

  alias Mix.Task.Compiler.Diagnostic
  import ExUnit.CaptureIO

  describe "validations" do
    defmodule RequiredAttrs do
      use Phoenix.Component

      attr :name, :any, required: true
      attr :phone, :any
      attr :email, :any, required: true

      def func(assigns), do: ~H[]

      def line, do: __ENV__.line + 4

      def render(assigns) do
        ~H"""
        <.func/>
        """
      end
    end

    test "validate required attributes" do
      line = get_line(RequiredAttrs)
      diagnostics = Mix.Tasks.Compile.PhoenixLiveView.validate_components_calls([RequiredAttrs])

      assert diagnostics == [
               %Diagnostic{
                 compiler_name: "phoenix_live_view",
                 file: __ENV__.file,
                 message: """
                 missing required attribute "email" for component \
                 Mix.Tasks.Compile.PhoenixLiveViewTest.RequiredAttrs.func/1\
                 """,
                 position: line,
                 severity: :warning
               },
               %Diagnostic{
                 compiler_name: "phoenix_live_view",
                 file: __ENV__.file,
                 message: """
                 missing required attribute "name" for component \
                 Mix.Tasks.Compile.PhoenixLiveViewTest.RequiredAttrs.func/1\
                 """,
                 position: line,
                 severity: :warning
               }
             ]
    end

    defmodule RequiredAttrsWithDynamic do
      use Phoenix.Component

      attr :name, :any, required: true

      def func(assigns), do: ~H[]

      def render(assigns) do
        ~H"""
        <.func {[foo: 1]}/>
        """
      end
    end

    test "do not validate required attributes when passing dynamic attr" do
      diagnostics =
        Mix.Tasks.Compile.PhoenixLiveView.validate_components_calls([RequiredAttrsWithDynamic])

      assert diagnostics == []
    end

    defmodule UndefinedAttrs do
      use Phoenix.Component

      attr :class, :any
      def func(assigns), do: ~H[]

      def line, do: __ENV__.line + 4

      def render(assigns) do
        ~H"""
        <.func width="btn" size={@size} phx-no-format />
        """
      end
    end

    test "validate undefined attributes" do
      line = get_line(UndefinedAttrs)
      diagnostics = Mix.Tasks.Compile.PhoenixLiveView.validate_components_calls([UndefinedAttrs])

      assert diagnostics == [
               %Diagnostic{
                 compiler_name: "phoenix_live_view",
                 file: __ENV__.file,
                 message:
                   "undefined attribute \"size\" for component Mix.Tasks.Compile.PhoenixLiveViewTest.UndefinedAttrs.func/1",
                 position: line,
                 severity: :warning
               },
               %Diagnostic{
                 compiler_name: "phoenix_live_view",
                 file: __ENV__.file,
                 message:
                   "undefined attribute \"width\" for component Mix.Tasks.Compile.PhoenixLiveViewTest.UndefinedAttrs.func/1",
                 position: line,
                 severity: :warning
               }
             ]
    end

    defmodule External do
      use Phoenix.Component
      attr :id, :string, required: true
      attr :rest, :global
      def button(assigns), do: ~H[<button id={@id} {@rest}/>]
    end

    defmodule TypeAttrs do
      use Phoenix.Component, global_prefixes: ~w(myprefix-)

      attr :boolean, :boolean
      attr :string, :string
      def func(assigns), do: ~H[]

      attr :id, :string, required: true
      attr :rest, :global
      def local_button(assigns), do: ~H[<button id={@id} {@rest}/>]

      def line, do: __ENV__.line + 4

      def render(assigns) do
        ~H"""
        <.func boolean="btn"/>
        <.func string/>
        <.func boolean string="string"/>
        <!-- <.func boolean={"can't validate"} string={:wont_validate}/> -->
        <.local_button id="foo" class="my-class" myprefix-thing="value"/>
        <.local_button id="foo" unknown-global="bad"/>
        <.local_button id="foo" rest="nope"/>
        <External.button id="foo" class="external" myprefix-external="value"/>
        <External.button id="foo" unknown-global-external="bad"/>
        """
      end
    end

    test "validate literal types" do
      line = get_line(TypeAttrs)
      diagnostics = Mix.Tasks.Compile.PhoenixLiveView.validate_components_calls([TypeAttrs])

      assert diagnostics == [
               %Diagnostic{
                 compiler_name: "phoenix_live_view",
                 file: __ENV__.file,
                 message:
                   "attribute \"boolean\" in component Mix.Tasks.Compile.PhoenixLiveViewTest.TypeAttrs.func/1 must be a :boolean, got string: \"btn\"",
                 position: line,
                 severity: :warning
               },
               %Diagnostic{
                 compiler_name: "phoenix_live_view",
                 file: __ENV__.file,
                 message:
                   "attribute \"string\" in component Mix.Tasks.Compile.PhoenixLiveViewTest.TypeAttrs.func/1 must be a :string, got boolean: true",
                 position: line + 1,
                 severity: :warning
               },
               %Mix.Task.Compiler.Diagnostic{
                 compiler_name: "phoenix_live_view",
                 file: __ENV__.file,
                 message:
                   "undefined attribute \"unknown-global\" for component Mix.Tasks.Compile.PhoenixLiveViewTest.TypeAttrs.local_button/1",
                 position: line + 5,
                 severity: :warning
               },
               %Mix.Task.Compiler.Diagnostic{
                 compiler_name: "phoenix_live_view",
                 file: __ENV__.file,
                 message:
                   "global attribute \"rest\" in component Mix.Tasks.Compile.PhoenixLiveViewTest.TypeAttrs.local_button/1 may not be provided directly",
                 position: line + 6,
                 severity: :warning
               },
               %Mix.Task.Compiler.Diagnostic{
                 compiler_name: "phoenix_live_view",
                 details: nil,
                 file: __ENV__.file,
                 message:
                   "undefined attribute \"unknown-global-external\" for component Mix.Tasks.Compile.PhoenixLiveViewTest.External.button/1",
                 position: line + 8,
                 severity: :warning
               }
             ]
    end

    defmodule NoAttrs do
      use Phoenix.Component

      def func(assigns), do: ~H[]

      def render(assigns) do
        ~H"""
        <.func width="btn"/>
        """
      end
    end

    test "do not validate if component doesn't have any attr declared" do
      diagnostics = Mix.Tasks.Compile.PhoenixLiveView.validate_components_calls([NoAttrs])

      assert diagnostics == []
    end

    defmodule RequiredSlots do
      use Phoenix.Component

      slot :inner_block, required: true

      def func(assigns), do: ~H[]

      slot :named, required: true

      def func_named_slot(assigns), do: ~H[]

      def render_line, do: __ENV__.line + 2

      def render(assigns) do
        ~H"""
        <!-- no default slot provided -->
        <.func/>

        <!-- with an empty default slot -->
        <.func></.func>

        <!-- with content in the default slot -->
        <.func>Hello!</.func>

        <!-- no named slots provided -->
        <.func_named_slot/>

        <!-- with an empty named slot -->
        <.func_named_slot>
          <:named />
        </.func_named_slot>

        <!-- with content in the named slots -->
        <.func_named_slot>
          <:named>
            Hello!
          </:named>
        </.func_named_slot>

        <!-- with entires for the named slot -->
        <.func_named_slot>
          <:named>
            Hello,
          </:named>
          <:named>
            World!
          </:named>
        </.func_named_slot>
        """
      end
    end

    test "validate required slots" do
      line = RequiredSlots.render_line()
      diagnostics = Mix.Tasks.Compile.PhoenixLiveView.validate_components_calls([RequiredSlots])

      assert diagnostics == [
               %Diagnostic{
                 compiler_name: "phoenix_live_view",
                 details: nil,
                 file: __ENV__.file,
                 message:
                   "missing required slot \"inner_block\" for component Mix.Tasks.Compile.PhoenixLiveViewTest.RequiredSlots.func/1",
                 position: line + 3,
                 severity: :warning
               },
               %Diagnostic{
                 compiler_name: "phoenix_live_view",
                 details: nil,
                 file: __ENV__.file,
                 message:
                   "missing required slot \"named\" for component Mix.Tasks.Compile.PhoenixLiveViewTest.RequiredSlots.func_named_slot/1",
                 position: line + 12,
                 severity: :warning
               }
             ]
    end

    defmodule SlotAttrs do
      use Phoenix.Component

      defmodule Struct do
        defstruct []
      end

      slot :slot do
        attr :any, :any
        attr :string, :string
        attr :atom, :atom
        attr :boolean, :boolean
        attr :integer, :integer
        attr :float, :float
        attr :list, :list
        attr :struct, Struct
      end

      def func(assigns), do: ~H[]

      def render_any_line, do: __ENV__.line + 5

      def render_any(assigns) do
        ~H"""
        <.func>
          <:slot any />
          <:slot any="any" />
          <:slot any={:any} />
          <:slot any={true} />
          <:slot any={1} />
          <:slot any={1.0} />
          <:slot any={[]} />
          <:slot any={%Struct{}} />
        </.func>
        """
      end

      def render_string_line, do: __ENV__.line + 5

      def render_string(assigns) do
        ~H"""
        <.func>
          <:slot string="string" />
          <:slot string={:string} />
          <:slot string={true} />
          <:slot string={1} />
          <:slot string={1.0} />
          <:slot string={[]} />
          <:slot string={%Struct{}} />
          <:slot string={nil} />
        </.func>
        """
      end

      def render_atom_line, do: __ENV__.line + 5

      def render_atom(assigns) do
        ~H"""
        <.func>
          <:slot atom="atom" />
          <:slot atom={:atom} />
          <:slot atom={true} />
          <:slot atom={1} />
          <:slot atom={1.0} />
          <:slot atom={[]} />
          <:slot atom={%Struct{}} />
          <:slot atom={nil} />
        </.func>
        """
      end

      def render_boolean_line, do: __ENV__.line + 5

      def render_boolean(assigns) do
        ~H"""
        <.func>
          <:slot boolean="boolean" />
          <:slot boolean={:boolean} />
          <:slot boolean={true} />
          <:slot boolean={1} />
          <:slot boolean={1.0} />
          <:slot boolean={[]} />
          <:slot boolean={%Struct{}} />
          <:slot boolean={nil} />
        </.func>
        """
      end

      def render_integer_line, do: __ENV__.line + 5

      def render_integer(assigns) do
        ~H"""
        <.func>
          <:slot integer="integer" />
          <:slot integer={:integer} />
          <:slot integer={true} />
          <:slot integer={1} />
          <:slot integer={1.0} />
          <:slot integer={[]} />
          <:slot integer={%Struct{}} />
          <:slot integer={nil} />
        </.func>
        """
      end

      def render_float_line, do: __ENV__.line + 5

      def render_float(assigns) do
        ~H"""
        <.func>
          <:slot float="float" />
          <:slot float={:float} />
          <:slot float={true} />
          <:slot float={1} />
          <:slot float={1.0} />
          <:slot float={[]} />
          <:slot float={%Struct{}} />
          <:slot float={nil} />
        </.func>
        """
      end

      def render_list_line, do: __ENV__.line + 5

      def render_list(assigns) do
        ~H"""
        <.func>
          <:slot list="list" />
          <:slot list={:list} />
          <:slot list={true} />
          <:slot list={1} />
          <:slot list={1.0} />
          <:slot list={[]} />
          <:slot list={%Struct{}} />
          <:slot list={nil} />
        </.func>
        """
      end

      def render_struct_line, do: __ENV__.line + 5

      def render_struct(assigns) do
        ~H"""
        <.func>
          <:slot struct="struct" />
          <:slot struct={:struct} />
          <:slot struct={true} />
          <:slot struct={1} />
          <:slot struct={1.0} />
          <:slot struct={[]} />
          <:slot struct={%Struct{}} />
          <:slot struct={nil} />
        </.func>
        """
      end
    end

    test "validate slot attr types" do
      diagnostics = Mix.Tasks.Compile.PhoenixLiveView.validate_components_calls([SlotAttrs])

      string_warnings =
        for {value, line} <- [
              {nil, 7},
              # {:struct, 6},
              {[], 5},
              {1.0, 4},
              {1, 3},
              {true, 2},
              {:string, 1}
              # {"string", 0},
            ] do
          %Diagnostic{
            compiler_name: "phoenix_live_view",
            details: nil,
            file: __ENV__.file,
            severity: :warning,
            position: SlotAttrs.render_string_line() + line,
            message:
              "attribute \"string\" in slot \"slot\" for component Mix.Tasks.Compile.PhoenixLiveViewTest.SlotAttrs.func/1 must be a :string, got: #{inspect(value)}"
          }
        end

      atom_warnings =
        for {value, line} <- [
              # {nil, 7},
              # {:struct, 6}, # TODO: this should not cause a warning
              {[], 5},
              {1.0, 4},
              {1, 3},
              # {true, 2},
              # {:atom, 1},
              {"atom", 0}
            ] do
          %Diagnostic{
            compiler_name: "phoenix_live_view",
            details: nil,
            file: __ENV__.file,
            severity: :warning,
            position: SlotAttrs.render_atom_line() + line,
            message:
              "attribute \"atom\" in slot \"slot\" for component Mix.Tasks.Compile.PhoenixLiveViewTest.SlotAttrs.func/1 must be an :atom, got: #{inspect(value)}"
          }
        end

      boolean_warnings =
        for {value, line} <- [
              {nil, 7},
              # {:struct, 6},
              {[], 5},
              {1.0, 4},
              {1, 3},
              # {true, 2},
              {:boolean, 1},
              {"boolean", 0}
            ] do
          %Diagnostic{
            compiler_name: "phoenix_live_view",
            details: nil,
            file: __ENV__.file,
            severity: :warning,
            position: SlotAttrs.render_boolean_line() + line,
            message:
              "attribute \"boolean\" in slot \"slot\" for component Mix.Tasks.Compile.PhoenixLiveViewTest.SlotAttrs.func/1 must be a :boolean, got: #{inspect(value)}"
          }
        end

      integer_warnings =
        for {value, line} <- [
              {nil, 7},
              # {:struct, 6},
              {[], 5},
              {1.0, 4},
              # {1, 3},
              {true, 2},
              {:integer, 1},
              {"integer", 0}
            ] do
          %Diagnostic{
            compiler_name: "phoenix_live_view",
            details: nil,
            file: __ENV__.file,
            severity: :warning,
            position: SlotAttrs.render_integer_line() + line,
            message:
              "attribute \"integer\" in slot \"slot\" for component Mix.Tasks.Compile.PhoenixLiveViewTest.SlotAttrs.func/1 must be a :integer, got: #{inspect(value)}"
          }
        end

      float_warnings =
        for {value, line} <- [
              {nil, 7},
              # {:struct, 6},
              {[], 5},
              # {1.0, 4},
              {1, 3},
              {true, 2},
              {:float, 1},
              {"float", 0}
            ] do
          %Diagnostic{
            compiler_name: "phoenix_live_view",
            details: nil,
            file: __ENV__.file,
            severity: :warning,
            position: SlotAttrs.render_float_line() + line,
            message:
              "attribute \"float\" in slot \"slot\" for component Mix.Tasks.Compile.PhoenixLiveViewTest.SlotAttrs.func/1 must be a :float, got: #{inspect(value)}"
          }
        end

      list_warnings =
        for {value, line} <- [
              {nil, 7},
              {{:%, [line: 428],
                [{:__aliases__, [line: 428], [:Struct]}, {:%{}, [line: 428], []}]}, 6},
              {[], 5},
              {1.0, 4},
              {1, 3},
              {true, 2},
              {:list, 1},
              {"list", 0}
            ] do
          %Diagnostic{
            compiler_name: "phoenix_live_view",
            details: nil,
            file: __ENV__.file,
            severity: :warning,
            position: SlotAttrs.render_list_line() + line,
            message:
              "attribute \"list\" in slot \"slot\" for component Mix.Tasks.Compile.PhoenixLiveViewTest.SlotAttrs.func/1 must be a :list, got: #{inspect(value)}"
          }
        end

      struct_warnings =
        for {value, line} <- [
              {nil, 7},
              {[], 5},
              {1.0, 4},
              {1, 3},
              {true, 2},
              # TODO: fix this, should be a warning
              {:struct, 1},
              {"struct", 0}
            ] do
          %Diagnostic{
            compiler_name: "phoenix_live_view",
            details: nil,
            file: __ENV__.file,
            severity: :warning,
            position: SlotAttrs.render_struct_line() + line,
            message:
              "attribute \"struct\" in slot \"slot\" for component Mix.Tasks.Compile.PhoenixLiveViewTest.SlotAttrs.func/1 must be a Mix.Tasks.Compile.PhoenixLiveViewTest.SlotAttrs.Struct, got: #{inspect(value)}"
          }
        end

      assert diagnostics ==
               string_warnings ++
                 atom_warnings ++
                 boolean_warnings ++
                 integer_warnings ++
                 float_warnings ++
                 list_warnings ++
                 struct_warnings
    end

    defmodule UndefinedSlots do
      use Phoenix.Component

      slot :inner_block

      def func(assigns), do: ~H[]

      slot :named

      def func_undefined_slot_attrs(assigns), do: ~H[]

      def render_line, do: __ENV__.line + 2

      def render(assigns) do
        ~H"""
        <!-- undefined slot -->
        <.func>
          <:undefined />
        </.func>

        <!-- slot with undefined attrs -->
        <.func_undefined_slot_attrs>
          <:named undefined />
          <:named undefined="undefined" />
        </.func_undefined_slot_attrs>
        """
      end
    end

    test "validates undefined slots" do
      line = UndefinedSlots.render_line()
      diagnostics = Mix.Tasks.Compile.PhoenixLiveView.validate_components_calls([UndefinedSlots])

      assert diagnostics == [
               %Diagnostic{
                 compiler_name: "phoenix_live_view",
                 details: nil,
                 file: __ENV__.file,
                 message:
                   "undefined slot \"undefined\" for component Mix.Tasks.Compile.PhoenixLiveViewTest.UndefinedSlots.func/1",
                 position: line + 4,
                 severity: :warning
               },
               %Diagnostic{
                 compiler_name: "phoenix_live_view",
                 details: nil,
                 file: __ENV__.file,
                 message:
                   "undefined attribute \"undefined\" in slot \"named\" for component Mix.Tasks.Compile.PhoenixLiveViewTest.UndefinedSlots.func_undefined_slot_attrs/1",
                 position: line + 10,
                 severity: :warning
               },
               %Diagnostic{
                 compiler_name: "phoenix_live_view",
                 details: nil,
                 file: __ENV__.file,
                 message:
                   "undefined attribute \"undefined\" in slot \"named\" for component Mix.Tasks.Compile.PhoenixLiveViewTest.UndefinedSlots.func_undefined_slot_attrs/1",
                 position: line + 9,
                 severity: :warning
               }
             ]
    end
  end

  describe "integration tests" do
    test "run validations for all project modules and return diagnostics" do
      {:ok, diagnostics} = Mix.Tasks.Compile.PhoenixLiveView.run(["--return-errors", "--force"])
      file = to_string(Mix.Tasks.Compile.PhoenixLiveViewTest.Comp1.module_info(:compile)[:source])

      assert Enum.all?(diagnostics, &match?(%Diagnostic{file: ^file}, &1))
    end

    test "create manifest with diagnostics if file doesn't exist" do
      [manifest] = Mix.Tasks.Compile.PhoenixLiveView.manifests()
      File.rm(manifest)

      refute File.exists?(manifest)

      {:ok, diagnostics} = Mix.Tasks.Compile.PhoenixLiveView.run(["--return-errors"])

      assert {1, ^diagnostics} = manifest |> File.read!() |> :erlang.binary_to_term()
    end

    test "update manifest if file is older than other manifests" do
      {:ok, _diagnostics} = Mix.Tasks.Compile.PhoenixLiveView.run(["--return-errors", "--force"])

      # Doesn't update it as the modification time is newer
      assert {:noop, _diagnostics} = Mix.Tasks.Compile.PhoenixLiveView.run(["--return-errors"])

      [manifest] = Mix.Tasks.Compile.PhoenixLiveView.manifests()
      [other_manifest | _] = Mix.Tasks.Compile.Elixir.manifests()

      new_manifest_mtime =
        File.stat!(other_manifest).mtime
        |> :calendar.datetime_to_gregorian_seconds()
        |> Kernel.-(1)
        |> :calendar.gregorian_seconds_to_datetime()

      File.touch!(manifest, new_manifest_mtime)

      # Update it as the modification time is older now
      assert {:ok, _diagnostics} = Mix.Tasks.Compile.PhoenixLiveView.run(["--return-errors"])
    end

    test "update manifest if the version differs" do
      {:ok, _diagnostics} = Mix.Tasks.Compile.PhoenixLiveView.run(["--return-errors", "--force"])

      # Doesn't update it as the version is the same
      assert {:noop, _diagnostics} = Mix.Tasks.Compile.PhoenixLiveView.run(["--return-errors"])

      [manifest] = Mix.Tasks.Compile.PhoenixLiveView.manifests()
      {version, diagnostics} = File.read!(manifest) |> :erlang.binary_to_term()
      File.write!(manifest, :erlang.term_to_binary({version + 1, diagnostics}))

      # Update it as the version changed
      assert {:ok, _diagnostics} = Mix.Tasks.Compile.PhoenixLiveView.run(["--return-errors"])
    end

    test "read diagnostics from manifest only when --all-warnings is passed" do
      {:ok, diagnostics} = Mix.Tasks.Compile.PhoenixLiveView.run(["--return-errors", "--force"])
      assert length(diagnostics) > 0

      assert {:noop, []} == Mix.Tasks.Compile.PhoenixLiveView.run(["--return-errors"])

      assert {:noop, ^diagnostics} =
               Mix.Tasks.Compile.PhoenixLiveView.run(["--return-errors", "--all-warnings"])
    end

    test "always return {:error. diagnostics} when --warnings-as-errors is passed" do
      {:error, _diagnostics} =
        Mix.Tasks.Compile.PhoenixLiveView.run([
          "--return-errors",
          "--force",
          "--warnings-as-errors"
        ])

      {:error, _diagnostics} =
        Mix.Tasks.Compile.PhoenixLiveView.run([
          "--return-errors",
          "--all-warnings",
          "--warnings-as-errors"
        ])
    end
  end

  describe "integration warnings" do
    # setup do
    #   ansi_enabled? = Application.put_env(:elixir, :ansi_enabled, false)
    #   Application.put_env(:elixir, :ansi_enabled, false)
    #   on_exit(fn -> Application.put_env(:elixir, :ansi_enabled, ansi_enabled?) end)
    # end

    test "print diagnostics when --return-errors is not passed" do
      messages =
        capture_io(:stderr, fn ->
          Mix.Tasks.Compile.PhoenixLiveView.run(["--force"])
        end)

      assert messages =~ """
             missing required attribute "name" for component Mix.Tasks.Compile.PhoenixLiveViewTest.Comp1.func/1
               test/support/mix/tasks/compile/phoenix_live_view_test_components.ex:9: (file)
             """

      assert messages =~ """
             missing required attribute "name" for component Mix.Tasks.Compile.PhoenixLiveViewTest.Comp1.func/1
               test/support/mix/tasks/compile/phoenix_live_view_test_components.ex:15: (file)
             """

      assert messages =~ """
             missing required attribute "name" for component Mix.Tasks.Compile.PhoenixLiveViewTest.Comp2.func/1
               test/support/mix/tasks/compile/phoenix_live_view_test_components.ex:28: (file)
             """

      assert messages =~ """
             missing required attribute "name" for component Mix.Tasks.Compile.PhoenixLiveViewTest.Comp2.func/1
               test/support/mix/tasks/compile/phoenix_live_view_test_components.ex:34: (file)
             """
    end
  end

  test "only runs diagnostics on Phoenix.Component modules" do
    alias Mix.Tasks.Compile.WithDiagnostics
    diagnostics = Mix.Tasks.Compile.PhoenixLiveView.validate_components_calls([WithDiagnostics])
    assert diagnostics == []
  end

  defp get_line(module) do
    module.line()
  end
end
