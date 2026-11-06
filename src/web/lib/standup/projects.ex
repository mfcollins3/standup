defmodule Standup.Projects do
  @moduledoc """
  The projects that status reports belong to.

  > #### Stub {: .warning}
  >
  > This module returns a fixed list of projects. Workspaces and projects
  > (NS-006) and the public API (NS-048) do not exist yet, and the recorder
  > needs something to choose from. NS-006 replaces this module with one that
  > reads projects from the database. It keeps the function names and return
  > values used here, so the callers do not change.
  """

  alias Standup.Projects.Project

  @workspace_id "0b6f5c1e-6d0a-4c1e-9c63-3b7c5d1f0a01"

  @projects [
    %Project{
      id: "7d1c8d3a-1f4e-4a53-8f0b-5f0e2d9a1b01",
      name: "Website redesign",
      workspace_id: @workspace_id
    },
    %Project{
      id: "7d1c8d3a-1f4e-4a53-8f0b-5f0e2d9a1b02",
      name: "Mobile app",
      workspace_id: @workspace_id
    },
    %Project{
      id: "7d1c8d3a-1f4e-4a53-8f0b-5f0e2d9a1b03",
      name: "Platform migration",
      workspace_id: @workspace_id
    }
  ]

  @doc """
  Lists the projects that `user` can record status reports for.

  There are no users yet, so every caller passes `nil` and gets every project.
  """
  @spec list_projects_for_user(term()) :: [Project.t()]
  def list_projects_for_user(_user), do: @projects

  @doc """
  Gets a project by its ID.

  Raises `ArgumentError` when there is no project with that ID. (The Ecto
  version raises `Ecto.NoResultsError`.)
  """
  @spec get_project!(String.t()) :: Project.t()
  def get_project!(id) do
    Enum.find(@projects, &(&1.id == id)) ||
      raise ArgumentError, "no project with id #{inspect(id)}"
  end
end
