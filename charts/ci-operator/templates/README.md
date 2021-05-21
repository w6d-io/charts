## **<center>W6D INTEGRATION TESTS DOCUMENTATION<center/>**
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

### gitleaks
##
**<center>**GITLEAKS** (secret discovery SAST)<center/>**
##
 - **Resume**
    Gitleaks is a SAST tool for detecting hardcoded secrets like passwords, api keys, and tokens in git repos. Gitleaks is an **easy-to-use, all-in-one solution** for finding secrets, past or present, in your code.

 - **Prerequis:**
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
 - name: repository_http_link
    type: string
step:
  name: test-gitleaks-pathScann
  image: "zricethezav/gitleaks:latest"
  script: |
    mkdir -p $(workspaces.source.path)/tests/report-gitleaks
    cd $(workspaces.source.path)/tests/
    git clone $(params.repository_http_link) repo-gitleaks
    gitleaks --path="repo-gitleaks/" -v --report=$(workspaces.source.path)/tests/report-gitleaks/report-pathsecretsscan.json

```

 - **Client found variables:**
  ```
 Basic scan on local repo:
repository_http_link= <the project client repository url>
```

### codecov
##
 **<center>**CODECOV**  (recovery rating SAST)<center/>**
 ##
 - **Resume**
Codecov takes coverage to the next level. Unlike open source and paid products, Codecov focuses on integration and promoting healthy pull requests. Codecov delivers  _or "injects"_coverage metrics directly into the modern workflow to promote more code coverage, especially in pull requests where new features and bug fixes commonly occur.

 - **Prerequis:**


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
 - name: codecov_link
    type: string
 - name: CODECOV_TOKEN
    type: string
step:
  name: test-codecov-coverage
  image: "bash"
  script: |
    mkdir -p $(workspaces.source.path)/tests/report-codecov
    cd $(workspaces.source.path)/tests/
    echo y | apk add --no-cache curl
    bash <(curl -s $(params.codecov_link)) -t $(params.CODECOV_TOKEN) -f $(workspaces.source.path)/tests/report-codecov/cover.out

```
**Internal variables:**
```
codecov_link= <https://codecov.io/bash> //link to Codecov
```
**Client found variables:**
  ```
CODECOV_TOKEN= <token generate by Codecov>
```


