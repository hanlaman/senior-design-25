import * as resources from "@pulumi/azure-native/resources";
import * as pulumi from "@pulumi/pulumi";

const stack = pulumi.getStack();

// Create an Azure Resource Group
const resourceGroup = new resources.ResourceGroup(`senior-design-${stack}`);

// Export the resource group name
export const resourceGroupName = resourceGroup.name;