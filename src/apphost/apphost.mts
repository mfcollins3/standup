// Aspire TypeScript AppHost for Naked Standup.
// For more information, see: https://aspire.dev
//
// Run `aspire run` in this directory to start the app and its dependencies
// locally, and open the Aspire dashboard to see them.

import { createBuilder } from './.aspire/modules/aspire.mjs';

const builder = await createBuilder();

if (await builder.executionContext().isRunMode()) {
  // Local development: the database is a PostgreSQL container, and Aspire
  // generates its credentials. The same resource becomes an Azure Database for
  // PostgreSQL when the app is published to Azure.
  const postgres = await builder
    .addAzurePostgresFlexibleServer('postgres')
    .runAsContainer({
      // Keep the data between runs so that `aspire run` does not start with an
      // empty database every time.
      configureContainer: async (container) => {
        await container.withDataVolume();
      },
    });

  const db = await postgres.addDatabase('db', { databaseName: 'standup' });

  // The Phoenix app runs directly from source with `mix`, so code reloading
  // and the Vite watcher keep working. Aspire sets PORT, and the app's
  // config/runtime.exs reads PORT. Referencing the database injects its
  // connection details as environment variables, including DB_URI, which
  // config/runtime.exs uses to configure Ecto.
  //
  // `mix do` creates and migrates the database before starting the server.
  await builder
    .addExecutable('web', 'mix', '../web', [
      'do',
      'ecto.create',
      '+',
      'ecto.migrate',
      '+',
      'phx.server',
    ])
    .withHttpEndpoint({ env: 'PORT' })
    .withEnvironment('MIX_ENV', 'dev')
    .withReference(db)
    .waitFor(db);
}

// Publishing to Azure is added in issue #61.

await builder.build().run();
