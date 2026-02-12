# GraphQL Mesh BFF

GraphQL Mesh-based Backend for Frontend (BFF) that provides a unified GraphQL API gateway.

## Overview

This service uses [GraphQL Mesh](https://the-guild.dev/graphql/mesh) to create a unified GraphQL API gateway that aggregates multiple microservices:

- **learn-go** (OpenAPI) - Go-based API service (port 8001)
- **learn-python** (OpenAPI) - Python-based API service (port 8000)
- **learn-rust** (OpenAPI) - Rust-based API service (port 8080)

## Architecture

```text
┌─────────────────────────────────────────────────────────────┐
│                    GraphQL Mesh Gateway                     │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  Unified GraphQL Schema (Auto-generated + Custom)    │   │
│  └──────────────────────────────────────────────────────┘   │
│                           │                                 │
│  ┌────────────┬───────────┼───────────┬──────────────────┐  │
│  │  OpenAPI   │  OpenAPI  │  OpenAPI  │                  │  │
│  │  Handler   │  Handler  │  Handler  │                  │  │
│  └─────┬──────┴─────┬─────┴─────┬─────┴──────────────────┘  │
│        │            │           │                           │
└────────┼────────────┼───────────┼───────────────────────────┘
         │            │           │
    ┌────▼────┐  ┌────▼─────┐  ┌─▼─────────┐
    │Learn-Go │  │Learn-Py  │  │Learn-Rust │
    │  :8001  │  │  :8000   │  │   :8080   │
    └─────────┘  └──────────┘  └───────────┘
```

## Key Features

### 1. Automatic Schema Generation

- Mesh auto-generates GraphQL schema from OpenAPI specs
- No manual type definitions needed for base operations
- Type-safe queries & mutations

### 2. Service Prefix Transforms

- **go_ prefix**: All learn-go operations (e.g., `go_healthz`, `go_ping`)
- **python_ prefix**: All learn-python operations (e.g., `python_healthz`, `python_info`)
- **rust_ prefix**: All learn-rust operations (e.g., `rust_healthz`, `rust_version`)

### 3. Redis Caching (Optional)

- Response caching with configurable TTL
- Per-type cache configuration
- Automatic cache invalidation

### 4. Request Header Forwarding

- Automatically forwards `x-user-id` headers to all services
- Service-specific headers for tracking (`x-service`)
- Support for custom operation headers

## Quick Start

### 1. Install Dependencies

```bash
pnpm install
```

### 2. Configure Environment

```bash
cp .env.example .env
# Edit service URLs in .env
```

### 3. Start Development Server

```bash
pnpm dev
```

Server starts at `http://localhost:8080/graphql`

### 4. Access GraphQL Playground

Open browser to `http://localhost:8080/graphql` for interactive playground.

## Example Queries

### Health Check All Services

```graphql
query HealthCheckAll {
  goHealthz: go_healthz {
    success
    data
    timestamp
  }

  pythonHealthz: python_healthz {
    success
    data
    timestamp
  }

  rustHealthz: rust_healthz {
    success
    data
    timestamp
  }
}
```

### Ping All Services

```graphql
query PingAll {
  goPing: go_ping
  pythonPing: python_ping
  rustPing: rust_ping
}
```

### Get Service Information

```graphql
query ServiceInfo {
  goInfo: go_info {
    success
    data
    timestamp
  }

  pythonInfo: python_info {
    success
    data
    timestamp
  }

  rustInfo: rust_info {
    success
    data
    timestamp
  }
}
```

### Echo Endpoint Example

```graphql
mutation EchoMessage {
  goEcho: go_echo(body: {message: "Hello from GraphQL"}) {
    success
    data
    timestamp
  }
}
```

## Project Structure

```text
mesh/
├── .meshrc.yaml              # Main Mesh configuration
├── package.json              # Dependencies
├── tsconfig.json             # TypeScript config
├── .env.example              # Environment template
├── Dockerfile                # Container image definition
├── k8s/
│   └── chart/                # Helm chart for deployment
│       ├── Chart.yaml
│       ├── values.yaml
│       └── templates/
└── .mesh/                    # Generated artifacts (git-ignored)
```

## Development Scripts

```bash
# Start dev server with hot reload
pnpm dev

# Build for production
pnpm build

# Start production server
pnpm start

# Validate configuration
pnpm validate

# Generate TypeScript types
pnpm generate

# Compose supergraph
pnpm supergraph
```

## Configuration

### Service Sources

The `.meshrc.yaml` file defines three backend services:

```yaml
sources:
  - name: LearnGo
    handler:
      openapi:
        source: "http://learn-go:8001/openapi.json"
        endpoint: "http://learn-go:8001"
        operationHeaders:
          x-user-id: "{context.headers.x-user-id}"
          x-service: "learn-go"
    transforms:
      - prefix:
          value: "go_"
          includeRootOperations: true

  - name: LearnPython
    handler:
      openapi:
        source: "http://learn-python:8000/openapi.json"
        endpoint: "http://learn-python:8000"
        operationHeaders:
          x-user-id: "{context.headers.x-user-id}"
          x-service: "learn-python"
    transforms:
      - prefix:
          value: "python_"
          includeRootOperations: true

  - name: LearnRust
    handler:
      openapi:
        source: "http://learn-rust:8080/openapi.json"
        endpoint: "http://learn-rust:8080"
        operationHeaders:
          x-user-id: "{context.headers.x-user-id}"
          x-service: "learn-rust"
    transforms:
      - prefix:
          value: "rust_"
          includeRootOperations: true
```

### Adding New Services

To add a new service, add a source entry in `.meshrc.yaml`:

```yaml
sources:
  - name: NewService
    handler:
      openapi:
        source: http://new-service:9000/openapi.json
        operationHeaders:
          Authorization: "Bearer {context.headers.authorization}"
    transforms:
      - prefix:
          value: "newservice_"
          includeRootOperations: true
```

## Benefits of GraphQL Mesh

| Feature | Direct REST Calls | GraphQL Mesh |
| ------- | ----------------- | ------------ |
| **API Type** | REST | GraphQL |
| **Schema** | Manual OpenAPI parsing | Auto-generated |
| **Type Safety** | Manual types | GraphQL + TypeScript |
| **Data Fetching** | Multiple requests | Single query |
| **Caching** | Manual implementation | Plugin (automatic) |
| **Error Handling** | Per-service format | Unified GraphQL errors |
| **Performance** | N network calls | Optimized batching |
| **Tooling** | Swagger UI | GraphQL Playground |
| **Learning Curve** | Low | Low (declarative) |

## Service Endpoints

Each backend service provides standard REST endpoints that are exposed via GraphQL:

### Common Endpoints (All Services)

- `GET /` - Root endpoint
- `GET /ping` - Health ping
- `GET /healthz` - Detailed health check
- `GET /info` - Service information
- `GET /version` - Service version
- `POST /echo` - Echo test endpoint

### GraphQL Mapping

- REST: `GET /healthz` → GraphQL: `query { go_healthz { ... } }`
- REST: `GET /ping` → GraphQL: `query { go_ping }`
- REST: `POST /echo` → GraphQL: `mutation { go_echo(body: {...}) { ... } }`

## Performance Optimization

### 1. Response Caching (Redis)

Configure caching in `.meshrc.yaml`:

```yaml
cache:
  redis:
    url: ${REDIS_URL:redis://localhost:6379/0}
```

Enable optional per-type TTL:

```yaml
plugins:
  - responseCache:
      ttlPerType:
        Query.go_healthz: 60      # 1 minute
        Query.python_info: 300    # 5 minutes
```

### 2. Request Batching

Mesh automatically batches parallel requests to the same service, reducing network overhead.

### 3. Schema Filtering

Filter unnecessary fields to reduce payload size:

```yaml
transforms:
  - filterSchema:
      mode: wrap
      filters:
        - Type.!{Internal*, _*}
```

## Production Deployment

### Docker

Build and run the container:

```bash
docker build -t mesh:latest .
docker run -p 8080:8080 \
  -e REDIS_URL=redis://redis:6379/0 \
  mesh:latest
```

### Kubernetes/Helm

Deploy using the provided Helm chart:

```bash
helm install mesh k8s/chart \
  --set image.repository=your-registry/mesh \
  --set image.tag=latest \
  --set extraEnv.LEARN_GO_SERVICE_URL=http://learn-go.playground.svc.cluster.local:8001 \
  --set extraEnv.LEARN_PYTHON_SERVICE_URL=http://learn-python.playground.svc.cluster.local:8000 \
  --set extraEnv.LEARN_RUST_SERVICE_URL=http://learn-rust.playground.svc.cluster.local:8080
```

### Environment Variables

Set production service URLs in your deployment:

```bash
# Service endpoints
LEARN_GO_SERVICE_URL=http://learn-go:8001
LEARN_PYTHON_SERVICE_URL=http://learn-python:8000
LEARN_RUST_SERVICE_URL=http://learn-rust:8080

# Redis cache (optional)
REDIS_URL=redis://redis-cluster:6379/0
REDIS_ENABLED=true

# Server config
PORT=8080
ENABLE_PLAYGROUND=false
CORS_ORIGINS=https://your-domain.com
```

## Troubleshooting

### Service Connection Errors

Verify service endpoints are accessible:

```bash
# Test learn-go
curl http://localhost:8001/openapi.json

# Test learn-python
curl http://localhost:8000/openapi.json

# Test learn-rust
curl http://localhost:8080/openapi.json
```

### Schema Generation Errors

Ensure services expose valid OpenAPI specifications:

```bash
pnpm validate
```

### Cache Issues

Temporarily disable Redis caching for debugging:

```bash
REDIS_ENABLED=false pnpm dev
```

### GraphQL Playground Not Loading

Check that playground is enabled:

```bash
ENABLE_PLAYGROUND=true pnpm dev
```

## Resources

- [GraphQL Mesh Documentation](https://the-guild.dev/graphql/mesh/v1)
- [OpenAPI Handler](https://the-guild.dev/graphql/mesh/v1/handlers/openapi)
- [Response Caching Plugin](https://the-guild.dev/graphql/mesh/v1/plugins/response-cache)
- [Transform Documentation](https://the-guild.dev/graphql/mesh/v1/transforms)

## Related Services

- [learn-go](../learn-go) - Go-based microservice (port 8001)
- [learn-python](../learn-python) - Python-based microservice (port 8000)
- [learn-rust](../learn-rust) - Rust-based microservice (port 8080)

## License

MIT
