## **<center>W6D INTEGRATION TESTS DOCUMENTATION <br/> ![enter image description here](https://www.w6d.io/images/Logo.svg)<center/>**
<div  align="center">
SUMMARY
<table>

|      SAST       |       DAST      |       BUILD     |
| :---------------: | :---------------:| :---------------: |
|* [Gitleaks](#gitleaks)|* [Clair](#clair)|* [SBT](#gitleaks)|
|* [Codecov]( #codecov)|* [Owasp ZAP](#owaspzap)|* [Quasar](#quasar)|
|* [Sonarqube](#sonarqube)|* [Nmap](#nmap)||
</table>
</div>

### gitleaks ![enter image description here](https://www.w6d.io/images/Logo.svg)
##
**<center>**GITLEAKS** (secret discovery SAST)<center/>**<br/>![enter image description here](https://www.w6d.io/images/Logo.svg)
##
 - **Preface**
 Gitleaks is a SAST tool for detecting hardcoded secrets like passwords, api keys, and tokens in git repos. Gitleaks is an **easy-to-use, all-in-one solution** for finding secrets, past or present, in your code.

 - **Prerequisite:**
    NaN

 - **CI-OPERATOR Configuration.**
```
apiVersion: ci.w6d.io/v1alpha1
kind: Step
metadata:
  name: test-gitleaks-pathScann
  labels:
  {{- include "ci-operator.labels" . | nindent 4 }}
  annotations:
    ci.w6d.io/kind: generic
    ci.w6d.io/task: test-gitleaks
    ci.w6d.io/order: "0"
params:
  - name: CLIENT_HTTP_REPOSITORY_URL
    type: string
step:
  name: test-gitleaks-pathScann
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
##
**<center>**CODECOV**  (recovery rating SAST)<br/>![enter image description here](https://www.w6d.io/images/Logo.svg)<center/>**
 ##
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
  name: test-codecov-coverage
  labels:
  {{- include "ci-operator.labels" . | nindent 4 }}
  annotations:
    ci.w6d.io/kind: generic
    ci.w6d.io/task: test-codecov
    ci.w6d.io/order: "0"
params:
  - name: INTERNAL_CODECOV_LINK
    type: string
  - name: CLIENT_CODECOV_TOKEN
    type: string
step:
  name: test-codecov-coverage
  image: "bash"
  script: |
    mkdir -p $(workspaces.source.path)/tests/report-codecov
    cd $(workspaces.source.path)/tests/
    echo y | apk add --no-cache curl
    bash <(curl -s $(params.INTERNAL_CODECOV_LINK)) -t $(params.CLIENT_CODECOV_TOKEN) -f $(workspaces.source.path)/tests/report-codecov/cover.out

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
##
**<center>**Clair**  (Image Scanner DAST)<br/>![enter image description here](https://www.w6d.io/images/Logo.svg)<center/>**
 ##
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
  name: test-clair-klar
  labels:
  {{- include "ci-operator.labels" . | nindent 4 }}
  annotations:
    ci.w6d.io/kind: generic
    ci.w6d.io/task: test-clair
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
  name: test-clair-klar
  image: "golang"
  script: |
    mkdir -p $(workspaces.source.path)/tests/report-clair
    cd $(workspaces.source.path)/tests/
    git clone https://github.com/Portshift/klar.git klar
    cd klar
    go build
    CLAIR_ADDR=(params.INTERNAL_CLAIR_URL) CLAIR_OUTPUT=High CLAIR_THRESHOLD=10 JSON_OUTPUT=true DOCKER_USER=$(params.CLIENT_DOCKER_USER) DOCKER_PASSWORD=$(params.CLIENT_DOCKER_PASSWORD) ./klar $(params.CLIENT_IMAGE_URL) > ../report-clairklar.json
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
##
**<center>**OWASP ZAP** ( Proxy Scan DAST)<center/>**<br/>![enter image description here](https://www.w6d.io/images/Logo.svg)
##
 - **Preface**
OWASP Zed Attack Proxy (ZAP) is a free, open-source penetration testing tool being maintained under the umbrella of the Open Web Application Security Project (OWASP). ZAP is designed specifically for testing web applications and is both flexible and extensible.

 - **Prerequisite:**
    NaN

 - **CI-OPERATOR Configuration.**

   - 1) [OWASP Zap Baseline](https://www.zaproxy.org/docs/docker/baseline-scan/)

```
apiVersion: ci.w6d.io/v1alpha1
kind: Step
metadata:
  name: test-owasp-baseline
  labels:
  {{- include "ci-operator.labels" . | nindent 4 }}
  annotations:
    ci.w6d.io/kind: generic
    ci.w6d.io/task: test-owasp
    ci.w6d.io/order: "0"
params:
  - name: CLIENT_HOST_URL
    type: string
step:
  name: test-owasp-baseline
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
  name: test-owasp-graphql
  labels:
  {{- include "ci-operator.labels" . | nindent 4 }}
  annotations:
    ci.w6d.io/kind: generic
    ci.w6d.io/task: test-owasp
    ci.w6d.io/order: "0"
params:
  - name: CLIENT_HOST_URL
    type: string
step:
  name: test-owasp-graphql
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
  name: test-owasp-fullscan
  labels:
  {{- include "ci-operator.labels" . | nindent 4 }}
  annotations:
    ci.w6d.io/kind: generic
    ci.w6d.io/task: test-owasp
    ci.w6d.io/order: "0"
params:
  - name: CLIENT_HOST_URL
    type: string
step:
  name: test-owasp-fullscan
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
