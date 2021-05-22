
<table align="center"><tr><td align="center" width="9999">

## **<center>BUILD and AST  TESTS DOCUMENTATION <br/> ![enter image description here](https://www.w6d.io/images/Logo.svg)w6d.io![enter image description here](https://www.w6d.io/images/Logo.svg)<center/>**
</td></tr></table>
<table align="center"><tr><td align="center" width="9999">
<center>
SUMMARY

|      SAST       |       DAST      |       BUILD     |
| :---------------: | :---------------:| :---------------: |
|* [Gitleaks](#GITLEAKS)|* [Clair](#CLAIR)|* [SBT](#GITLEAKS)|
|* [Codecov]( #CODECOV)|* [Owasp ZAP](#OWASPZAP)|* [Quasar](#QUASAR)|
|* [Sonarqube](#SONARQUBE)|* [Nmap](#NMAP)||
<center/>
</td></tr></table>


### gitleaks ![enter image description here](https://www.w6d.io/images/Logo.svg)
<table align="center"><tr><td align="center" width="9999">

**<center>**GITLEAKS** (secret discovery SAST)<center/>**<br/>![enter image description here](https://raw.githubusercontent.com/zricethezav/gifs/master/gitleakslogo.png)
##
</td></tr></table>
 - **Preface**
 Gitleaks is a SAST tool for detecting hardcoded secrets like passwords, api keys, and tokens in git repos. Gitleaks is an **easy-to-use, all-in-one solution** for finding secrets, past or present, in your code.

 - **Prerequisite:**
    NaN

 - **CI-OPERATOR Configuration.**
```
apiVersion: ci.w6d.io/v1alpha1
kind: Step
metadata:
  name: static-test-gitleakspathscan
  labels:
  {{- include "ci-operator.labels" . | nindent 4 }}
  annotations:
    ci.w6d.io/kind: generic
    ci.w6d.io/task: static-test
    ci.w6d.io/order: "0"
params:
  - name: CLIENT_HTTP_REPOSITORY_URL
    type: string
step:
  name: static-test-gitleakspathscan
  image: "zricethezav/gitleaks:latest"
  script: |
    mkdir -p $(workspaces.source.path)/tests/report-gitleaks
    cd $(workspaces.source.path)/tests/
    git clone $(params.CLIENT_HTTP_REPOSITORY_URL) repo-gitleaks
    gitleaks --path="repo-gitleaks/" -v --report=$(workspaces.source.path)/tests/report-gitleaks/report-pathsecretsscan.json

```
 ### -**Variables**
 - **Clients found:**
  ```
 Basic scan on local repo:
repository_http_link= <the project client repository url>
```

### codecov ![enter image description here](https://www.w6d.io/images/Logo.svg)
<table align="center"><tr><td align="center" width="9999">

**<center>**CODECOV**  (recovery rating SAST)<br/>![enter image description here](https://camo.githubusercontent.com/692d51b2ffcee37fc8ac7e75229128a225d3d9b57e294c7d848b73a059f2db57/68747470733a2f2f636f6465636f762e696f2f67682f636f6465636f762f636f6465636f762d626173682f6272616e63682f6d61737465722f67726170682f62616467652e7376673f746f6b656e3d69457653546e5739516d)<center/>**
 ##
 </td></tr></table>
  - **Preface**
Codecov delivers  _or "injects"_coverage metrics directly into the modern workflow to promote more code coverage, especially in pull requests where new features and bug fixes commonly occur.

 - **Prerequisite**


 - [ ] Create your account on [Codecov](https://about.codecov.io/sign-up/)
 - [ ]  link your project
 - [ ] Generate a Token
    For more see the [Codecov documentation](https://docs.codecov.io/docs/quick-start)

 - **CI-OPERATOR Configuration.**

```
apiVersion: ci.w6d.io/v1alpha1
kind: Step
metadata:
  name: static-test-codecov
  labels:
  {{- include "ci-operator.labels" . | nindent 4 }}
  annotations:
    ci.w6d.io/kind: generic
    ci.w6d.io/task: static-test
    ci.w6d.io/order: "0"
params:
  - name: INTERNAL_CODECOV_URL
    type: string
  - name: CLIENT_CODECOV_TOKEN
    type: string
step:
  name: static-test-codecov
  image: "bash"
  script: |
    mkdir -p $(workspaces.source.path)/tests/report-codecov
    cd $(workspaces.source.path)/tests/
    echo y | apk add --no-cache curl
    bash <(curl -s $(params.INTERNAL_CODECOV_URL)) -t $(params.CLIENT_CODECOV_TOKEN) -f $(workspaces.source.path)/tests/report-codecov/cover.out

```
 ### -**Variables**
 - **Internal:**
```
INTERNAL_CODECOV_LINK= <https://codecov.io/bash> //link to Codecov
```
 - **Client found:**
  ```
CLIENT_CODECOV_TOKEN= <token generate by Codecov>
```

### clair![enter image description here](https://www.w6d.io/images/Logo.svg)
<table align="center"><tr><td align="center" width="9999">

**<center>**Clair**  (Image Scanner DAST)<br/>![enter image description here](https://cloud.githubusercontent.com/assets/343539/21630811/c5081e5c-d202-11e6-92eb-919d5999c77a.png)<center/>**
 ##
 </td></tr></table>
  - **Preface**
Clair is an open source project for the  [static analysis](https://en.wikipedia.org/wiki/Static_program_analysis)  of vulnerabilities in application containers (currently including  [OCI](https://github.com/opencontainers/image-spec/blob/master/spec.md)  and  [docker](https://github.com/docker/docker/blob/master/image/spec/v1.2.md)). Clients use the Clair API to index their container images and can then match it against known vulnerabilities. Our goal is to enable a more transparent view of the security of container-based infrastructure. Thus, the project was named  `Clair`

 - **Prerequisite**
 - [ ] Install the **api clair** with [helm chart](https://github.com/quay/clair/tree/3617b7a12646d9d5f68ec057ed327b2f16ffeafb/contrib/helm/clair/templates) in the k8s cluster.
`helm install my-clair wiremind/clair --version 0.2.6\n\n`
 - [ ] Verify if the k8s service respond on curl command:
`k describe service my-clair-clair`
`curl -X GET -I http://<IP of k8s service>:6061/health`
 - [ ] Read the [documentation on **Clair api**](https://quay.github.io/clair/howto/api.html)
 - [ ]  Read the [documentation on **Klar**](https://github.com/optiopay/klar)

 - **CI-OPERATOR Configuration.**

```
apiVersion: ci.w6d.io/v1alpha1
kind: Step
metadata:
  name: static-test-clair
  labels:
  {{- include "ci-operator.labels" . | nindent 4 }}
  annotations:
    ci.w6d.io/kind: generic
    ci.w6d.io/task: static-test
    ci.w6d.io/order: "0"
params:
  - name: CLIENT_IMAGE_URL
    type: string
  - name: CLIENT_DOCKER_USER
    type: string
  - name: CLIENT_DOCKER_PASSWORD
    type: string
  - name: INTERNAL_CLAIR_URL
    type: string
step:
  name: static-test-clair
  image: "golang"
  script: |
    mkdir -p $(workspaces.source.path)/tests/report-clair
    cd $(workspaces.source.path)/tests/
    git clone https://github.com/Portshift/klar.git klar
    cd klar
    go build
    CLAIR_ADDR=(params.INTERNAL_CLAIR_URL) CLAIR_OUTPUT=High CLAIR_THRESHOLD=10 JSON_OUTPUT=true DOCKER_USER=$(params.CLIENT_DOCKER_USER) DOCKER_PASSWORD=$(params.CLIENT_DOCKER_PASSWORD) ./klar $(params.CLIENT_IMAGE_URL) > ../report-clairklar.json
---
```
 ### -**Variables**
 - **Internal:**
```
INTERNAL_CLAIR_URL = <CLAIR URL IN CLUSTER>
Example: INTERNAL_CLAIR_URL=100.66.104.108:6060
```
 - **Client found:**
  ```
CLIENT_IMAGE_URL= <URL REGISTRY>
CLIENT_DOCKER_USER = <USERNAME CREDENTIAL REGISTRY>
CLIENT_DOCKER_USER = <PASSWORD REGISTRY>
```

### OWASPZAP ![enter image description here](https://www.w6d.io/images/Logo.svg)
<table align="center"><tr><td align="center" width="9999">

**<center>**OWASP ZAP** ( Proxy Scan DAST)<center/>**<br/>![enter image description here](https://raw.githubusercontent.com/wiki/zaproxy/zaproxy/images/zap32x32.png)
##
</td></tr></table>
 - **Preface**
OWASP Zed Attack Proxy (ZAP) is a free, open-source penetration testing tool being maintained under the umbrella of the Open Web Application Security Project (OWASP). ZAP is designed specifically for testing web applications and is both flexible and extensible.

 - **Prerequisite:**
    NaN

 - **CI-OPERATOR Configuration.**

   - 1)[OWASP Zap Baseline](https://www.zaproxy.org/docs/docker/baseline-scan/)

```
apiVersion: ci.w6d.io/v1alpha1
kind: Step
metadata:
  name: static-test-owaspbaseline
  labels:
  {{- include "ci-operator.labels" . | nindent 4 }}
  annotations:
    ci.w6d.io/kind: generic
    ci.w6d.io/task: static-test
    ci.w6d.io/order: "0"
params:
  - name: CLIENT_HOST_URL
    type: string
step:
  name: static-test-owaspbaseline
  image: "owasp/zap2docker-stable"
  script: |
    mkdir -p $(workspaces.source.path)/tests/report-owasp
    cd $(workspaces.source.path)/tests/
    mkdir -p /zap/wrk
    zap-baseline.py -t $(params.CLIENT_HOST_URL) -J report-baseline.json -d
    cp /zap/wrk/report-baseline.json $(workspaces.source.path)/tests/report-owasp
```
   - 2) [OWASP Zap GRAPHQL](https://www.zaproxy.org/docs/docker/api-scan/)

```
apiVersion: ci.w6d.io/v1alpha1
kind: Step
metadata:
  name: static-test-owaspgraphql
  labels:
  {{- include "ci-operator.labels" . | nindent 4 }}
  annotations:
    ci.w6d.io/kind: generic
    ci.w6d.io/task: static-test
    ci.w6d.io/order: "0"
params:
  - name: CLIENT_HOST_URL
    type: string
step:
  name: static-test-owaspgraphql
  image: "owasp/zap2docker-stable"
  script: |
    mkdir -p $(workspaces.source.path)/tests/report-owasp
    cd $(workspaces.source.path)/tests/
    mkdir -p /zap/wrk
    zap-api-scan.py -t $(params.CLIENT_HOST_URL) -T 60 -D 30 -f graphql -J report-graphql.json -d -I
    cp /zap/wrk/report-graphql.json $(workspaces.source.path)/tests/report-owasp
```

   - 3) [OWASP Zap FULLSCAN](https://www.zaproxy.org/docs/docker/full-scan/)

```
apiVersion: ci.w6d.io/v1alpha1
kind: Step
metadata:
  name: static-test-owaspfullscan
  labels:
  {{- include "ci-operator.labels" . | nindent 4 }}
  annotations:
    ci.w6d.io/kind: generic
    ci.w6d.io/task: static-test
    ci.w6d.io/order: "0"
params:
  - name: CLIENT_HOST_URL
    type: string
step:
  name: static-test-owaspfullscan
  image: "owasp/zap2docker-stable"
  script: |
    mkdir -p $(workspaces.source.path)/tests/report-owasp
    cd $(workspaces.source.path)/tests/
    mkdir -p /zap/wrk
    zap-full-scan.py -t $(params.CLIENT_HOST_URL) -T 60 -D 30 -J report-fullscan.json -d -I
    cp /zap/wrk/report-fullscan.json $(workspaces.source.path)/tests/report-owasp
```

 ### -**Variables**
 - **Clients found:**
  ```
 Basic scan on local repo:
CLIENT_HOST_URL= <the project client repository url>

Example: CLIENT_HOST_URL=http://deploymgt.test-owasp:8080
```

### NMAP ![enter image description here](https://www.w6d.io/images/Logo.svg)
<table align="center"><tr><td align="center" width="9999">

**<center>**NMAP** ( network discovery and security auditing Scan DAST)<center/>**<br/>![@nmap](https://avatars.githubusercontent.com/u/63385?s=70&v=4)
##
</td></tr></table>
 - **Preface**
Nmap provides a number of features for probing computer networks, including host discovery and service and operating system detection. These features are extensible by scripts that provide more advanced service detection, vulnerability detection, and other features. Nmap can adapt to network conditions including latency and congestion during a scan.

This Nmap features include:

-   Host discovery – Identifying hosts on a network. For example, listing the hosts that respond to  [TCP](https://en.wikipedia.org/wiki/Transmission_Control_Protocol "Transmission Control Protocol")  and/or  [ICMP](https://en.wikipedia.org/wiki/Internet_Control_Message_Protocol "Internet Control Message Protocol")  requests or have a particular port open.
-   Port scanning – Enumerating the open  ports on target hosts.
-   Version detection – Interrogating network services on remote devices to determine application name and version number.
-   [TCP/IP stack fingerprinting](https://en.wikipedia.org/wiki/TCP/IP_stack_fingerprinting)  – Determining the  [operating system](https://en.wikipedia.org/wiki/Operating_system "Network congestion")  and hardware characteristics of network devices based on observations of network activity of said devices.
-   Scriptable interaction with the target – using Nmap Scripting Engine (NSE) and  [Lua](https://en.wikipedia.org/wiki/Lua_(programming_language) "Lua (programming language)")  programming language.

 - **Prerequisite:**
    NaN

 - **CI-OPERATOR Configuration.**

   - 1)[NMAP IP RANGE SCAN](https://nmap.org/book/man-target-specification.html)

```
apiVersion: ci.w6d.io/v1alpha1
kind: Step
metadata:
  name: static-test-nmapiprangescan
  labels:
  {{- include "ci-operator.labels" . | nindent 4 }}
  annotations:
    ci.w6d.io/kind: generic
    ci.w6d.io/task: static-test
    ci.w6d.io/order: "0"
params:
  - name: CLIENT_IP_RANGE
    type: string
step:
  name: static-test-nmapiprangescan
  image: "instrumentisto/nmap"
  script: |
    mkdir -p $(workspaces.source.path)/tests/nmap
    cd $(workspaces.source.path)/tests/nmap
    nmap -sn $(params.CLIENT_IP_RANGE) -oX report-ipRangeScanNmap.xml
```
   - 2) [NMAP TOP 100 SCAN](https://nmap.org/book/performance-port-selection.html)

```
apiVersion: ci.w6d.io/v1alpha1
kind: Step
metadata:
  name: static-test-nmaptopports100
  labels:
  {{- include "ci-operator.labels" . | nindent 4 }}
  annotations:
    ci.w6d.io/kind: generic
    ci.w6d.io/task: static-test
    ci.w6d.io/order: "0"
params:
  - name: CLIENT_IP
    type: string
step:
  name: static-test-nmaptopports100
  image: "instrumentisto/nmap"
  script: |
    mkdir -p $(workspaces.source.path)/tests/nmap
    cd $(workspaces.source.path)/tests/nmap
    nmap --top-ports 100 $(params.CLIENT_IP) -oX report-topPorts100Nmap.xml
```

   - 3) [NMAP HOST DISCOVERY](https://nmap.org/book/man-host-discovery.html)

```
apiVersion: ci.w6d.io/v1alpha1
kind: Step
metadata:
  name: static-test-nmaphostscan
  labels:
  {{- include "ci-operator.labels" . | nindent 4 }}
  annotations:
    ci.w6d.io/kind: generic
    ci.w6d.io/task: static-test
    ci.w6d.io/order: "0"
params:
  - name: CLIENT_IP
    type: string
step:
  name: static-test-nmaphostscan
  image: "instrumentisto/nmap"
  script: |
    mkdir -p $(workspaces.source.path)/tests/nmap
    cd $(workspaces.source.path)/tests/nmap
    nmap $(params.CLIENT_IP) -oX report-hostScanNmap.xml
```

 ### -**Variables**
 - **Clients found:**
  ```
 The target IP:
CLIENT_IP= <IP>

Example: CLIENT_IP=100.68.54.81
```
