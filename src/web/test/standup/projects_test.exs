defmodule Standup.ProjectsTest do
  use ExUnit.Case, async: true

  alias Standup.Projects
  alias Standup.Projects.Project

  describe "list_projects_for_user/1" do
    test "returns projects with an ID, a name and a workspace" do
      projects = Projects.list_projects_for_user(nil)

      assert [_ | _] = projects

      for project <- projects do
        assert %Project{id: id, name: name, workspace_id: workspace_id} = project
        assert is_binary(id) and id != ""
        assert is_binary(name) and name != ""
        assert is_binary(workspace_id) and workspace_id != ""
      end
    end

    test "returns projects with unique IDs and names" do
      projects = Projects.list_projects_for_user(nil)

      assert projects |> Enum.map(& &1.id) |> Enum.uniq() |> length() == length(projects)
      assert projects |> Enum.map(& &1.name) |> Enum.uniq() |> length() == length(projects)
    end
  end

  describe "get_project!/1" do
    test "returns the project with that ID" do
      [project | _] = Projects.list_projects_for_user(nil)

      assert Projects.get_project!(project.id) == project
    end

    test "raises when there is no such project" do
      assert_raise ArgumentError, ~r/no project with id/, fn ->
        Projects.get_project!("not-a-project")
      end
    end
  end
end
