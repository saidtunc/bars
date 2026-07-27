# Bars – Tech Stack & Library Summary

## 1. High-Level Stack

| Layer | Technology |
|--------|------------|
| **Backend** | Python 3.11, FastAPI (async), SQLite (async via aiosqlite) |
| **Frontend** | React 18, Vite 5, TailwindCSS 3.4 |
| **State** | Zustand (frontend) |
| **Orchestration** | Docker, Docker Compose |
| **Runtime** | Uvicorn (ASGI), Node 18 (frontend dev) |

---

## 2. Backend (`backend/`)

### Core Framework & Server
| Library | Version | Role |
|---------|--------|------|
| **fastapi** | 0.109.0 | REST API, WebSocket, dependency injection, OpenAPI |
| **uvicorn[standard]** | 0.27.0 | ASGI server (includes WebSocket support) |
| **python-multipart** | 0.0.6 | Form/data upload handling |

### Database
| Library | Version | Role |
|---------|--------|------|
| **sqlalchemy** | 2.0.25 | ORM, async sessions, migrations |
| **alembic** | 1.13.1 | Schema migrations |
| **aiosqlite** | 0.19.0 | Async SQLite driver |

### Validation & Config
| Library | Version | Role |
|---------|--------|------|
| **pydantic** | 2.5.3 | Request/response schemas, validation |
| **pydantic-settings** | 2.1.0 | Settings from env/config |

### Async & I/O
| Library | Version | Role |
|---------|--------|------|
| **asyncio** | 3.4.3 | Async event loop (backport; 3.11 has stdlib asyncio) |
| **aiofiles** | 23.2.1 | Async file I/O |
| **aiohttp** | 3.9.1 | Async HTTP client (e.g. sync worker / peer calls) |

### Reports & Templating
| Library | Version | Role |
|---------|--------|------|
| **markdown** | 3.5.2 | Markdown → HTML for reports |
| **weasyprint** | 60.2 | PDF generation from HTML |
| **jinja2** | 3.1.3 | Report templates, flow/task templating |

### Testing
| Library | Version | Role |
|---------|--------|------|
| **pytest** | 7.4.4 | Test runner |
| **pytest-asyncio** | 0.23.3 | Async tests |
| **httpx** | 0.26.0 | Async HTTP client for API tests |

### Utilities
| Library | Version | Role |
|---------|--------|------|
| **python-dateutil** | 2.8.2 | Date parsing/normalization |
| **regex** | 2023.12.25 | Regex (parsing, flow conditions) |

### Backend Runtime & Layout (from code)
- **Python**: 3.11 (from `backend/Dockerfile`).
- **Built-in usage**: `asyncio`, `re`, `json`, `uuid`, `dataclasses`, `pathlib`, `shlex`, `signal`, `traceback`.
- **Key app pieces**: FastAPI CORS, WebSocket endpoint, lifespan (DB init, WebSocket listener, flow manager, sync worker, host runner).

---

## 3. Host Agent (`host_agent/`)

| Library | Version | Role |
|---------|--------|------|
| **fastapi** | (unpinned) | Minimal API for receiving/executing commands |
| **uvicorn** | (unpinned) | Serve the agent |
| **pydantic** | (unpinned) | Request/response models |

Lightweight agent; no DB or heavy deps.

---

## 4. Frontend (`frontend/`)

### Dependencies (Production)
| Library | Version | Role |
|---------|--------|------|
| **react** | ^18.2.0 | UI library |
| **react-dom** | ^18.2.0 | React DOM renderer |
| **react-router-dom** | ^6.21.0 | Client-side routing |
| **zustand** | ^4.4.7 | Global state |
| **axios** | ^1.6.2 | HTTP client to backend API |
| **lucide-react** | ^0.303.0 | Icons |
| **reactflow** | ^11.10.1 | Flow editor (nodes/edges) |
| **react-hot-toast** | ^2.4.1 | Toast notifications |

### Dev Dependencies
| Library | Version | Role |
|---------|--------|------|
| **@types/react** | ^18.2.43 | React TypeScript types |
| **@types/react-dom** | ^18.2.17 | React DOM types |
| **@vitejs/plugin-react** | ^4.2.1 | Vite React support (JSX, HMR) |
| **autoprefixer** | ^10.4.16 | CSS vendor prefixes |
| **postcss** | ^8.4.32 | PostCSS pipeline (Tailwind) |
| **tailwindcss** | ^3.4.0 | Utility-first CSS |
| **vite** | ^5.0.10 | Build tool, dev server, HMR |

### Frontend Tooling (from config)
- **Vite**: React plugin; dev server on port 3000; proxy `/api` and `/ws` to backend; manual chunks: `vendor` (react, react-dom, react-router-dom), `flow` (reactflow), `ui` (lucide-react).
- **Tailwind**: v3.4; `content` on `index.html` and `src/**/*.{js,ts,jsx,tsx}`; `darkMode: 'class'`; custom `dark` and `accent` palettes; fonts Inter / JetBrains Mono, Fira Code.
- **PostCSS**: used for Tailwind (via `postcss.config.js`).

---

## 5. Infrastructure

### Containers
- **Backend**: `python:3.11-slim`; `gcc`, `libffi-dev` for native deps (e.g. WeasyPrint); port 8000; uvicorn.
- **Frontend**: `node:18-alpine`; port 3000; `npm run dev -- --host`.

### Compose
- **docker-compose.yml**: `backend` + `frontend`; volumes for app code, `storage`, `reports`; `.env`; backend reload; `host.docker.internal` for host access.
- **docker-compose.dev.yml**: Same stack with `WATCHFILES_FORCE_POLLING` and `WATCH_USE_POLLING` for file watching in dev.
- **docker-compose.sync.yml**: Two backend + two frontend instances for multi-operator sync (separate DBs and storage volumes per node).

### Env / Config
- Backend: `HOST_STORAGE_PATH`, `DATABASE_URL` (SQLite+aiosqlite), optional `SYNC_*`, `NODE_ID`, etc.
- Frontend: `VITE_API_URL`, `VITE_AUTH_REQUIRED`; proxy used when running in Docker.

---

## 6. Summary Table

| Category | Backend | Host Agent | Frontend |
|----------|---------|------------|----------|
| **Runtime** | Python 3.11, Uvicorn | Python, Uvicorn | Node 18, Vite dev server |
| **Framework** | FastAPI | FastAPI | React 18 |
| **DB** | SQLAlchemy 2 + aiosqlite | — | — |
| **Validation** | Pydantic v2 | Pydantic | — |
| **Async HTTP** | aiohttp | — | axios |
| **State** | — | — | Zustand |
| **UI / UX** | — | — | Tailwind, Lucide, React Flow, React Hot Toast |
| **Build** | — | — | Vite 5, PostCSS, Autoprefixer |
| **Reports** | Markdown, WeasyPrint, Jinja2 | — | — |
| **Testing** | pytest, pytest-asyncio, httpx | — | — |

---

*Generated from project analysis. Aligns with architecture in `.cursor/rules`: async FastAPI backend, React + Vite + Tailwind frontend, SQLite (async), WebSockets, React Flow for workflows, and Docker-based deployment.*
