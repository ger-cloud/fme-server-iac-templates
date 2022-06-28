@description('Value for owner tag.')
param ownerValue string 

@description('Location for the resources.')
param location string = resourceGroup().location

@description('Size of VMs in the Core VM Scale Set.')
param vmSizeCore string = 'Standard_D2s_v3'

@description('Size of VMs in the Engine VM Scale Set.')
param vmSizeEngine string = 'Standard_D2s_v3'

@description('Name of the VM Scaleset for the Core machines')
@maxLength(61)
param vmssNameCore string = 'fmeserver-core'

@description('Name of the VM Scaleset for the Engine machines')
@maxLength(61)
param vmssNameEngine string = 'fmeserver-engine'

@description('Number of Core VM instances.')
param instanceCountCore int = 1

@description('Number of Engine VM instances.')
param instanceCountEngine int = 1

@description('Determines whether or not a new storage account should be provisioned.')
param storageNewOrExisting string = 'new'

@description('Name of the storage account')
param storageAccountName string = 'fmeserver${uniqueString(resourceGroup().id)}'

@description('Name of the resource group for the existing virtual network')
param storageAccountResourceGroup string

@description('Name of the Postgresql server')
param postgresServerName string = 'fmeserver-postgresql-${uniqueString(resourceGroup().id)}'

@description('Determines whether or not a new virtual network should be provisioned.')
param virtualNetworkNewOrExisting string = 'new'

@description('Name of the virtual network')
param virtualNetworkName string = 'fmeserver-vnet'

@description('Address prefix of the virtual network')
param addressPrefixes array = [
  '10.0.0.0/16'
]

@description('Name of the subnet')
param subnetName string = 'default'

@description('Subnet prefix of the virtual network')
param subnetPrefix string = '10.0.0.0/24'

@description('Name of the subnet for the Application Gateway')
param subnetAGName string = 'AGSubnet'

@description('Subnet prefix of the Application Gateway subnet')
param subnetAGPrefix string = '10.0.1.0/24'

@description('Name of the resource group for the existing virtual network')
param virtualNetworkResourceGroup string

@description('Determines whether or not a new public ip should be provisioned.')
param publicIpNewOrExisting string = 'new'

@description('Name of the public ip address')
param publicIpName string = 'fmeserver-pip'

@description('DNS of the public ip address for the VM')
param publicIpDns string = 'fmeserver-${uniqueString(resourceGroup().id)}'

@description('Allocation method for the public ip address')
@allowed([
  'Dynamic'
  'Static'
])
param publicIpAllocationMethod string = 'Dynamic'

@description('Name of the resource group for the public ip address')
@allowed([
  'Basic'
  'Standard'
])
param publicIpSku string = 'Basic'

@description('Name of the resource group for the existing virtual network')
param publicIpResourceGroup string

@description('Name of the resource group for the existing virtual network')
param applicationGatewayName string = 'fmeserver-appgateway'

@description('Name of the resource group for the existing virtual network')
param engineRegistrationLoadBalancerName string = 'fmeserver-engineregistration'

@description('Admin username on all VMs.')
param adminUsername string

@description('Admin password on all VMs.')
@secure()
param adminPassword string

var tags = {
  'owner': ownerValue 
}
var applicationGatewayBackEndName = 'applicationGatewayBackEnd'
var engineRegistrationloadBalancerFrontEndName = 'engineRegistrationFrontend'
var engineRegistrationloadBalancerBackEndName = 'engineRegistrationBackend'
var postgresqlAdministratorLogin = 'postgres'
var postgresqlAdministratorLoginPassword = 'P${uniqueString(resourceGroup().id, deployment().name, 'ad909260-dc63-4102-983f-4f82af7a6840')}x!'
var filesharename = 'fmeserverdata'
var vnetId = {
  new: virtualNetworkName_resource.id
  existing: resourceId(virtualNetworkResourceGroup, 'Microsoft.Network/virtualNetworks', virtualNetworkName)
}
var storageAccountId = {
  new: storageAccountName_resource.id
  existing: resourceId(storageAccountResourceGroup, 'Microsoft.Storage/storageAccounts', storageAccountName)
}
var publicIpId = {
  new: publicIpName_resource.id
  existing: resourceId(publicIpResourceGroup, 'Microsoft.Network/publicIPAddresses', publicIpName)
}
var storageAccountIdString = storageAccountId[storageNewOrExisting]
var publicIpIdString = '${publicIpId[storageNewOrExisting]}'
var subnetId = '${vnetId[virtualNetworkNewOrExisting]}/subnets/${subnetName}'
var subnetAGId = '${vnetId[virtualNetworkNewOrExisting]}/subnets/${subnetAGName}'

resource vmssNameCore_resource 'Microsoft.Compute/virtualMachineScaleSets@2021-03-01' = {
  name: vmssNameCore
  location: location
  sku: {
    name: vmSizeCore
    capacity: instanceCountCore
  }
  plan: {
    publisher: 'safesoftwareinc'
    name: 'fme-core-2022-0-0-2-windows-byol'
    product: 'fme-core'
  }
  properties: {
    overprovision: false
    upgradePolicy: {
      mode: 'Manual'
    }
    virtualMachineProfile: {
      storageProfile: {
        osDisk: {
          createOption: 'FromImage'
          caching: 'ReadWrite'
        }
        imageReference: {
          publisher: 'safesoftwareinc'
          offer: 'fme-core'
          sku: 'fme-core-2022-0-0-2-windows-byol'
          version: '1.0.0'
        }
      }
      osProfile: {
        computerNamePrefix: 'core'
        adminUsername: adminUsername
        adminPassword: adminPassword
      }
      networkProfile: {
        networkInterfaceConfigurations: [
          {
            name: 'nic-core'
            properties: {
              primary: true
              ipConfigurations: [
                {
                  name: 'ipconfig'
                  properties: {
                    subnet: {
                      id: subnetId
                    }
                    loadBalancerBackendAddressPools: [
                      {
                        id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', engineRegistrationLoadBalancerName, engineRegistrationloadBalancerBackEndName)
                      }
                    ]
                    applicationGatewayBackendAddressPools: [
                      {
                        id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', applicationGatewayName, applicationGatewayBackEndName)
                      }
                    ]
                  }
                }
              ]
            }
          }
        ]
      }
      extensionProfile: {
        extensions: [
          {
            name: 'customScript'
            properties: {
              publisher: 'Microsoft.Compute'
              protectedSettings: {
                commandToExecute: 'powershell -ExecutionPolicy Unrestricted -File C:\\config_fmeserver_confd.ps1 -databasehostname ${pgsql.outputs.postgresFqdn} -databasePassword ${postgresqlAdministratorLoginPassword} -databaseUsername ${postgresqlAdministratorLogin} -externalhostname ${reference(publicIpIdString).dnsSettings.fqdn} -storageAccountName ${storageAccountName} -storageAccountKey ${listKeys(storageAccountIdString, '2019-04-01').keys[0].value} >C:\\confd-log.txt 2>&1'
              }
              typeHandlerVersion: '1.8'
              autoUpgradeMinorVersion: true
              type: 'CustomScriptExtension'
            }
          }
        ]
      }
    }
  }
  tags: tags
}

resource vmssNameEngine_resource 'Microsoft.Compute/virtualMachineScaleSets@2021-03-01' = {
  name: vmssNameEngine
  location: location
  sku: {
    name: vmSizeEngine
    capacity: instanceCountEngine
  }
  plan: {
    publisher: 'safesoftwareinc'
    name: 'fme-engine-2022-0-0-2-windows-byol'
    product: 'fme-engine'
  }
  properties: {
    overprovision: false
    upgradePolicy: {
      mode: 'Manual'
    }
    virtualMachineProfile: {
      storageProfile: {
        osDisk: {
          createOption: 'FromImage'
          caching: 'ReadWrite'
        }
        imageReference: {
          publisher: 'safesoftwareinc'
          offer: 'fme-engine'
          sku: 'fme-engine-2022-0-0-2-windows-byol'
          version: '1.0.0'
        }
      }
      osProfile: {
        computerNamePrefix: 'engine'
        adminUsername: adminUsername
        adminPassword: adminPassword
      }
      networkProfile: {
        networkInterfaceConfigurations: [
          {
            name: 'nic-engine'
            properties: {
              primary: true
              ipConfigurations: [
                {
                  name: 'ipconfig'
                  properties: {
                    subnet: {
                      id: subnetId
                    }
                  }
                }
              ]
            }
          }
        ]
      }
      extensionProfile: {
        extensions: [
          {
            name: 'customScript'
            properties: {
              publisher: 'Microsoft.Compute'
              protectedSettings: {
                commandToExecute: 'powershell -ExecutionPolicy Unrestricted -File C:\\config_fmeserver_confd_engine.ps1 -databasehostname ${pgsql.outputs.postgresFqdn} -engineregistrationhost ${engineRegistrationLoadBalancerName_resource.properties.frontendIPConfigurations[0].properties.privateIPAddress} -storageAccountName ${storageAccountName} -storageAccountKey ${listKeys(storageAccountIdString, '2019-04-01').keys[0].value} >C:\\confd-log.txt 2>&1'
              }
              typeHandlerVersion: '1.8'
              autoUpgradeMinorVersion: true
              type: 'CustomScriptExtension'
            }
          }
        ]
      }
    }
  }
  tags: tags
}

resource virtualNetworkName_resource 'Microsoft.Network/virtualNetworks@2021-03-01' = if (virtualNetworkNewOrExisting == 'new') {
  name: virtualNetworkName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: addressPrefixes
    }
    subnets: [
      {
        name: subnetName
        properties: {
          addressPrefix: subnetPrefix
          serviceEndpoints: [
            {
              service: 'Microsoft.Storage'
            }
            {
              service: 'Microsoft.Sql'
            }
          ]
          privateEndpointNetworkPolicies: 'Enabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
      {
        name: subnetAGName
        properties: {
          addressPrefix: subnetAGPrefix
          privateEndpointNetworkPolicies: 'Enabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
    ]
  }
  tags: tags
}

resource publicIpName_resource 'Microsoft.Network/publicIPAddresses@2021-03-01' = if (publicIpNewOrExisting == 'new') {
  name: publicIpName
  location: location
  sku: {
    name: publicIpSku
  }
  properties: {
    publicIPAllocationMethod: publicIpAllocationMethod
    dnsSettings: {
      domainNameLabel: toLower(publicIpDns)
    }
    idleTimeoutInMinutes: 30
  }
  tags: tags
}

resource engineRegistrationLoadBalancerName_resource 'Microsoft.Network/loadBalancers@2021-03-01' = {
  name: engineRegistrationLoadBalancerName
  location: location
  properties: {
    frontendIPConfigurations: [
      {
        name: engineRegistrationloadBalancerFrontEndName
        properties: {
          subnet: {
            id: subnetId
          }
          privateIPAllocationMethod: 'Dynamic'
        }
      }
    ]
    backendAddressPools: [
      {
        name: engineRegistrationloadBalancerBackEndName
      }
    ]
    loadBalancingRules: [
      {
        name: 'roundRobinEngineRegistrationRule'
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/loadBalancers/frontendIPConfigurations', engineRegistrationLoadBalancerName, engineRegistrationloadBalancerFrontEndName)
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', engineRegistrationLoadBalancerName, engineRegistrationloadBalancerBackEndName)
          }
          protocol: 'Tcp'
          frontendPort: 7070
          backendPort: 7070
          enableFloatingIP: false
          idleTimeoutInMinutes: 30
        }
      }
    ]
  }
  tags: tags
}

resource applicationGatewayName_resource 'Microsoft.Network/applicationGateways@2021-08-01' = {
  name: applicationGatewayName
  location: location
  properties: {
    sku: {
      name: 'Standard_Medium'
      tier: 'Standard'
      capacity: 1
    }
    gatewayIPConfigurations: [
      {
        name: 'appGatewayIpConfig'
        properties: {
          subnet: {
            id: subnetAGId
          }
        }
      }
    ]
    frontendIPConfigurations: [
      {
        name: 'appGwPublicFrontendIp'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: publicIpIdString
          }
        }
      }
    ]
    frontendPorts: [
      {
        name: 'port_80'
        properties: {
          port: 80
        }
      }
      {
        name: 'port_7078'
        properties: {
          port: 7078
        }
      }
    ]
    probes: [
      {
        properties: {
          protocol: 'Http'
          path: '/'
          interval: 30
          timeout: 30
          unhealthyThreshold: 3
          pickHostNameFromBackendHttpSettings: true
          match: {
            statusCodes: [
              '200-400'
            ]
          }
        }
        name: 'websocketProbe'
      }
    ]
    backendAddressPools: [
      {
        name: applicationGatewayBackEndName
      }
    ]
    backendHttpSettingsCollection: [
      {
        name: 'httpSetting'
        properties: {
          port: 8080
          protocol: 'Http'
          cookieBasedAffinity: 'Disabled'
          pickHostNameFromBackendAddress: false
          requestTimeout: 86400
        }
      }
      {
        name: 'websocketSetting'
        properties: {
          port: 7078
          protocol: 'Http'
          cookieBasedAffinity: 'Disabled'
          pickHostNameFromBackendAddress: true
          requestTimeout: 86400
          probe: {
            id: resourceId('Microsoft.Network/applicationGateways/probes', applicationGatewayName, 'websocketProbe')
          }
        }
      }
    ]
    httpListeners: [
      {
        name: 'httpListener'
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations', applicationGatewayName, 'appGwPublicFrontendIp')
          }
          frontendPort: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendPorts', applicationGatewayName, 'port_80')
          }
          protocol: 'Http'
          requireServerNameIndication: false
        }
      }
      {
        name: 'websocketListener'
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations', applicationGatewayName, 'appGwPublicFrontendIp')
          }
          frontendPort: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendPorts', applicationGatewayName, 'port_7078')
          }
          protocol: 'Http'
          requireServerNameIndication: false
        }
      }
    ]
    requestRoutingRules: [
      {
        name: 'httpRoutingRule'
        properties: {
          ruleType: 'Basic'
          httpListener: {
            id: resourceId('Microsoft.Network/applicationGateways/httpListeners', applicationGatewayName, 'httpListener')
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', applicationGatewayName, applicationGatewayBackEndName)
          }
          backendHttpSettings: {
            id: resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection', applicationGatewayName, 'httpSetting')
          }
        }
      }
      {
        name: 'websocketRoutingRule'
        properties: {
          ruleType: 'Basic'
          httpListener: {
            id: resourceId('Microsoft.Network/applicationGateways/httpListeners', applicationGatewayName, 'websocketListener')
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', applicationGatewayName, applicationGatewayBackEndName)
          }
          backendHttpSettings: {
            id: resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection', applicationGatewayName, 'websocketSetting')
          }
        }
      }
    ]
    enableHttp2: false
  }
  tags: tags
}

module pgsql 'modules/database/pgsql.bicep' = {
  name: 'fme-server-pgsql'
  params: {
    location: location
    postgresqlAdministratorLogin: postgresqlAdministratorLogin
    postgresqlAdministratorLoginPassword: postgresqlAdministratorLoginPassword 
    postgresServerName: postgresServerName 
    subnetId:subnetId 
    tags: tags
  }
}

// resource postgresServerName_resource 'Microsoft.DBforPostgreSQL/servers@2017-12-01' = {
//   location: location
//   name: postgresServerName
//   sku: {
//     name: 'GP_Gen5_2'
//     tier: 'GeneralPurpose'
//     capacity: 2
//     size: '51200'
//     family: 'Gen5'
//   }
//   properties: {
//     version: '10'
//     createMode: 'Default'
//     administratorLogin: postgresqlAdministratorLogin
//     administratorLoginPassword: postgresqlAdministratorLoginPassword
//   }
//   tags: tags
// }

// resource postgresServerName_postgres_vnet_rule 'Microsoft.DBforPostgreSQL/servers/virtualNetworkRules@2017-12-01' = {
//   parent: postgresServerName_resource
//   name: 'postgres-vnet-rule'
//   properties: {
//     virtualNetworkSubnetId: subnetId
//     ignoreMissingVnetServiceEndpoint: true
//   }
// }

// resource postgresServerName_postgres 'Microsoft.DBforPostgreSQL/servers/databases@2017-12-01' = {
//   parent: postgresServerName_resource
//   name: 'postgres'
//   properties: {
//     charset: 'utf8'
//     collation: 'English_United States.1252'
//   }
// }

// Storage module is currently not supported because of limitation to pass on secrets from modules
//
// module storage 'modules/storage/storage.bicep' = if (storageNewOrExisting == 'new') {
//   name: 'fme-server-storage'
//   params: {
//     fileShareName: '${storageAccountName}/default/${filesharename}'
//     location: location
//     storageAccountName: storageAccountName 
//     subnetId: subnetId
//     tags: tags
//   }
// }

resource storageAccountName_resource 'Microsoft.Storage/storageAccounts@2021-02-01' = if (storageNewOrExisting == 'new') {
  name: storageAccountName
  location: location
  kind: 'FileStorage'
  sku: {
    name: 'Premium_LRS'
  }
  properties: {
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
      virtualNetworkRules: [
        {
          id: subnetId
        }
      ]
    }
  }
  tags: tags
}

resource storageAccountName_default_filesharename 'Microsoft.Storage/storageAccounts/fileServices/shares@2021-09-01' = {
  name: '${storageAccountName}/default/${filesharename}'
}

output fqdn string = reference(publicIpIdString).dnsSettings.fqdn
