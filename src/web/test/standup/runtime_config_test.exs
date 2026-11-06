defmodule Standup.RuntimeConfigTest do
  # These tests change environment variables, so they cannot run concurrently.
  use ExUnit.Case, async: false

  @runtime_config "config/runtime.exs"
  @env_vars ~w(DB_URI DATABASE_SSL PORT PHX_SERVER SECRET_KEY_BASE PHX_HOST)

  setup do
    saved = Map.new(@env_vars, &{&1, System.get_env(&1)})
    Enum.each(@env_vars, &System.delete_env/1)

    on_exit(fn ->
      Enum.each(saved, fn
        {name, nil} -> System.delete_env(name)
        {name, value} -> System.put_env(name, value)
      end)
    end)
  end

  defp read_config(env) do
    @runtime_config
    |> Config.Reader.read!(env: env, target: :host)
    |> Keyword.get(:standup, [])
  end

  defp repo_config(env), do: env |> read_config() |> Keyword.get(Standup.Repo)

  describe "the database connection in development" do
    test "is left to config/dev.exs when DB_URI is not set" do
      assert repo_config(:dev) == nil
    end

    test "comes from DB_URI, as set by Aspire" do
      System.put_env("DB_URI", "postgresql://postgres:secret@localhost:5432/standup")

      repo = repo_config(:dev)

      assert repo[:url] == "postgresql://postgres:secret@localhost:5432/standup"
      assert repo[:ssl] == false
    end

    test "does not use TLS unless DATABASE_SSL is true" do
      System.put_env("DB_URI", "postgresql://postgres:secret@localhost:5432/standup")
      System.put_env("DATABASE_SSL", "false")

      assert repo_config(:dev)[:ssl] == false
    end

    test "verifies the server certificate and host name when DATABASE_SSL is true" do
      System.put_env("DB_URI", "postgresql://u:p@myserver.postgres.database.azure.com/standup")
      System.put_env("DATABASE_SSL", "true")

      ssl = repo_config(:dev)[:ssl]

      assert ssl[:verify] == :verify_peer
      assert ssl[:server_name_indication] == ~c"myserver.postgres.database.azure.com"
      assert [_ | _] = ssl[:cacerts]
      assert [match_fun: _] = ssl[:customize_hostname_check]
    end

    test "decodes a password with special characters through Ecto's URL parser" do
      System.put_env("DB_URI", "postgresql://postgres:p%40ss%2Fw%3Ard@localhost:5432/standup")

      opts = Ecto.Repo.Supervisor.parse_url(repo_config(:dev)[:url])

      assert opts[:password] == "p@ss/w:rd"
      assert opts[:hostname] == "localhost"
      assert opts[:database] == "standup"
    end
  end

  describe "the database connection in the test environment" do
    test "ignores DB_URI so that tests cannot reach another database" do
      System.put_env("DB_URI", "postgresql://postgres:secret@localhost:5432/standup")

      assert repo_config(:test) == nil
    end
  end

  describe "the database connection in production" do
    test "requires DB_URI" do
      System.put_env("SECRET_KEY_BASE", String.duplicate("a", 64))

      assert_raise RuntimeError, ~r/environment variable DB_URI is missing/, fn ->
        read_config(:prod)
      end
    end
  end

  describe "the HTTP port" do
    test "defaults to 4000" do
      assert read_config(:dev)[StandupWeb.Endpoint][:http][:port] == 4000
    end

    test "comes from PORT, as set by Aspire" do
      System.put_env("PORT", "25818")

      assert read_config(:dev)[StandupWeb.Endpoint][:http][:port] == 25_818
    end
  end
end
