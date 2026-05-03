# Switch Engines — OpenTofu

Provisioniert auf Switch Engines: ein privates Netz mit einem Subnetz, eine Security Group und konfigurierbare VMs (Standard: Debian Trixie aus dem Image-Katalog).

## Voraussetzungen

- OpenTofu installiert
- `terraform.tfvars` angelegt (Vorlage: `terraform.tfvars.example`)

## Credentials setzen

```bash
export OS_AUTH_URL="https://keystone.cloud.switch.ch:5000/v3"
export OS_USERNAME="your-email@fhnw.ch"
export OS_PASSWORD="your-openstack-password"
export OS_PROJECT_ID="your-project-id"
export OS_USER_DOMAIN_NAME="Default"
export OS_REGION_NAME="ZH"
```

Credential-Quellen:

- `OS_PASSWORD`: [SWITCHengines Admin - User Credentials](https://engines.admin.switch.ch/users/4157/credentials_tab)
- Weitere OpenStack-Exports: [SWITCHengines Horizon - API Access](https://engines.switch.ch/horizon/project/api_access/) → `View Credentials`

## Verwendung

```bash
tofu init      # einmalig
tofu plan      # Vorschau
tofu apply     # Infrastruktur erstellen
tofu destroy   # Infrastruktur löschen
```

## Was wird erstellt

| Ressource | Details |
| --- | --- |
| Netzwerk | Ein privates Netz, ein Subnetz (`private_subnet_cidr`), Router mit externem Gateway |
| Security Group | SSH (22) und ICMP von überall (`0.0.0.0/0`); voller Verkehr innerhalb des privaten Subnetzes |
| VMs | Über `instances` in `terraform.tfvars` |
| Floating IPs | Für Einträge mit `floating_ip = true` (Pool: `floating_ip_pool`, Standard `public`) |
| Cloud-init | Automatisch (`../../cloud-init/cloud-init.yml`), pro VM mit `user_data` überschreibbar |

Fest-IPs der VMs sollten außerhalb des DHCP-Allokationsbereichs des Subnetzes liegen (im Modul etwa Host 50–200).

## Outputs

```bash
tofu output floating_ips
tofu output private_ips
```
