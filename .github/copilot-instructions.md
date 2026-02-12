# AI Coding Agent Instructions for mesh

## Project Overview
GraphQL Mesh-based API gateway that declaratively aggregates learn-go (port 8001), learn-python (port 8000), and learn-rust (port 8080) microservices into a unified GraphQL API. **Configuration-driven architecture** - no custom TypeScript code, ONLY `.meshrc.yaml` configuration file defines all behavior.

## Architecture & Core Concepts

### Declarative Configuration Pattern (CRITICAL)
- **`.meshrc.yaml`** is the ONLY source of truth for gateway behavior - all service integration, transforms, caching, and routing defined here
- Sources use OpenAPI handlers to auto-generate GraphQL schema from backend REST APIs
- Three-service architecture with prefix transforms to avoid naming conflicts:
  - `LearnGo` → `go_` prefix (e.g., `go_healthz`, `go_ping`)
  - `LearnPython` → `python_` prefix (e.g., `python_healthz`, `python_info`)
  - `LearnRust` → `rust_` prefix (e.g., `rust_healthz`, `rust_version`)

### Service Integration Requirements
1. Backend services MUST expose OpenAPI spec at `/openapi.json` endpoint
2. Services receive forwarded headers: `x-user-id` (auth) and `x-service` (tracking)
3. Service URLs configured via environment variables (see `.env.example`)

### Build & Runtime Architecture
- **Docker multi-stage**: Node.js 24-alpine → pnpm install → runtime with `pnpm mesh build && pnpm mesh start`
- **Critical Docker detail**: `.mesh/` directory mounted as emptyDir in K8s to avoid permission conflicts (see Dockerfile comment line 36)
- **Generated artifacts**: GraphQL Mesh generates schema and runtime code into `.mesh/` (git-ignored)
- **Package manager**: pnpm (v10.28.0) via corepack - ALWAYS use pnpm (both local dev and CI)

## Critical Developer Workflows

### Local Development
```bash
pnpm install              # Install dependencies (uses frozen lockfile)
pnpm dev                  # Start dev server with hot reload on :8080
pnpm build                # Build and validate .meshrc.yaml configuration
```

**Testing backend connectivity:**
```bash
# Verify OpenAPI specs are accessible
curl http://localhost:8001/openapi.json  # learn-go
curl http://localhost:8000/openapi.json  # learn-python
curl http://localhost:8080/openapi.json  # learn-rust
```

### Adding New Backend Services
1. Update `.meshrc.yaml` sources array with new OpenAPI handler
2. Add prefix transform to avoid naming conflicts (e.g., `newservice_`)
3. Configure `operationHeaders` to forward authentication
4. Update `k8s/chart/values.yaml` extraEnv with service URL
5. Run `pnpm build` to validate configuration
6. Update `.env.example` with new SERVICE_URL variable

### CI/CD Pipeline Structure
1. **lint** → Builds mesh to validate `.meshrc.yaml` configuration
2. **test** → Matrix (Node 20/22/24) builds mesh gateway with `pnpm build`
3. **security-scan** → pnpm audit for dependency vulnerabilities
4. **helm-test** → helm-unittest + helm lint on `k8s/chart/`
5. **build** → Multi-arch Docker image (amd64/arm64) pushed to ghcr.io

## Project-Specific Conventions

### Configuration Patterns in .meshrc.yaml
```yaml
sources:
  - name: ServiceName
    handler:
      openapi:
        source: "http://service:port/openapi.json"
        endpoint: "http://service:port"
        operationHeaders:
          x-user-id: "{context.headers.x-user-id}"  # CRITICAL: Auth forwarding
          x-service: "service-name"
    transforms:
      - prefix:
          value: "prefix_"
          includeRootOperations: true  # REQUIRED for root queries
```

### Helm Chart Patterns
- Chart uses `base.` helper templates from `templates/_helpers.tpl` - use these for consistent labeling
- Key toggle: `autoscaling.enabled` - when true, replicas field is omitted from Deployment
- Label pattern: `app.kubernetes.io/part-of: "mesh"` via `chart_label` value
- Health probes: GraphQL query `{health{status}}` at `/graphql?query=%7Bhealth%7Bstatus%7D%7D`
- Volume mounts: `app-cache` emptyDir at `/tmp/mesh/cache` for build artifacts

### Environment Variable Priority
1. Kubernetes ConfigMap (`extraEnv` in values.yaml) - production service URLs
2. `.env` file - local development overrides
3. `.meshrc.yaml` defaults - `${VAR:default}` syntax for Redis URL

## Common Pitfalls & Gotchas

1. **Service URLs mismatch**: `.meshrc.yaml` uses Kubernetes service names (`learn-go:8001`), but `.env.example` uses localhost. Update `.meshrc.yaml` sources when testing locally OR use port-forwarding.
2. **OpenAPI spec changes**: Mesh caches schema - restart dev server after backend API changes
3. **Permission errors**: If `.mesh/` exists before Docker build, K8s emptyDir mount fails - Dockerfile intentionally omits creating this directory
4. **Prefix collisions**: If adding new service, ensure prefix doesn't conflict (current: go_, python_, rust_)
5. **pnpm lockfile**: Both CI workflows and local dev use pnpm with frozen lockfile - never commit package-lock.json
6. **Missing transform package**: The `prefix` transform requires `@graphql-mesh/transform-prefix` dependency - ensure it's in package.json

## Quick Reference: Key Files

**Must-understand for modifications:**
- `.meshrc.yaml` - ALL gateway configuration (sources, caching, CORS, transforms)
- `package.json` - Dependencies and scripts (note: `pnpm mesh` commands, not custom code)
- `Dockerfile` - Multi-stage build with emptyDir workaround comment
- `k8s/chart/values.yaml` - Service URLs (`extraEnv` section lines 64-75)
- `k8s/chart/templates/_helpers.tpl` - Label/name generation patterns
- `.env.example` - Local development service URL configuration

**Testing patterns:**
- `k8s/chart/tests/*.yaml` - helm-unittest suites using `set:` and `asserts:` patterns
- No unit/integration tests - this is a configuration-only gateway (no custom resolvers)
- Config validation via `pnpm build` (validates `.meshrc.yaml` syntax and generates artifacts)
- Note: `pnpm validate` requires built artifacts - use `pnpm build` for validation

## GraphQL Playground Usage

Access at `http://localhost:8080/graphql` - queries use prefixed operations:

```graphql
query HealthCheckAll {
  go_healthz { success data timestamp }
  python_healthz { success data timestamp }
  rust_healthz { success data timestamp }
}
```

## Related Services & Dependencies

- **Upstream services**: [learn-go](../learn-go), [learn-python](../learn-python), [learn-rust](../learn-rust)
- **Required ports**: 8001 (Go), 8000 (Python), 8080 (Rust), 8080 (Mesh gateway)
- **Optional**: Redis on 6379 for response caching (disabled by default)
