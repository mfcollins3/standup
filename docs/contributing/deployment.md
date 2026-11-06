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
LOCATION="westus3"                     # an Azure region
RESOURCE_GROUP="rg-standup-production"
GITHUB_REPOSITORY="mfcollins3/standup"
```

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

```shell
APP_ID="$(az ad app create --display-name "standup-github-deploy" \
  --query appId --output tsv)"
az ad sp create --id "$APP_ID"

az ad app federated-credential create --id "$APP_ID" --parameters "$(cat <<EOF
{
  "name": "github-production",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "repo:${GITHUB_REPOSITORY}:environment:production",
  "audiences": ["api://AzureADTokenExchange"]
}
EOF
)"
```

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
