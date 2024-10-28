# Netskope Publisher Azure Deployment 🚀

This Azure Bicep template facilitates the automated deployment of Netskope Publisher instances in Azure environments. It's designed to streamline the deployment process for DevOps teams, enabling quick and consistent Publisher setups while following infrastructure-as-code best practices.

## Supported Functions ✨

* **Azure Integration**: 
  - Automated deployment of Netskope Publisher Marketplace VMs
  - Integration ready for Azure Pipelines
  - End-to-end deployment in 3-4 minutes
* **Network Management**: 
  - Support for existing networking components
  - VNet, Subnet, and NSG integration
  - Option to create new or use existing network components
* **Security & Configuration**:
  - Secure parameter handling through dedicated parameter files
  - API token and SSH key management
  - Cloud-init based post-deployment setup
  - Automated Publisher registration with Netskope tenant

## Project Structure 📁

The deployment consists of three main files:
1. `nsk_deployment.bicep` - Azure deployment template
2. `nsk_deployment.parameters.json` - Configuration file for Azure and Netskope details
3. `nsk_deployment.yaml` - Cloud-init configuration for VM setup and Publisher registration. This script is forked from [Stefano Artioli](https://github.com/sartioli/Publisher-auto-register)

## Prerequisites 📋

- [ ] Azure subscription
- [ ] Azure CLI installed
- [ ] Netskope tenant URL
- [ ] Netskope API token (with required permissions)
- [ ] SSH key pair

### Required API Permissions
The API token needs these permissions:
- `/api/v2/infrastructure/publisherupgradeprofiles` (Read)
- `/api/v2/infrastructure/publishers` (Read + Write)

## Getting Started 🚀

### 1. Install Azure CLI
```bash
# For macOS
brew update && brew install azure-cli

# Login to Azure
az login
```

### 2. Prepare SSH Key
```bash
# Check existing public key
cat ~/.ssh/id_rsa.pub

# Generate from private key
ssh-keygen -y -f ~/.ssh/private_key > ~/.ssh/id_rsa.pub

# Or create new key pair
ssh-keygen -t rsa -b 4096 -C "your_email@example.com"
```

### 3. Configure Parameters
Update the parameters file (`main.parameters.json`):

```json
{
  "parameters": {
    "virtualMachineName": {
      "value": "ZTNAPUB01"
    },
    "adminUsername": {
      "value": "ubuntu"
    },
    "virtualMachineSize": {
      "value": "Standard_D2s_v3"
    },
    "existingVNetName": {
      "value": "your-vnet"
    },
    "tenantUrl": {
      "value": "your-tenant.goskope.com"
    },
    "apiToken": {
      "value": "your-api-token"
    }
  }
}
```

### 4. Deploy
```bash
az deployment group create \
  --resource-group your-rg \
  --template-file nsk_deployment.bicep \
  --parameters @nsk_deployment.parameters.json
```

### 5. Access Publisher VM
```bash
ssh -i ~/.ssh/your_private_key ubuntu@<publisher-ip>
```

## Configuration Reference 📖

| Parameter | Description | Required | Default |
|-----------|-------------|----------|---------|
| `virtualMachineName` | Name for the Publisher VM | Yes | - |
| `adminUsername` | VM admin username (do not change) | Yes | ubuntu |
| `virtualMachineSize` | Azure VM size | Yes | Standard_D2s_v3 |
| `existingVNetName` | Existing VNet name | No | - |
| `existingVNetResourceGroup` | VNet resource group | No | - |
| `existingNsgName` | Existing NSG name | No | - |
| `tenantUrl` | Netskope tenant URL | Yes | - |
| `apiToken` | Netskope API token | Yes | - |
| `pubTag` | Publisher tags (not used currently) | Yes | - |
| `pubUpgrade` | Upgrade profile ID (1 == Default profile) | Yes | 1 |
