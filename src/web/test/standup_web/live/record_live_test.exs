defmodule StandupWeb.RecordLiveTest do
  use StandupWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Standup.Projects

  setup %{conn: conn} do
    {:ok, view, html} = live(conn, ~p"/record")
    [project | _] = Projects.list_projects_for_user(nil)

    %{view: view, html: html, project: project}
  end

  defp island_props(view) do
    view
    |> element("#recorder")
    |> render()
    |> LazyHTML.from_fragment()
    |> LazyHTML.query("#recorder")
    |> LazyHTML.attribute("data-props")
    |> hd()
    |> Jason.decode!()
  end

  defp select_project(view, project_id) do
    view |> form("#project-form", %{"project_id" => project_id}) |> render_change()
  end

  defp complete_recording(view, project, overrides \\ %{}) do
    params =
      Map.merge(
        %{
          "project_id" => project.id,
          "mime_type" => "video/webm",
          "size" => 2048,
          "duration_ms" => 3200
        },
        overrides
      )

    render_hook(view, "recording_complete", params)
  end

  describe "the page" do
    test "has a title", %{html: html} do
      assert html =~ "Record a status report"
    end

    test "lists the projects to choose from", %{view: view} do
      for project <- Projects.list_projects_for_user(nil) do
        assert has_element?(view, "#project_id option[value='#{project.id}']", project.name)
      end

      assert has_element?(view, "#project_id option[value='']", "Choose a project")
    end

    test "mounts the recorder with no project chosen", %{view: view} do
      assert has_element?(view, "#recorder[phx-hook='ReactIsland'][data-component='Recorder']")
      assert island_props(view) == %{"projectId" => nil}
    end

    test "does not show a finished recording", %{view: view} do
      refute has_element?(view, "#recording-ready")
    end
  end

  describe "choosing a project" do
    test "passes the project to the recorder", %{view: view, project: project} do
      select_project(view, project.id)

      assert island_props(view) == %{"projectId" => project.id}
    end

    test "choosing the prompt again clears the project", %{view: view, project: project} do
      select_project(view, project.id)
      select_project(view, "")

      assert island_props(view) == %{"projectId" => nil}
    end

    test "ignores a project that the user cannot record for", %{view: view} do
      render_hook(view, "select_project", %{"project_id" => "forged-id"})

      assert island_props(view) == %{"projectId" => nil}
    end

    test "clears a finished recording", %{view: view, project: project} do
      select_project(view, project.id)
      complete_recording(view, project)
      assert has_element?(view, "#recording-ready")

      select_project(view, "")

      refute has_element?(view, "#recording-ready")
    end
  end

  describe "while recording" do
    test "the project cannot be changed", %{view: view} do
      refute has_element?(view, "#project_id[disabled]")

      render_hook(view, "recorder_state", %{"state" => "recording"})
      assert has_element?(view, "#project_id[disabled]")

      render_hook(view, "recorder_state", %{"state" => "recorded"})
      refute has_element?(view, "#project_id[disabled]")
    end

    test "ignores a state that the recorder does not have", %{view: view} do
      render_hook(view, "recorder_state", %{"state" => "exploding"})

      refute has_element?(view, "#project_id[disabled]")
    end
  end

  describe "a finished recording" do
    test "is shown with its project, size and length", %{view: view, project: project} do
      select_project(view, project.id)
      complete_recording(view, project, %{"size" => 2048, "duration_ms" => 3200})

      assert has_element?(view, "#recording-ready[role='status']", project.name)
      assert has_element?(view, "#recording-ready", "2.0 KB")
      assert has_element?(view, "#recording-ready", "3.2 seconds")
    end

    test "is shown in megabytes when it is large", %{view: view, project: project} do
      select_project(view, project.id)
      complete_recording(view, project, %{"size" => 5 * 1024 * 1024})

      assert has_element?(view, "#recording-ready", "5.0 MB")
    end

    test "is ignored for a project that the user cannot record for", %{view: view} do
      render_hook(view, "recording_complete", %{
        "project_id" => "forged-id",
        "mime_type" => "video/webm",
        "size" => 1,
        "duration_ms" => 1
      })

      refute has_element?(view, "#recording-ready")
    end

    test "is ignored when the details have the wrong types", %{view: view, project: project} do
      complete_recording(view, project, %{"size" => "big", "duration_ms" => -5})
      complete_recording(view, project, %{"mime_type" => nil})

      refute has_element?(view, "#recording-ready")
      assert has_element?(view, "#recorder")
    end

    test "is ignored when details are missing", %{view: view} do
      render_hook(view, "recording_complete", %{})

      refute has_element?(view, "#recording-ready")
    end
  end
end
