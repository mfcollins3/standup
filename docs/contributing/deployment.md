# Deploying to Azure

The web app is deployed to Azure Container Apps by the **Deploy** workflow
(`.github/workflows/deploy.yml`). You run it by hand from the Actions tab. This
page describes what it does, and the one-time setup that it needs.

## What the workflow does

1. Takes the tag of an image that the **Container image** workflow published to
   GHCR (`latest` by default) and resolves it to a digest. It verifies that the
   image was built by this repository's workflow, and deploys that digest.
2. Logs in to Azure with OpenID Connect. No Azure secret is stored in GitHub.
3. Runs `aspire deploy` in `src/apphost`. Aspire:
   * provisions or updates the Azure resources listed below,
   * builds `src/apphost/web-image/Dockerfile`, which is only `FROM` the
     published image, and pushes it to the Azure Container Registry,
   * gives the Container App permission to pull from the registry, and
   * deploys the Container App.
4. Calls `/healthz` on the deployed app until it answers.

The deployed image has the same configuration and layers as the one in GHCR.
Aspire builds the one-line `FROM` Dockerfile because it only sets up registry
access for images that it builds itself. See the
[ADR on container delivery](../adrs/draft-build-once-container-delivery-ghcr-to-acr.md).

### The Azure resources

| Resource | Created for |
| -------- | ----------- |
| Container Apps environment, and a Log Analytics workspace | Runs the app and keeps its logs. |
| Container Registry | Holds the image that the app runs. |
| Managed identity for the registry | Lets the Container App pull from the registry (`AcrPull`). |
| Container App `web` | The web app, with a public HTTPS address. |
| Azure Database for PostgreSQL flexible server, and the `standup` database | The app's database. |
| Key Vault | Holds the database connection string for the Container App. |
| Managed identity for the app | Lets the Container App read from the Key Vault. |

These resources cost money while they exist. To remove all of them, delete the
resource group (see [Removing everything](#removing-everything)).

## One-time setup

You need the [Azure CLI](https://learn.microsoft.com/cli/azure/), the
[GitHub CLI](https://cli.github.com/), and permission to create app
registrations and role assignments on the Azure subscription.

### 1. Choose the settings

```shell
az login

SUBSCRIPTION_ID="$(az account show --query id --output tsv)"
TENANT_ID="$(az account show --query tenantId --output tsv)"
LOCATION="southcentralus"              # an Azure region, see below
RESOURCE_GROUP="rg-standup-production"
GITHUB_REPOSITORY="mfcollins3/standup"
```

**Check the region before you use it.** The database is the part that is most
likely to fail, because Azure does not offer every SKU in every region, and
offers some only to some subscriptions. The AppHost asks for a `Standard_B1ms`
(Burstable) server with PostgreSQL 16, and it always pins the server to
availability zone 1. It cannot change these, so the region has to offer that
SKU **and** have availability zones:

```shell
az postgres flexible-server list-skus --location "$LOCATION" \
  --query "[0].supportedServerEditions[?name=='Burstable'].supportedServerSkus[] | [?name=='Standard_B1ms'].{sku:name, zones:supportedZones}" \
  --output json
```

You want to see `Standard_B1ms` with zones `1`, `2` and `3`. If the output is
empty, the region does not offer the SKU to your subscription, and Azure says
why in the `reason` field of `az postgres flexible-server list-skus --location
"$LOCATION"`. If `zones` is empty, the region has no availability zones. Both
mean that you should choose another region.

This list shows what Azure offers, not what it has free right now. If the
deployment is accepted and then fails after a minute with `SkuNotAvailable`,
see [SkuNotAvailable](#skunotavailable-from-the-database).

### 2. Register the resource providers

```shell
for provider in Microsoft.App Microsoft.ContainerRegistry \
    Microsoft.DBforPostgreSQL Microsoft.KeyVault \
    Microsoft.ManagedIdentity Microsoft.OperationalInsights; do
  az provider register --namespace "$provider"
done
```

### 3. Create the resource group

```shell
az group create --name "$RESOURCE_GROUP" --location "$LOCATION"
```

### 4. Create the identity that GitHub Actions uses

The workflow logs in as an app registration that has a federated credential for
the `production` environment of this repository, so it needs no secret.

Azure compares the credential's subject with the subject in GitHub's token
**exactly**, and GitHub builds that subject in one of two ways. Repositories with
the immutable subject setting turned on, which is the default for newer
repositories, put the numeric owner and repository IDs in it, for example
`repo:owner@123/name@456:environment:production`. Older repositories use
`repo:owner/name:environment:production`. Ask GitHub for the prefix that this
repository uses, so that the credential matches:

```shell
SUBJECT_PREFIX="$(gh api "repos/${GITHUB_REPOSITORY}/actions/oidc/customization/sub" \
  --jq '.sub_claim_prefix // empty')"
SUBJECT_PREFIX="${SUBJECT_PREFIX:-repo:${GITHUB_REPOSITORY}}"
echo "$SUBJECT_PREFIX:environment:production"

APP_ID="$(az ad app create --display-name "standup-github-deploy" \
  --query appId --output tsv)"
az ad sp create --id "$APP_ID"

az ad app federated-credential create --id "$APP_ID" --parameters "$(cat <<EOF
{
  "name": "github-production",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "${SUBJECT_PREFIX}:environment:production",
  "audiences": ["api://AzureADTokenExchange"]
}
EOF
)"
```

If a login fails with `AADSTS700213`, the subject is wrong. See
[Troubleshooting](#troubleshooting).

### 5. Give it access to the resource group

`aspire deploy` creates resources and also creates role assignments, such as the
`AcrPull` role for the registry, so the identity needs both roles. Scope them to
the resource group and no wider.

```shell
SCOPE="/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP}"
az role assignment create --assignee "$APP_ID" --role "Contributor" --scope "$SCOPE"
az role assignment create --assignee "$APP_ID" --role "User Access Administrator" --scope "$SCOPE"
```

### 6. Configure the `production` environment in GitHub

Create the environment, and optionally add required reviewers so that every
deployment needs an approval. Then set its variables and secrets:

```shell
gh api --method PUT "repos/${GITHUB_REPOSITORY}/environments/production"

for pair in "AZURE_CLIENT_ID=$APP_ID" "AZURE_TENANT_ID=$TENANT_ID" \
    "AZURE_SUBSCRIPTION_ID=$SUBSCRIPTION_ID" "AZURE_LOCATION=$LOCATION" \
    "AZURE_RESOURCE_GROUP=$RESOURCE_GROUP"; do
  gh variable set "${pair%%=*}" --env production --repo "$GITHUB_REPOSITORY" --body "${pair#*=}"
done
```

| Variable | Value |
| -------- | ----- |
| `AZURE_CLIENT_ID` | The app registration's application (client) ID. |
| `AZURE_TENANT_ID` | The Microsoft Entra tenant ID. |
| `AZURE_SUBSCRIPTION_ID` | The subscription to deploy to. |
| `AZURE_LOCATION` | The Azure region, for example `westus3`. |
| `AZURE_RESOURCE_GROUP` | The resource group from step 3. |

Set these secrets too. Choose the database user name and password yourself:

| Secret | Value |
| ------ | ----- |
| `DB_USER` | The database administrator's user name, for example `standupadmin`. Azure reserves some names, such as `admin`, `administrator` and `root`, and names that start with `pg_`. |
| `DB_PASSWORD` | A strong password for it. |
| `SECRET_KEY_BASE` | The key that Phoenix uses to sign cookies. Generate one with `openssl rand -hex 32`. |

```shell
gh secret set DB_USER --env production --repo "$GITHUB_REPOSITORY"
gh secret set DB_PASSWORD --env production --repo "$GITHUB_REPOSITORY"
gh secret set SECRET_KEY_BASE --env production --repo "$GITHUB_REPOSITORY" --body "$(openssl rand -hex 32)"
```

`gh secret set` asks for the value when `--body` is not given, so the user name
and password do not end up in your shell history.

## Deploying

1. Make sure that the **Container image** workflow has published the image that
   you want to deploy. Pushes to `main` publish `latest`, `main`, and
   `sha-<commit>`.
2. In the repository, open **Actions**, choose **Deploy**, and **Run workflow**.
   Enter the image tag, or keep `latest`.
3. If the environment has required reviewers, approve the run.

The job summary shows the image digest that was deployed and the app's address.

## Checking and debugging a deployment

```shell
# The app's address
az containerapp show --name web --resource-group "$RESOURCE_GROUP" \
  --query properties.configuration.ingress.fqdn --output tsv

# The app's logs
az containerapp logs show --name web --resource-group "$RESOURCE_GROUP" --follow

# The image that is running
az containerapp show --name web --resource-group "$RESOURCE_GROUP" \
  --query "properties.template.containers[0].image" --output tsv
```

## Troubleshooting

Open the failed run in the Actions tab and find the step with the red cross. The
failures below are the ones that are most likely on a first deployment.

### "Log in to Azure" says `client-id` and `tenant-id` are missing

The variables of the `production` environment are empty. The step's log lists the
values that it received, and the `Azure__SubscriptionId:` line in the `env`
block is blank when `AZURE_SUBSCRIPTION_ID` is not set. Check the environment's
variables under **Settings**, **Environments**, **production**. The variables
must be on that environment, not only in your shell.

### `AADSTS700213: No matching federated identity record found`

Azure rejected the login because the credential's subject is not the subject that
GitHub sent. The failing step prints the one that GitHub sent, on the line that
starts with `subject claim`. The credential has to match it exactly:

```shell
az ad app federated-credential list --id "$APP_ID" \
  --query "[].{name:name, subject:subject}" --output table
```

If they differ, correct the credential. Use the subject from the log:

```shell
az ad app federated-credential update --id "$APP_ID" \
  --federated-credential-id github-production \
  --parameters '{
    "name": "github-production",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "<the subject claim from the log>",
    "audiences": ["api://AzureADTokenExchange"]
  }'
```

A change can take a few minutes to reach all of Microsoft Entra. A step that runs
right after the change can still fail with this error, even though the credential
is correct, so wait a few minutes and run the workflow again.

### `SkuNotAvailable` from the database

`provision-postgres` fails with `Specified SKU is not supported in this region`.
There are two causes, and the time at which it fails tells you which one it is.

* **The request is rejected at once.** The region does not offer the SKU to your
  subscription. `az postgres flexible-server list-skus` (see
  [Choose the settings](#1-choose-the-settings)) shows this and gives the reason.
* **The request is accepted, and fails about a minute later.** The region lists
  the SKU, but Azure could not allocate it in availability zone 1 at that time.
  Azure's error does not say more. The AppHost cannot choose another zone or SKU,
  so the fix is another region.

The SKU list does not predict the second case. A region can list `Standard_B1ms`
with zones `1`, `2` and `3` and still fail. The only reliable check is to create
a server with the same settings that the AppHost uses, and delete it. It takes
about five minutes and costs very little:

```shell
az group create --name rg-standup-skutest --location "$LOCATION"
az postgres flexible-server create \
  --resource-group rg-standup-skutest --location "$LOCATION" \
  --name "standup-skutest-$RANDOM" \
  --tier Burstable --sku-name Standard_B1ms --version 16 \
  --storage-size 32 --zone 1 --public-access None \
  --admin-user skutestadmin --admin-password "Aa1$(openssl rand -hex 12)" \
  --yes

# Delete it, whether it worked or not:
az group delete --name rg-standup-skutest --yes
```

If the `create` fails with `SkuNotAvailable`, choose another region.

Azure's own record of the failure is in the deployment history:

```shell
az deployment group list --resource-group "$RESOURCE_GROUP" \
  --query "[?properties.provisioningState=='Failed'].{name:name, time:properties.timestamp}" \
  --output table
az deployment operation group list --resource-group "$RESOURCE_GROUP" \
  --name <the failed deployment's name> \
  --query "[?properties.provisioningState=='Failed'].properties.statusMessage" \
  --output json
```

To use another region, **use a new resource group**. The earlier run already
created the Container Apps environment, the registry and the other resources in
the old region, and their names come from the resource group, so a deployment to a
new region cannot move them. A new group name gives new names and avoids a clash
with the soft-deleted Key Vault that deleting the old group leaves behind. Run
step 3 and step 5 again for the new group, set the `AZURE_LOCATION` and
`AZURE_RESOURCE_GROUP` variables of the `production` environment, run the
workflow, and delete the old group:

```shell
az group delete --name <the old resource group> --yes --no-wait
```

### `VaultAlreadyExists` from `provision-postgres-kv`

```
Failed to provision postgres-kv: Deployment failed: VaultAlreadyExists: The vault
name 'postgreskv-<suffix>' is already in use.
```

Key Vault names are unique across all of Azure, and the name is made from the
resource group's ID, so a resource group that is deleted and created again with
**the same name** gets the same Key Vault name. Deleting a group only *soft*
deletes its Key Vault, and Azure keeps the name reserved until the vault is
purged (90 days by default). This is what happens when you reuse the old group's
name after a failed deployment, instead of choosing a new name as described above.

If you did reuse the name, find the soft-deleted vault and purge it. **Purging
cannot be undone**, so check that the vault is one that you no longer need. A vault
that a failed first deployment created is empty, because Aspire only stores the
database connection string in it after the database is provisioned.

```shell
az keyvault list-deleted \
  --query "[].{name:name, location:properties.location, deleted:properties.deletionDate}" \
  --output table

az keyvault purge --name <the vault's name> --location <the vault's location>
```

Then run the workflow again.

## Things to know

* **Database migrations run when the container starts**, before the server
  starts. That is fine for one replica. If the app is scaled out, move the
  migrations to a separate Azure Container Apps job.
* **The database credentials come from the `DB_USER` and `DB_PASSWORD`
  secrets.** They set the server's administrator at provisioning time, so keep
  them stable, and change them with care.
* **The database is reachable from the app over TLS** (`DATABASE_SSL=true`),
  and the app verifies the server's certificate.
* Aspire keeps a small deployment cache, so a repeated deployment can skip work
  that has not changed. It is not needed to run the workflow.

## Removing everything

This deletes the Container App, the database and all of its data, the registry,
and the other resources. It cannot be undone.

```shell
az group delete --name "$RESOURCE_GROUP"
```
