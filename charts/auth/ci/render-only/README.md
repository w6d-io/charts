Render-only values: `helm lint` / `helm template` and `hack/check-gateway-base.sh` use them,
`ct install` does not (chart-testing only picks up `ci/*-values.yaml`, not this directory).
They enable gatekit and the site-operator, whose images are not published yet; move a file
back to `ci/` once `ct install` can run it.
