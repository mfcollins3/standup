import Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :standup, Standup.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  port: String.to_integer(System.get_env("DATABASE_PORT", "5432")),
  database: "standup_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :standup, StandupWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "5BkvvAJgjFGEAltQDJsqK0dvJfiWx1vUxGw6VYDBjBTWG5Pe1+WjmeOfpzaXfS4s",
  server: false

# In test we don't send emails
config :standup, Standup.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# Sort query params output of verified routes for robust url comparisons
config :phoenix,
  sort_verified_routes_query_params: true

# Enable the development-only routes (such as /dev/react-island) so they can be tested.
config :standup, dev_routes: true

# Tests do not run `vite build`, so give the root layout a stub Vite manifest
# instead of reading priv/static/.vite/manifest.json.
config :standup,
  vite_manifest:
    JSON.encode!(%{
      "js/app.ts" => %{"file" => "assets/app-test.js", "src" => "js/app.ts", "isEntry" => true},
      "css/app.css" => %{
        "file" => "assets/app-test.css",
        "src" => "css/app.css",
        "isEntry" => true
      }
    })
