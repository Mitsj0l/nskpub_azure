// Location parameter with resource group location as default
param location string = resourceGroup().location

// Required parameters
param virtualMachineName string
param adminUsername string
param virtualMachineSize string
param osDiskType string
param osDiskSizeGiB int
param sshPublicKey string

// Optional networking parameters
param existingVNetName string = ''
param existingVNetResourceGroup string = ''
param existingSubnetName string = ''
param existingNsgName string = ''
param existingNsgResourceGroup string = ''
param zone string = '1'

// Netskope configuration parameters
@description('Netskope tenant URL')
@secure()
param tenantUrl string

@description('Netskope API token')
@secure()
param apiToken string

@description('Publisher tag (optional)')
param pubTag string = ''

@description('Publisher upgrade profile')
param pubUpgrade string = '1'

// Variables
var networkInterfaceName = '${virtualMachineName}_z1'
var networkSecurityGroupName = '${virtualMachineName}-nsg'
var newVNetName = '${virtualMachineName}-vnet'
var newSubnetName = 'default'
var useExistingVNet = !empty(existingVNetName)
var useExistingNsg = !empty(existingNsgName)

// Process cloud-init script
var cloudInitScript = loadTextContent('nsk_deployment.yaml')
var cloudInitScriptProcessed = replace(
                                replace(
                                  replace(
                                    replace(
                                      cloudInitScript,
                                      '##TENANT_URL##',
                                      tenantUrl
                                    ),
                                    '##API_TOKEN##',
                                    apiToken
                                  ),
                                  '##PUB_TAG##',
                                  pubTag == '' ? '' : pubTag
                                ),
                                '##PUB_UPGRADE##',
                                pubUpgrade
                              )
var customData = base64(cloudInitScriptProcessed)

// Reference to existing NSG
resource existingNsg 'Microsoft.Network/networkSecurityGroups@2020-05-01' existing = if (useExistingNsg) {
  name: existingNsgName
  scope: resourceGroup(existingNsgResourceGroup)
}

// Network Security Group - Only created if not using existing NSG
resource nsg 'Microsoft.Network/networkSecurityGroups@2020-05-01' = if (!useExistingNsg) {
  name: networkSecurityGroupName
  location: location
  properties: {
    securityRules: [
      {
        name: 'SSH'
        properties: {
          priority: 300
          protocol: 'TCP'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '22'
        }
      }
    ]
  }
}

// New Virtual Network - Only created if not using existing VNet
resource newVnet 'Microsoft.Network/virtualNetworks@2024-01-01' = if (!useExistingVNet) {
  name: newVNetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    subnets: [
      {
        name: newSubnetName
        properties: {
          addressPrefix: '10.0.3.0/24'
          networkSecurityGroup: {
            id: useExistingNsg ? existingNsg.id : nsg.id
          }
        }
      }
    ]
  }
}

// Reference to existing VNet
resource existingVnet 'Microsoft.Network/virtualNetworks@2024-01-01' existing = if (useExistingVNet) {
  name: existingVNetName
  scope: resourceGroup(existingVNetResourceGroup)
}

// Network Interface
resource nic 'Microsoft.Network/networkInterfaces@2022-11-01' = {
  name: networkInterfaceName
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: useExistingVNet ? '${existingVnet.id}/subnets/${existingSubnetName}' : '${newVnet.id}/subnets/${newSubnetName}'
          }
          privateIPAllocationMethod: 'Dynamic'
        }
      }
    ]
    networkSecurityGroup: {
      id: useExistingNsg ? existingNsg.id : nsg.id
    }
  }
}

// Virtual Machine
resource vm 'Microsoft.Compute/virtualMachines@2024-03-01' = {
  name: virtualMachineName
  location: location
  properties: {
    hardwareProfile: {
      vmSize: virtualMachineSize
    }
    storageProfile: {
      osDisk: {
        createOption: 'fromImage'
        managedDisk: {
          storageAccountType: osDiskType
        }
        diskSizeGB: osDiskSizeGiB
        deleteOption: 'Delete'
      }
      imageReference: {
        publisher: 'netskope'
        offer: 'netskope-npa-publisher'
        sku: 'npa_publisher'
        version: 'latest'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
          properties: {
            deleteOption: 'Detach'
          }
        }
      ]
    }
    osProfile: {
      computerName: virtualMachineName
      adminUsername: adminUsername
      customData: customData
      linuxConfiguration: {
        disablePasswordAuthentication: true
        ssh: {
          publicKeys: [
            {
              path: '/home/${adminUsername}/.ssh/authorized_keys'
              keyData: sshPublicKey
            }
          ]
        }
        patchSettings: {
          assessmentMode: 'ImageDefault'
          patchMode: 'ImageDefault'
        }
      }
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
      }
    }
  }
  plan: {
    name: 'npa_publisher'
    publisher: 'netskope'
    product: 'netskope-npa-publisher'
  }
  zones: [
    zone
  ]
}

// Outputs
output adminUsername string = adminUsername
output privateIPAddress string = nic.properties.ipConfigurations[0].properties.privateIPAddress
