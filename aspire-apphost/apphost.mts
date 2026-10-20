// Aspire TypeScript AppHost
// For more information, see: https://aspire.dev

import { createBuilder } from './.aspire/modules/aspire.mjs';

const builder = await createBuilder();

await builder.addAzurePostgresFlexibleServer("postgres")
    .runAsContainer({
        configureContainer: async (resource) => {
            await resource.withPgAdmin({
                configureContainer: async (pgAdmin) => {
                    await pgAdmin.withImage("dpage/pgadmin4", { tag: "9.18.0" });
                }
            })
                .withDataVolume()
                .withRepl();
        },
    });

await builder.addKeycloak("keycloak", { port: 8080 })
    .withImageRegistry("quay.io")
    .withImage("keycloak/keycloak", { tag: "26.8.1" })
    .withOtlpExporter()
    .withDataVolume()
    .withRealmImport("./data/keycloak");

await builder.build().run();
