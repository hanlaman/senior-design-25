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

export const resourceGroupName = resourceGroup.name;