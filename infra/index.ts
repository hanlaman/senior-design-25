import * as app from "@pulumi/azure-native/app";
import * as containerregistry from "@pulumi/azure-native/containerregistry";
import * as cosmosdb from "@pulumi/azure-native/cosmosdb";
import * as resources from "@pulumi/azure-native/resources";
import * as sql from "@pulumi/azure-native/sql";
import * as pulumi from "@pulumi/pulumi";
import * as cognitiveservices from './sdks/azure-native_cognitiveservices_v20250401preview/cognitiveservices';

const config = new pulumi.Config();

const stack = pulumi.getStack();

const resourceGroup = new resources.ResourceGroup(`senior-design-${stack}`);

// Create a cognitive services account

const foundryAccountName = `hsdaucsd26${stack}`;
const foundry = new cognitiveservices.Account(`foundry-${stack}`, {
    accountName: foundryAccountName,
    resourceGroupName: resourceGroup.name,
    location: resourceGroup.location,
    kind: "AIServices",
    sku: { 
        name: "S0" 
    },
    identity: {
        type: cognitiveservices.ResourceIdentityType.SystemAssigned,
    },
    properties: {
        customSubDomainName: foundryAccountName,
        apiProperties: {},
        publicNetworkAccess: 'Enabled',
        networkAcls: {
            defaultAction: 'Allow',
            virtualNetworkRules: [],
            ipRules: [],
        },
        allowProjectManagement: true,
        defaultProject: `default-${stack}`,
        associatedProjects: [
            `default-${stack}`
        ]
    },
});

// Create a cognitive services project
const cognitiveProject = new cognitiveservices.Project(`foundry-project-${stack}`, {
    accountName: foundry.name,
    identity: {
        type: cognitiveservices.ResourceIdentityType.SystemAssigned,
    },
    location: resourceGroup.location,
    projectName: `default-${stack}`,
    resourceGroupName: resourceGroup.name,
    properties: {
        description: "Default project for senior design foundry",
        displayName: "default",
    }
});

// Deploy GPT-4o-mini model for conversation summarization
const summarizerDeployment = new cognitiveservices.Deployment(`conversation-summarizer-${stack}`, {
    accountName: foundry.name,
    resourceGroupName: resourceGroup.name,
    deploymentName: "conversation-summarizer",
    properties: {
        model: {
            format: "OpenAI",
            name: "gpt-4o-mini",
            version: "2024-07-18",
        },
        versionUpgradeOption: "OnceCurrentVersionExpired",
    },
    sku: {
        name: "GlobalStandard",
        capacity: 10,
    },
});

// Deploy text-embedding-3-small model for memory semantic search
const embeddingDeployment = new cognitiveservices.Deployment(`text-embedding-3-small-${stack}`, {
    accountName: foundry.name,
    resourceGroupName: resourceGroup.name,
    deploymentName: "text-embedding-3-small",
    properties: {
        model: {
            format: "OpenAI",
            name: "text-embedding-3-small",
            version: "1",
        },
        versionUpgradeOption: "OnceCurrentVersionExpired",
    },
    sku: {
        name: "Standard",
        capacity: 10,
    },
}, { dependsOn: [summarizerDeployment] }); // Deploy after summarizer to avoid rate limits


// Create a Cosmos DB account
const cosmosDbAccount = new cosmosdb.DatabaseAccount(`cosmos-db-account-${stack}`, {
    accountName: `hsdaucsd26${stack}`,
    resourceGroupName: resourceGroup.name,
    location: resourceGroup.location,

    // Identity
    identity: {
        type: cosmosdb.ResourceIdentityType.SystemAssigned,
    },

    // Account type
    kind: cosmosdb.DatabaseAccountKind.GlobalDocumentDB,
    databaseAccountOfferType: cosmosdb.DatabaseAccountOfferType.Standard,

    // Location configuration (single region)
    locations: [{
        locationName: resourceGroup.location,
        failoverPriority: 0,
    }],

    // Backup policy
    backupPolicy: {
        type: "Periodic",
        periodicModeProperties: {
            backupIntervalInMinutes: 240,
            backupRetentionIntervalInHours: 8,
            backupStorageRedundancy: "Local",
        },
    },

    // Network security
    isVirtualNetworkFilterEnabled: false,
    virtualNetworkRules: [],
    ipRules: [],
    minimalTlsVersion: cosmosdb.MinimalTlsVersion.Tls12,

    // Feature configuration
    enableMultipleWriteLocations: false,
    enableFreeTier: true,
    disableLocalAuth: false,
    capabilities: [],

    // Capacity enforcement (1000 RU/s limit for free tier)
    capacity: {
        totalThroughputLimit: 1000,
    },

    // Tags
    tags: {
        "defaultExperience": "Core (SQL)",
        "hidden-workload-type": "Learning",
        "hidden-cosmos-mmspecial": "",
    },
});

// ── Azure Container Registry (Basic) ──────────────────────────────────────────
const registry = new containerregistry.Registry(`acr-${stack}`, {
    registryName: `remind${stack}acr`,
    resourceGroupName: resourceGroup.name,
    location: resourceGroup.location,
    sku: { name: "Basic" },
    adminUserEnabled: true,
});

const registryCreds = containerregistry.listRegistryCredentialsOutput({
    registryName: registry.name,
    resourceGroupName: resourceGroup.name,
});
const acrAdminUsername = registryCreds.username as pulumi.Output<string>;
const acrAdminPassword = registryCreds.passwords!.apply(p => p![0].value!) as pulumi.Output<string>;

// ── Azure SQL Server + Database (Free tier) ───────────────────────────────────
const sqlAdminPassword = config.requireSecret("sqlAdminPassword");

const sqlServer = new sql.Server(`sql-server-${stack}`, {
    serverName: `remind-sql-${stack}`,
    resourceGroupName: resourceGroup.name,
    location: resourceGroup.location,
    administratorLogin: "remindadmin",
    administratorLoginPassword: sqlAdminPassword,
    version: "12.0",
    minimalTlsVersion: "1.2",
    publicNetworkAccess: sql.ServerPublicNetworkAccessFlag.Enabled,
});

const sqlFirewallAllowAzure = new sql.FirewallRule(`sql-fw-azure-${stack}`, {
    serverName: sqlServer.name,
    resourceGroupName: resourceGroup.name,
    firewallRuleName: "AllowAzureServices",
    startIpAddress: "0.0.0.0",
    endIpAddress: "0.0.0.0",
});

const sqlFirewallAllowAll = new sql.FirewallRule(`sql-fw-all-${stack}`, {
    serverName: sqlServer.name,
    resourceGroupName: resourceGroup.name,
    firewallRuleName: "AllowAll",
    startIpAddress: "0.0.0.0",
    endIpAddress: "255.255.255.255",
});

const sqlDatabase = new sql.Database(`sql-db-${stack}`, {
    databaseName: "remind_db",
    serverName: sqlServer.name,
    resourceGroupName: resourceGroup.name,
    location: resourceGroup.location,
    sku: {
        name: "GP_S_Gen5_1",
        tier: "GeneralPurpose",
        family: "Gen5",
        capacity: 1,
    },
    autoPauseDelay: 60,
    minCapacity: 0.5,
});

// ── Log Analytics Workspace (free tier: 5 GB/month ingestion) ─────────────────
import * as operationalinsights from "@pulumi/azure-native/operationalinsights";

const logAnalytics = new operationalinsights.Workspace(`logs-${stack}`, {
    workspaceName: `remind-logs-${stack}`,
    resourceGroupName: resourceGroup.name,
    location: resourceGroup.location,
    sku: { name: "PerGB2018" },
    retentionInDays: 30,
    workspaceCapping: { dailyQuotaGb: 1 },
});

const logAnalyticsKeys = operationalinsights.getSharedKeysOutput({
    workspaceName: logAnalytics.name,
    resourceGroupName: resourceGroup.name,
});

// ── Container Apps Environment (Consumption) ──────────────────────────────────
const containerAppEnv = new app.ManagedEnvironment(`cae-${stack}`, {
    environmentName: `remind-cae-${stack}`,
    resourceGroupName: resourceGroup.name,
    location: resourceGroup.location,
    appLogsConfiguration: {
        destination: "log-analytics",
        logAnalyticsConfiguration: {
            customerId: logAnalytics.customerId,
            sharedKey: logAnalyticsKeys.primarySharedKey as pulumi.Output<string>,
        },
    },
});

// ── Container App (remind-api) ────────────────────────────────────────────────
const betterAuthSecret = config.requireSecret("betterAuthSecret");
const azureOpenAiApiKey = config.requireSecret("azureOpenAiApiKey");
const apnsKeyContents = config.requireSecret("apnsKeyContents");
const apnsKeyId = config.requireSecret("apnsKeyId");
const apnsTeamId = config.requireSecret("apnsTeamId");

const containerApp = new app.ContainerApp(`remind-api-${stack}`, {
    containerAppName: `remind-api-${stack}`,
    resourceGroupName: resourceGroup.name,
    location: resourceGroup.location,
    managedEnvironmentId: containerAppEnv.id,
    configuration: {
        ingress: {
            external: true,
            targetPort: 3000,
            transport: "auto",
        },
        registries: [{
            server: registry.loginServer,
            username: acrAdminUsername,
            passwordSecretRef: "acr-password",
        }],
        secrets: [
            { name: "acr-password", value: acrAdminPassword },
            { name: "sql-password", value: sqlAdminPassword },
            { name: "better-auth-secret", value: betterAuthSecret },
            { name: "azure-openai-api-key", value: azureOpenAiApiKey },
            { name: "apns-key-contents", value: apnsKeyContents },
            { name: "apns-key-id", value: apnsKeyId },
            { name: "apns-team-id", value: apnsTeamId },
        ],
    },
    template: {
        containers: [{
            name: "remind-api",
            image: pulumi.interpolate`${registry.loginServer}/remind-api:latest`,
            resources: {
                cpu: 0.25,
                memory: "0.5Gi",
            },
            env: [
                { name: "PORT", value: "3000" },
                { name: "NODE_ENV", value: "production" },
                { name: "MSSQL_HOST", value: pulumi.interpolate`${sqlServer.name}.database.windows.net` },
                { name: "MSSQL_PORT", value: "1433" },
                { name: "MSSQL_USER", value: "remindadmin" },
                { name: "MSSQL_PASSWORD", secretRef: "sql-password" },
                { name: "MSSQL_DATABASE", value: "remind_db" },
                { name: "MSSQL_ENCRYPT", value: "true" },
                { name: "BETTER_AUTH_SECRET", secretRef: "better-auth-secret" },
                { name: "BETTER_AUTH_URL", value: pulumi.interpolate`https://remind-api-${stack}.${containerAppEnv.defaultDomain}` },
                { name: "AZURE_OPENAI_ENDPOINT", value: pulumi.interpolate`https://${foundryAccountName}.openai.azure.com` },
                { name: "AZURE_OPENAI_API_KEY", secretRef: "azure-openai-api-key" },
                { name: "AZURE_OPENAI_DEPLOYMENT_NAME", value: "conversation-summarizer" },
                { name: "AZURE_OPENAI_EMBEDDING_DEPLOYMENT", value: "text-embedding-3-small" },
                { name: "AZURE_OPENAI_API_VERSION", value: "2024-08-01-preview" },
                { name: "APNS_KEY_CONTENTS", secretRef: "apns-key-contents" },
                { name: "APNS_KEY_ID", secretRef: "apns-key-id" },
                { name: "APNS_TEAM_ID", secretRef: "apns-team-id" },
                { name: "APNS_BUNDLE_ID_WATCH", value: "sd2526.remind.watchapp" },
                { name: "APNS_BUNDLE_ID_IOS", value: "sd2526.remind.caregiverapp" },
            ],
        }],
        scale: {
            minReplicas: 0,
            maxReplicas: 1,
            rules: [{
                name: "http-rule",
                http: { metadata: { concurrentRequests: "10" } },
            }],
        },
    },
});

// ── Exports ───────────────────────────────────────────────────────────────────
export const resourceGroupName = resourceGroup.name;
export const summarizerDeploymentName = summarizerDeployment.name;
export const embeddingDeploymentName = embeddingDeployment.name;
export const apiUrl = containerApp.configuration.apply(c => `https://${c?.ingress?.fqdn}`);
export const sqlServerFqdn = pulumi.interpolate`${sqlServer.name}.database.windows.net`;
export const acrLoginServer = registry.loginServer;