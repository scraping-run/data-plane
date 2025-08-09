# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

laf is an open-source cloud development platform (BaaS/FaaS) that provides serverless cloud functions, cloud databases, cloud storage, and web hosting capabilities. It's a self-hosted alternative to Firebase or Supabase, allowing developers to build full-stack applications without managing infrastructure.

## Architecture

This is a monorepo managed by Lerna with these core components:

- **`/server/`** - NestJS backend API server (system-server)
- **`/web/`** - React/Vite frontend web application (admin dashboard & IDE)
- **`/cli/`** - Command-line interface tool
- **`/runtimes/nodejs/`** - Node.js runtime for executing cloud functions
- **`/packages/`** - Shared libraries:
  - `client-sdk/` - JavaScript SDK for frontend applications
  - `cloud-sdk/` - Cloud SDK for runtime environment
  - `database-proxy/` - Database access layer with policy enforcement
  - `database-ql/` - Database query language implementation
  - `node-modules-utils/` - Dependency management utilities

## Common Commands

### Root-level commands (run from project root):
```bash
# Install dependencies across all packages
npm run install

# Build all packages
npm run build

# Watch mode for development
npm run watch

# Lint all packages
npm run lint

# Clean build artifacts
npm run clean:build

# Count TypeScript lines
npm run stats
```

### Server development (in `/server/`):
```bash
# Development server with hot reload
npm run dev

# Build production
npm run build

# Run tests
npm run test

# Lint
npm run lint
```

### Web development (in `/web/`):
```bash
# Development server
npm run dev

# Build for production
npm run build

# Preview production build
npm run preview

# Lint
npm run lint

# Type check
npm run tsc
```

### Running individual tests:
- Server uses Jest: `cd server && npm run test -- path/to/test.spec.ts`
- Use `npm run test:watch` for watch mode

## Development Workflow

1. **Monorepo Structure**: This project uses Lerna. When making changes that affect multiple packages, ensure you build dependencies first.

2. **Type Safety**: The project uses TypeScript throughout. Always run type checking before committing:
   - Web: `cd web && npm run tsc`
   - Server: TypeScript is checked during build

3. **Code Style**: ESLint is configured. Always run `npm run lint` before committing changes.

4. **Database**: The platform uses MongoDB. The database proxy in `/packages/database-proxy/` enforces access policies.

5. **Runtime Environment**: Cloud functions run in a sandboxed Node.js environment (`/runtimes/nodejs/`). The runtime has access to:
   - `@scraping-run/cloud-sdk` for cloud services
   - User-installed npm packages via the dependency management system

6. **API Structure**: The server follows NestJS patterns with modules, controllers, and services. Key modules include:
   - Authentication & authorization
   - Application management
   - Function management
   - Database management
   - Storage management

7. **Frontend Architecture**: The web app uses:
   - React 18 with TypeScript
   - Chakra UI for components
   - React Query for state management
   - Monaco Editor for code editing
   - i18next for internationalization

## Key Technical Details

- **Kubernetes Integration**: The platform is designed to run on Kubernetes and manages application resources through K8s APIs
- **Multi-tenancy**: Applications are isolated using Kubernetes namespaces
- **Storage**: Uses MinIO for object storage with S3-compatible APIs
- **WebSocket Support**: Real-time features through WebSocket connections
- **Monitoring**: Prometheus metrics exported via `/services/runtime-exporter/`

## Testing Strategy

- Unit tests use Jest framework
- E2E tests are in `/e2e/` directory
- Run tests before committing code
- Mock external dependencies appropriately

## Deployment

The project uses Docker for containerization. Each component has its own Dockerfile. GitHub Actions handle CI/CD with workflows for:
- Building and pushing Docker images
- Running tests
- Deploying documentation
- Creating releases

When developing, be aware that changes might need corresponding updates to:
- Docker configurations
- Kubernetes manifests in `/deploy/`
- GitHub Actions workflows in `/.github/workflows/`