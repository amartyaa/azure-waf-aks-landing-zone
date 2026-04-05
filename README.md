# Azure Well-Architected AKS Landing Zone

Production-ready Terraform modules for deploying a **private AKS cluster** inside an **Azure Landing Zone** with hub-spoke networking — all five Well-Architected Framework pillars.

> 📖 Blog: [Azure Well-Architected: Private AKS in a Landing Zone](https://amartya.is-a.dev/blog/azure-well-architected-aks/)

## Quick Start

```bash
git clone https://github.com/amartyaa/azure-waf-aks-landing-zone.git
cd azure-waf-aks-landing-zone
cp environments/dev.tfvars.example environments/dev.tfvars
terraform init && terraform plan -var-file=environments/dev.tfvars
```

## Modules

| Module | Purpose |
|--------|---------|
| `hub-networking` | Hub VNet, Azure Firewall, Bastion, Private DNS |
| `spoke-networking` | Spoke VNet, Peering, UDRs, NSGs |
| `aks-cluster` | Private AKS, node pools, Managed Identity |
| `acr` | Container Registry + Private Endpoint |
| `key-vault` | Key Vault + RBAC + Private Endpoint |
| `monitoring` | Log Analytics, Container Insights, Alerts |
| `governance` | Azure Policy for AKS compliance |

## Prerequisites

- Terraform >= 1.5.0, Azure CLI >= 2.50.0
- Azure subscription with Owner role
- Azure AD group for AKS admins

## License

MIT — [Amartya Anshuman](https://amartya.is-a.dev)
