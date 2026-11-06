// Aspire TypeScript AppHost for Naked Standup.
// For more information, see: https://aspire.dev
//
// Run `aspire run` in this directory to start the app and its dependencies
// locally, and open the Aspire dashboard to see them. The deploy workflow
// (.github/workflows/deploy.yml) runs this AppHost to provision and deploy the
// app to Azure; see docs/contributing/deployment.md.

import { createBuilder, EndpointProperty } from './.aspire/modules/aspire.mjs';

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
} else {
  // Azure: Azure Database for PostgreSQL, an Azure Container Apps environment
  // (which also creates an Azure Container Registry), and a Container App that
  // runs the container image built by .github/workflows/container.yml.
  //
  // The deploy workflow passes the published image in WEB_IMAGE, pinned by its
  // digest, for example ghcr.io/<owner>/standup-web@sha256:<digest>. Aspire
  // builds web-image/Dockerfile, which is only `FROM` that image, pushes it to
  // the registry, and deploys it. See docs/contributing/deployment.md.
  const webImage =
    process.env.WEB_IMAGE ?? 'ghcr.io/mfcollins3/standup-web:latest';

  const dbUser = await builder.addParameter('db-user', { secret: true });
  const dbPassword = await builder.addParameter('db-password', { secret: true });
  const secretKeyBase = await builder.addParameter('secret-key-base', {
    secret: true,
  });

  // Ecto cannot use Microsoft Entra tokens as the database password, so the
  // server uses a user name and password.
  const postgres = await builder
    .addAzurePostgresFlexibleServer('postgres')
    .withPasswordAuthentication({ userName: dbUser, password: dbPassword });

  const db = await postgres.addDatabase('db', { databaseName: 'standup' });

  await builder.addAzureContainerAppEnvironment('aca-env');

  // The Container App is publicly reachable on port 8080 of the container.
  const web = await builder
    .addDockerfile('web', './web-image')
    .withBuildArg('WEB_IMAGE', webImage)
    .withHttpEndpoint({ targetPort: 8080 })
    .withExternalHttpEndpoints()
    .withReference(db)
    .withEnvironment('DATABASE_SSL', 'true')
    .withEnvironment('SECRET_KEY_BASE', secretKeyBase);

  // The public host name is needed to generate URLs and to check the origin of
  // WebSocket connections. It resolves to <app>.<environment default domain>.
  await web.withEnvironment(
    'PHX_HOST',
    web.getEndpoint('http').property(EndpointProperty.Host),
  );
}

await builder.build().run();
