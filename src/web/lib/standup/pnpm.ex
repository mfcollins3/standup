defmodule Standup.Pnpm do
  @moduledoc """
  Runs `pnpm` commands for the asset pipeline.

  `phoenix_vite` only knows how to run `npm` or `bun`, so this module plays the
  same role as `PhoenixVite.Npm` for pnpm. It is used as the `:vite` watcher in
  `config/dev.exs`, and the profiles are configured in `config/config.exs`:

      config :standup, Standup.Pnpm,
        vite: [args: ~w(exec vite), cd: Path.expand("../assets", __DIR__)]

  The watcher key must stay `:vite`, because
  `PhoenixVite.Components.has_vite_watcher?/1` looks for it.
  """

  @doc """
  Runs `pnpm` with the arguments of the given profile plus `extra_args`.

  Returns the exit status of the command.
  """
  @spec run(atom(), [String.t()]) :: non_neg_integer()
  def run(profile, extra_args) do
    config = config_for!(profile)
    args = Keyword.get(config, :args, []) ++ extra_args

    {_output, exit_status} =
      System.cmd("pnpm", args,
        cd: Keyword.get(config, :cd, File.cwd!()),
        env: Keyword.get(config, :env, %{}),
        into: IO.stream(:stdio, :line),
        stderr_to_stdout: true
      )

    exit_status
  end

  defp config_for!(profile) when is_atom(profile) do
    :standup
    |> Application.get_env(__MODULE__, [])
    |> Keyword.get_lazy(profile, fn ->
      raise ArgumentError, """
      unknown profile #{inspect(profile)}. Make sure it is defined in config/config.exs:

          config :standup, #{inspect(__MODULE__)},
            #{profile}: [args: ~w(...), cd: Path.expand("../assets", __DIR__)]
      """
    end)
  end
end
