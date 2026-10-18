// Aspire TypeScript AppHost
// For more information, see: https://aspire.dev

import { createBuilder } from './.aspire/modules/aspire.mjs';

const builder = await createBuilder();

const postgres = await builder.addAzurePostgresFlexibleServer("postgres")
    .runAsContainer({
        configureContainer: async (resource) => {
            await resource.withPgAdmin();
        },
    });

await builder.build().run();
