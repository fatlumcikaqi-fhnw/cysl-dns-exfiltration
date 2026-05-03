# Plan

## 0. Baseline-Infrastruktur

- 3 Debian-VMs mit OpenTofu und cloud-init (`sites/switch-engines`): ein privates Subnetz, Security Group mit SSH/ICMP von überall; **nur `cysl-controlplane` mit Floating IP** (Worker/CoreDNS nur über private IPs, z. B. via Jump über die Controlplane).
  - `cysl-controlplane`
  - `cysl-worker`
  - `cysl-coredns`
- Auf 2 VMs einen minimalen `k3s`-Cluster aufbauen
- Auf `cysl-coredns` einen autoritativen DNS für eine Test-Domain betreiben
- Alles mit Ansible konfigurieren
- Ziel: reproduzierbare Grundumgebung, noch **ohne Experimente**

## 1. Fall: Offene Baseline ohne Egress-Beschränkung

- Keine NetworkPolicy
- Test-Pod im Cluster starten
- DNS-Anfragen an die eigene Test-Domain senden
- Nachweisen, dass die Queries am autoritativen DNS ankommen
- Ziel: Messaufbau und Exfiltrationspfad grundsätzlich verifizieren

## 2. Fall: Default-Deny-Egress

- Egress für den Test-Pod komplett verbieten
- Erneut DNS-Test durchführen
- Prüfen, ob DNS und damit auch Exfiltration blockiert sind
- Ziel: Referenzfall für „vollständig gesperrt“

## 3. Fall: Default-Deny-Egress + DNS explizit erlaubt

- Weiterhin Default-Deny
- Zusätzlich nur DNS zu CoreDNS erlauben
- Erneut DNS-Test durchführen
- Prüfen, ob Exfiltration über DNS wieder möglich ist
- Ziel: Hauptnachweis der Arbeit

## 4. Fall: Default-Deny-Egress + DNS erlaubt + Gegenmassnahme

- Gleicher Stand wie Fall 3
- Zusätzlich **eine** Gegenmassnahme aktivieren
- Empfehlung: **Cilium DNS-/FQDN-Policy**
- Erneut DNS-Test durchführen
- Prüfen, ob Exfiltration verhindert oder zumindest stark eingeschränkt wird
- Ziel: Wirksamkeit einer konkreten Schutzmassnahme bewerten

---

### Einheitliches Vorgehen in jedem Fall

- Gleicher Namespace
- Gleicher Test-Pod
- Gleiche Testdaten
- Gleiche DNS-Testmethode
- Gleiche Auswertung:
  - Query geht durch: ja/nein
  - Exfiltration möglich: ja/nein
  - Logs oder Beobachtbarkeit vorhanden: ja/nein

### Erwartetes Ergebnis

- Fall 1 zeigt: Setup funktioniert
- Fall 2 zeigt: vollständiges Egress-Deny blockiert DNS
- Fall 3 zeigt: DNS-Ausnahme öffnet potenziell den Exfiltrationskanal wieder
- Fall 4 zeigt: eine gezielte Gegenmassnahme reduziert oder verhindert dieses Risiko
