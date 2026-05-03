# Kompakter Plan

```text
roles/
  coredns/
  k3s/
  cilium/
  exfil_test/
  exfil_cases/
```

## Zuständigkeit

```text
coredns      -> autoritativer DNS-Server
k3s          -> Kubernetes-Cluster
cilium       -> Cilium per Helm installieren
exfil_test   -> Namespace + Test-Pod
exfil_cases  -> Policies je nach Fall setzen
```

## `exfil_cases` Struktur

```text
roles/exfil_cases/
  defaults/
    main.yml

  tasks/
    main.yml
    cleanup.yml
    apply_case1.yml
    apply_case2.yml
    apply_case3.yml
    apply_case4.yml

  templates/
    case2-deny-all-egress.yaml.j2
    case3-allow-dns-egress.yaml.j2
    case4-cilium-dns-restriction.yaml.j2
```

## Steuerung

```yaml
exfil_case: 1
```

## Cases

```text
case 1:
  offen
  cleanup
  keine Policy anwenden

case 2:
  deny-all egress
  Kubernetes NetworkPolicy

case 3:
  deny-all egress
  allow UDP 53 zu 10.10.1.12
  Kubernetes NetworkPolicy

case 4:
  nur CiliumNetworkPolicy (keine Kubernetes NetworkPolicy parallel — sonst öffnet diese L4 ohne L7)
  toCIDRSet: DNS-VM-Host /32
  toPorts: UDP/53
  rules.dns: matchName allowed.exfil.test  -> Cilium DNS-Proxy erzwingt L7 auch bei `dig @<DNS-VM>`
```

## Cleanup

```bash
kubectl delete netpol -n exfil-test --all --ignore-not-found
kubectl delete cnp -n exfil-test --all --ignore-not-found
```

## Ablauf pro Case

```text
1. Cleanup ausführen
2. passende Policy rendern
3. kubectl apply
4. aktive Policies anzeigen
5. DNS-Test durchführen
6. CoreDNS-Logs prüfen
```
