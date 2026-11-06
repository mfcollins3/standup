defmodule Standup.Projects.Project do
  @moduledoc "A project that holds a standup feed of status reports."

  @enforce_keys [:id, :name, :workspace_id]
  defstruct [:id, :name, :workspace_id]

  @type t :: %__MODULE__{
          id: String.t(),
          name: String.t(),
          workspace_id: String.t()
        }
end
