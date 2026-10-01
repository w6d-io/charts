const http = require("http");
const KRATOS_ADMIN = process.env.KRATOS_ADMIN_URL;
const HYDRA_ADMIN = process.env.HYDRA_ADMIN_URL;
// Empty: /resolve-org assigns no organization (no tenant service in this environment).
const TENANT_URL = process.env.TENANT_URL || "";
// Admin API tokens (chart kratos/hydra.adminAuth): sent only when set.
function adminHeaders(token) {
    return token ? {Authorization: `Bearer ${token}`} : {};
}
const KRATOS_HEADERS = adminHeaders(process.env.KRATOS_ADMIN_TOKEN);
const HYDRA_HEADERS = adminHeaders(process.env.HYDRA_ADMIN_TOKEN);
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
function getJson(url) {
    return new Promise((resolve, reject) => {
        http.get(url, (res) => {
            let data = "";
            res.on("data", (chunk) => (data += chunk));
            res.on("end", () => {
                if (res.statusCode === 200) {
                    try { resolve(JSON.parse(data)); } catch (e) { reject(e); }
                } else if (res.statusCode === 404) {
                    resolve(null);
                } else {
                    reject(new Error(`GET ${url} returned ${res.statusCode}`));
                }
            });
        }).on("error", reject);
    });
}
function orgFromFlowUrl(flowUrl) {
    if (!flowUrl) return null;
    try {
        return new URL(flowUrl).searchParams.get("organization_id");
    } catch {
        return null;
    }
}
// The UUID check is mandatory, not defensive tidiness: tenant-service returns
// 500 (not 400) for a path segment that does not parse as a UUID, so a bad
// link would otherwise surface as a resolver error.
async function resolveOrg(candidate) {
    if (!TENANT_URL || !UUID_RE.test(candidate || "")) return null;
    const tenant = await getJson(`${TENANT_URL}/tenants/${candidate}`);
    if (!tenant || tenant.status !== "active") return null;
    return tenant.tenant_id;
}
// Narrows what an in-cluster caller can do: an organization may only be
// set on an identity that was just created and has none yet. Re-assigning
// an established user is refused.
const ASSIGN_WINDOW_MS = 5 * 60 * 1000;
async function assignIsAllowed(identity) {
    if (!identity) return {ok: false, reason: "identity_not_found"};
    if (identity.organization_id) return {ok: false, reason: "already_assigned"};
    const age = Date.now() - Date.parse(identity.created_at);
    if (!(age >= 0 && age < ASSIGN_WINDOW_MS)) {
        return {ok: false, reason: "identity_too_old"};
    }
    return {ok: true};
}
function patchOrganization(identityId, orgId) {
    return new Promise((resolve, reject) => {
        const body = JSON.stringify([
            {op: "add", path: "/organization_id", value: orgId},
        ]);
        const req = http.request(
            `${KRATOS_ADMIN}/admin/identities/${encodeURIComponent(identityId)}`,
            {
                method: "PATCH",
                headers: {
                    ...KRATOS_HEADERS,
                    "Content-Type": "application/json",
                    "Content-Length": Buffer.byteLength(body),
                },
            },
            (res) => {
                let data = "";
                res.on("data", (chunk) => (data += chunk));
                res.on("end", () => {
                    if (res.statusCode === 200) {
                        resolve();
                    } else {
                        reject(new Error(`Kratos PATCH returned ${res.statusCode}: ${data.slice(0, 200)}`));
                    }
                });
            },
        );
        req.on("error", reject);
        req.end(body);
    });
}
function fetchIdentity(subject) {
    return new Promise((resolve, reject) => {
        http.get(`${KRATOS_ADMIN}/admin/identities/${encodeURIComponent(subject)}`, {headers: KRATOS_HEADERS}, (res) => {
            let data = "";
            res.on("data", (chunk) => (data += chunk));
            res.on("end", () => {
                if (res.statusCode === 200) {
                    resolve(JSON.parse(data));
                } else if (res.statusCode === 404) {
                    resolve(null);
                } else {
                    reject(new Error(`Kratos returned ${res.statusCode}`));
                }
            });
        }).on("error", reject);
    });
}
function fetchHydraClient(clientId) {
    return new Promise((resolve, reject) => {
        if (!HYDRA_ADMIN) {
            resolve(null);
            return;
        }
        http.get(`${HYDRA_ADMIN}/admin/clients/${encodeURIComponent(clientId)}`, {headers: HYDRA_HEADERS}, (res) => {
            let data = "";
            res.on("data", (chunk) => (data += chunk));
            res.on("end", () => {
                if (res.statusCode === 200) {
                    resolve(JSON.parse(data));
                } else if (res.statusCode === 404) {
                    resolve(null);
                } else {
                    reject(new Error(`Hydra returned ${res.statusCode}`));
                }
            });
        }).on("error", reject);
    });
}
const server = http.createServer(async (req, res) => {
    const pathname = req.url.split("?")[0];
    if (pathname === "/health") {
        res.writeHead(200);
        res.end("ok");
        return;
    }
    if (pathname === "/hydrate" && req.method === "POST") {
        let body = "";
        req.on("data", (chunk) => (body += chunk));
        req.on("end", async () => {
            try {
                const payload = JSON.parse(body);
                const subject = payload.subject;
                const extra = payload.extra || {};
                const identity = await fetchIdentity(subject);
                if (identity) {
                    if (extra.identity) {
                        extra.identity.metadata_admin = identity.metadata_admin || {};
                    } else {
                        extra.identity = identity;
                    }
                } else {
                    // No Kratos identity: treat subject as a Hydra OAuth2 client (M2M)
                    // and expose its metadata.organization_id under extra.identity so
                    // the Oathkeeper header mutator can inject X-Id. Stub the
                    // sub-objects the mutator templates index into (traits, metadata_admin)
                    // so they don't fail with `index of untyped nil`.
                    const client = await fetchHydraClient(subject);
                    const orgId = client && client.metadata && client.metadata.organization_id;
                    if (orgId) {
                        extra.identity = {
                            organization_id: orgId,
                            traits: {},
                            metadata_admin: {},
                        };
                    }
                }
                res.writeHead(200, {"Content-Type": "application/json"});
                res.end(JSON.stringify({subject, extra}));
            } catch (err) {
                console.error("hydrate error:", err.message);
                res.writeHead(502);
                res.end(JSON.stringify({error: err.message}));
            }
        });
        return;
    }
    if (pathname === "/resolve-org" && req.method === "POST") {
        // Post-persist registration hook from Kratos. The identity already
        // exists, so only genuine failures return 5xx - "no organization"
        // is a 200 with a null, and leaves the user unassigned.
        //
        // There is deliberately no shared-secret check. Kratos renders
        // webhook auth into its config FILE, and banzaicloud vault-env
        // only substitutes environment VARIABLES, so Kratos transmits the
        // literal string "vault:infra/data/auth#KRATOS_WEBHOOK_SECRET"
        // and no comparison can ever succeed. A NetworkPolicy would not
        // help either: this cluster runs the EKS node agent with
        // --enable-network-policy=false, so policies are not enforced.
        //
        // What guards this endpoint instead: it has no Ingress or
        // HTTPRoute, so it is cluster-internal only, and assignIsAllowed()
        // below restricts writes to identities that are brand new and
        // still unassigned.
        let body = "";
        req.on("data", (chunk) => (body += chunk));
        req.on("end", async () => {
            try {
                const payload = JSON.parse(body);
                const identityId = payload.identity_id;
                if (!UUID_RE.test(identityId || "")) {
                    res.writeHead(400, {"Content-Type": "application/json"});
                    res.end(JSON.stringify({error: "bad identity_id"}));
                    return;
                }
                // The flow-init query string is persisted by Kratos in
                // flow.request_url, so it survives both steps of the code
                // flow. transient_payload is the optional second carrier.
                const candidate =
                    orgFromFlowUrl(payload.flow_request_url) || payload.organization_id;
                const allowed = await assignIsAllowed(await fetchIdentity(identityId));
                const orgId = allowed.ok ? await resolveOrg(candidate) : null;
                if (orgId) {
                    await patchOrganization(identityId, orgId);
                }
                console.log(JSON.stringify({
                    msg: "resolve-org",
                    identity_id: identityId,
                    candidate: candidate || null,
                    organization_id: orgId || null,
                    refused: allowed.ok ? null : allowed.reason,
                }));
                res.writeHead(200, {"Content-Type": "application/json"});
                res.end(JSON.stringify({organization_id: orgId || null}));
            } catch (err) {
                console.error("resolve-org error:", err.message);
                res.writeHead(502, {"Content-Type": "application/json"});
                res.end(JSON.stringify({error: err.message}));
            }
        });
        return;
    }

    res.writeHead(404);
    res.end("not found");
});
server.listen(8080, () => console.log("hydrator-proxy listening on :8080"));
