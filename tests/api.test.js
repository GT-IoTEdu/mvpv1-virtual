// Testes de integração HTTP contra o deploy ao vivo.
// Rodam via Jest em Node 20+ (fetch nativo). Testam apenas
// CONTRATOS estáveis (status code, host de destino do redirect)
// — nada de parsear payload internal, pra evitar manutenção
// constante quando o backend mudar.
//
//   BASE_URL=https://iotedu.anonshield.org npm test
//   BASE_URL=https://mvp.iotedu.org        npm test

const BASE = (process.env.BASE_URL || "https://iotedu.anonshield.org").replace(/\/$/, "");

async function get(path, opts = {}) {
    return fetch(`${BASE}${path}`, { redirect: "manual", ...opts });
}

describe(`iotedu API @ ${BASE}`, () => {

    test("frontend root → 200", async () => {
        const r = await get("/");
        expect(r.status).toBe(200);
    });

    test("backend health → 200 + db:ok (regressão DB pega aqui)", async () => {
        const r = await get("/health");
        expect(r.status).toBe(200);
        const body = await r.json();
        expect(body.status).toBe("healthy");
        expect(body.db).toBe("ok");
    });

    test("api docs → 200 (swagger)", async () => {
        const r = await get("/docs");
        expect(r.status).toBe(200);
    });

    test("openapi schema → 200 + JSON com 'paths'", async () => {
        const r = await get("/openapi.json");
        expect(r.status).toBe(200);
        const body = await r.json();
        expect(body.paths).toBeDefined();
    });

    test("providers list → 200 + array com iotedu e anonshield", async () => {
        const r = await get("/api/auth/providers");
        expect(r.status).toBe(200);
        const body = await r.json();
        const names = body.providers.map(p => p.name).sort();
        expect(names).toEqual(expect.arrayContaining(["iotedu", "anonshield"]));
    });

    test("/api/auth/iotedu/login → 302 → idp.iotedu.org", async () => {
        const r = await get("/api/auth/iotedu/login");
        expect(r.status).toBe(302);
        expect(r.headers.get("location")).toMatch(/^https:\/\/idp\.iotedu\.org\//);
    });

    test("/api/auth/anonshield/login → 302 → idp.anonshield.org", async () => {
        const r = await get("/api/auth/anonshield/login");
        expect(r.status).toBe(302);
        expect(r.headers.get("location")).toMatch(/^https:\/\/idp\.anonshield\.org\//);
    });

    test("/api/auth/google/login → 307 → accounts.google.com", async () => {
        const r = await get("/api/auth/google/login");
        expect(r.status).toBe(307);
        expect(r.headers.get("location")).toMatch(/^https:\/\/accounts\.google\.com\//);
    });

    test("/api/auth/me sem cookie → 401", async () => {
        const r = await get("/api/auth/me");
        expect(r.status).toBe(401);
    });

    test("/api/auth/iotedu/me sem cookie → 401", async () => {
        const r = await get("/api/auth/iotedu/me");
        expect(r.status).toBe(401);
    });

    test("/api/auth/foo (provider inválido) → 404", async () => {
        const r = await get("/api/auth/foo/login");
        expect(r.status).toBe(404);
    });

    test("login redirects carregam state, code_challenge e nonce (PKCE)", async () => {
        const r = await get("/api/auth/iotedu/login");
        const loc = r.headers.get("location") || "";
        expect(loc).toMatch(/[?&]state=/);
        expect(loc).toMatch(/[?&]nonce=/);
        expect(loc).toMatch(/[?&]code_challenge=/);
        expect(loc).toMatch(/[?&]code_challenge_method=S256/);
    });
});

describe("dependências externas (IdPs)", () => {

    test("idp.iotedu.org discovery → 200 + issuer correto", async () => {
        const r = await fetch("https://idp.iotedu.org/realms/iotedu/.well-known/openid-configuration");
        expect(r.status).toBe(200);
        const body = await r.json();
        expect(body.issuer).toBe("https://idp.iotedu.org/realms/iotedu");
    });

    test("idp.anonshield.org discovery → 200 + issuer correto", async () => {
        const r = await fetch("https://idp.anonshield.org/realms/anonshield/.well-known/openid-configuration");
        expect(r.status).toBe(200);
        const body = await r.json();
        expect(body.issuer).toBe("https://idp.anonshield.org/realms/anonshield");
    });
});
