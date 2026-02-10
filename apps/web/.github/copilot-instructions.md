# GitHub Copilot Instructions for AIID Doc Generator

This project is a Vue 3 + TypeScript application for generating construction drawing design descriptions using AI.

## 🏗 Architecture & Core Concepts

- **Framework**: Vue 3 (Composition API) + TypeScript + Vite.
- **UI Libraries**: Element Plus (primary) & Ant Design Vue. Check existing usage before introducing new components.
- **State Management**: Vue Composition API (refs/reactive) and Composables (`src/composables/`).
- **Routing**: Vue Router 4 with authentication guards (`src/router/index.ts`).
- **API Layer**:
  - Located in `src/service/`.
  - Uses native `fetch` with a custom wrapper/pattern (not a global Axios instance).
  - Base URL is `/aidoc/api/v1` (proxied in dev).
  - Responses follow `ApiResponse<T>` interface `{ code: number, message: string, data: T }`.
- **Authentication**:
  - Token-based (Bearer).
  - Managed via `src/utils/auth.ts` (`authStorage`).
  - Tokens stored in `localStorage`.

## 💻 Development Workflows

- **Start Dev Server**: `npm run dev` (Proxies `/aidoc/api` to `https://cm.aizzyun.com`).
- **Build**: `npm run build` (Includes `vue-tsc` type checking).
- **Type Checking**: Run `vue-tsc -b` to verify types.

## 🧩 Key Patterns & Conventions

### API Service Pattern
Do not make HTTP calls directly in components. Define typed service functions in `src/service/`.
```typescript
// src/service/example.ts
export async function getData(id: string): Promise<ApiResponse<Data>> {
  const url = `${API_BASE_URL}/resource/${id}`;
  // ... error handling and fetch logic ...
}
```

### Authentication
Always use `authStorage` to access tokens or user info.
```typescript
import { authStorage } from '@/utils/auth';
const token = authStorage.getToken();
if (!authStorage.isAuthenticated()) { /* ... */ }
```

### Component Structure
- Use `<script setup lang="ts">`.
- Import components explicitly or rely on `unplugin-vue-components` (configured in `vite.config.ts`).
- Use CSS variables from `src/style.css` for theming (e.g., `var(--primary-color)`).

### Document & Block Model
- Documents are hierarchical collections of "Blocks".
- See `src/service/document.ts` for `BlockData` and `DocumentData` interfaces.
- Block types include `heading_1`, `paragraph`, `table`, etc.

## ⚠️ Gotchas & Specifics

- **Proxy**: API requests must start with `/aidoc/api` to be correctly proxied in development.
- **Mixed UI Libs**: The project has both Element Plus and Ant Design Vue. Prefer Element Plus for general UI, but check context.
- **Markdown**: Uses `marked` for rendering.
- **Environment**: `VITE_PROXY_TARGET` in `package.json` scripts controls the backend target.
