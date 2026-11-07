defmodule StandupWeb.RecordLive do
  @moduledoc """
  The page where a team member records a status report with their camera and
  microphone (NS-010).

  The user chooses a project and records with the `Recorder` React component.
  The video stays in the browser. When a recording is finished, the component
  tells this LiveView its size and length, and the page shows that it is ready.
  The user can watch the recording in the browser, and discard it or record
  again. Discarding tells this LiveView, which stops saying the recording is
  ready. Uploading is a separate feature.
  """
  use StandupWeb, :live_view

  alias Standup.Projects

  @recorder_states ~w(idle requesting previewing recording recorded error)

  @impl true
  def mount(_params, _session, socket) do
    projects = Projects.list_projects_for_user(nil)

    {:ok,
     socket
     |> assign(:page_title, "Record a status report")
     |> assign(:projects, projects)
     |> assign(:selected_project_id, nil)
     |> assign(:max_recording_ms, Application.fetch_env!(:standup, :max_recording_ms))
     |> assign(:recorder_state, "idle")
     |> assign(:last_recording, nil)}
  end

  @impl true
  def handle_event("select_project", %{"project_id" => project_id}, socket) do
    # Only accept a project that the user can record for. The value comes from the
    # browser, so it is not trusted.
    project_id = if project_id in project_ids(socket), do: project_id

    {:noreply, socket |> assign(:selected_project_id, project_id) |> assign(:last_recording, nil)}
  end

  def handle_event("recorder_state", %{"state" => state}, socket)
      when state in @recorder_states do
    {:noreply, assign(socket, :recorder_state, state)}
  end

  def handle_event(
        "recording_complete",
        %{
          "project_id" => project_id,
          "mime_type" => mime_type,
          "size" => size,
          "duration_ms" => duration_ms
        } = params,
        socket
      )
      when is_binary(mime_type) and is_integer(size) and size >= 0 and is_integer(duration_ms) and
             duration_ms >= 0 do
    if project_id in project_ids(socket) do
      recording = %{
        project: Projects.get_project!(project_id),
        mime_type: mime_type,
        size: size,
        duration_ms: duration_ms,
        # The browser says what stopped the recording. Anything but "limit" is the user.
        stopped_by: if(params["stopped_by"] == "limit", do: :limit, else: :user)
      }

      {:noreply, assign(socket, :last_recording, recording)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("recording_discarded", %{"project_id" => project_id}, socket) do
    # Only clear the message if it is about the project that was discarded. A
    # discard for any other project leaves the page alone.
    case socket.assigns.last_recording do
      %{project: %{id: ^project_id}} -> {:noreply, assign(socket, :last_recording, nil)}
      _ -> {:noreply, socket}
    end
  end

  def handle_event(_event, _params, socket), do: {:noreply, socket}

  defp project_ids(socket), do: Enum.map(socket.assigns.projects, & &1.id)

  defp project_options(projects), do: Enum.map(projects, &{&1.name, &1.id})

  defp format_size(bytes) when bytes < 1024, do: "#{bytes} bytes"
  defp format_size(bytes) when bytes < 1024 * 1024, do: "#{Float.round(bytes / 1024, 1)} KB"
  defp format_size(bytes), do: "#{Float.round(bytes / (1024 * 1024), 1)} MB"

  defp format_limit(ms) when rem(ms, 60_000) == 0, do: "#{div(ms, 60_000)} minute"
  defp format_limit(ms), do: "#{round(ms / 1000)} second"

  defp format_duration(duration_ms), do: "#{Float.round(duration_ms / 1000, 1)} seconds"

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="mx-auto max-w-2xl space-y-6">
        <h1 class="text-2xl font-semibold">Record a status report</h1>

        <form id="project-form" phx-change="select_project">
          <.input
            type="select"
            id="project_id"
            name="project_id"
            label="Project"
            prompt="Choose a project"
            options={project_options(@projects)}
            value={@selected_project_id}
            disabled={@recorder_state == "recording"}
          />
        </form>

        <.react_island
          id="recorder"
          component="Recorder"
          props={%{projectId: @selected_project_id, maxDurationMs: @max_recording_ms}}
        />

        <div :if={@last_recording} id="recording-ready" role="status" class="alert alert-success">
          <span>
            Recording ready for {@last_recording.project.name}: {format_size(@last_recording.size)}, {format_duration(
              @last_recording.duration_ms
            )}.
            <%= if @last_recording.stopped_by == :limit do %>
              Recording stopped at the {format_limit(@max_recording_ms)} limit.
            <% end %>
          </span>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
