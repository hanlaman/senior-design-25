import * as cosmosdb from "@pulumi/azure-native/cosmosdb";
import * as resources from "@pulumi/azure-native/resources";
import * as pulumi from "@pulumi/pulumi";
import * as cognitiveservices from './sdks/azure-native_cognitiveservices_v20250401preview/cognitiveservices';

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

// Create a Cosmos DB account
const cosmosDbAccount = new cosmosdb.DatabaseAccount(`cosmos-db-account-${stack}`, {
    accountName: `hsdaucsd26${stack}`,
    resourceGroupName: resourceGroup.name,
    location: resourceGroup.location,

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

export const resourceGroupName = resourceGroup.name;