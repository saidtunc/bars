---
trigger: always_on
---

# SYSTEM: Bars Architecture & Rules
> **CRITICAL:** You are the Lead Developer for this Bars. You must strictly adhere to the architecture and patterns defined below. Do not deviate without user permission. 

** Do not add verification step to Implementation Plans. User want to verify manually.

# Project Context: Bars

## High-Level Purpose
A full-stack penetration testing orchestration framework designed to manage engagements, automate tool execution (e.g., Nmap), and aggregate results. It features real-time WebSocket updates, a visual flow editor for automation workflows, and report generation capabilities.

## Tech Stack
*   **Backend**: Python 3.11+, FastAPI (Async), SQLAlchemy (Asyncio), Pydantic v2, Uvicorn, Aiohttp.
*   **Frontend**: React 18, Vite, TailwindCSS (v3.4), Zustand (State Management), React Flow (Visual graphs).
*   **Database**: SQLite (Async/Aiosqlite) with WAL mode enabled.
*   **Infrastructure**: Docker, Docker Compose based orchestration.

## Project Structure
```text
PentestFramework/
├── backend/app/
│   ├── api/          # REST API Route handlers (Projects, Executions)
│   ├── core/         # Core business logic specialized services
│   │   ├── orchestrator.py  # Task coordination
│   │   ├── flow_manager.py  # Workflow engine
│   │   └── parser.py        # Output parsing logic
│   ├── models/       # SQLAlchemy ORM database models
│   ├── schemas/      # Pydantic data transfer objects (DTOs)
│   └── websocket/    # WebSocket connection handling
├── frontend/src/
│   ├── components/   # Reusable UI atoms (Buttons, Layouts)
│   ├── pages/        # Route-specific page views (Dashboard, Flows)
│   ├── services/     # API client functions (Axios wrappers)
│   └── stores/       # Global state management via Zustand
├── host_agent/       # Standalone Python agent for command execution
└── reports/          # Generated scan reports storage location
```

## Key Patterns
*   **Async Repository Pattern**: Database access is managed via `AsyncSession` with explicit transaction handling and `selectinload` for efficient relationship loading.
*   **Service-Layer Architecture**: Core business logic (e.g., `orchestrator.py`, `flow_manager.py`) is strictly decoupled from the API route handlers.
*   **Agent-Based Execution**: Tool execution is delegated to a standalone `host_agent` process that streams stdout/stderr back to the core via websockets/API calls, allowing for distributed or local execution.
*   **Event-Driven UI**: The frontend uses WebSocket connections (`notifications.py`) to receive real-time task progress updates, avoiding polling mechanisms.
*   **Declarative Flows**: Automation workflows are defined as JSON structures (stored in DB) and processed by a central flow engine, allowing dynamic execution paths.

## Advanced Technical Implementation

### Dynamic Variable Chaining
The framework supports complex variable injection where outputs from previous tasks can be reused in subsequent ones:
* **Global Injection**: Parsed outputs are automatically injected into `ProjectVariable` based on `storage_policy` or implicit discovery.
* **Namespaced Access**: In flows, use `{item_id.key}` or `{checklist_item_name.key}` to access specific task outputs.
* **Template Engine**: Jinja2-style rendering handles variable substitution in command templates.

### Parameter Schemas & Temporary Files
Tasks can define a `parameter_schema` to control argument processing:
* **File-Based Arguments**: Setting `var_type: "file"` for a parameter triggers the orchestrator to write the input value (e.g., a list of IPs) to a temporary file in `storage/tmp/` and pass the *path* to the command.
* **Automated Cleanup**: The `Orchestrator` automatically deletes these temporary files after execution to maintain disk hygiene.

### Batch Execution (Iterative Mode)
If a task receives multiple targets in the `targets` variable, it enters **Batch Mode**:
* **Parent-Child Logic**: A "Parent" execution record tracks the overall progress, while individual "Child" executions are spawned for each target.
* **Host Auto-Creation**: Missing hosts are automatically registered in the project when targeted in a batch execution.

### Infrastructure & Asset Discovery
* **ShareParser**: Specialized parser for tool outputs (SMBMap, NetExec, etc.) that populates the `DiscoveredFile` (Shares) table.
* **Asset Tracking**: New hosts, services, and findings are dynamically updated in the UI via the `notifications.py` service.

### Flow Engine Logic
The `FlowManager` orchestrates multi-step pipelines with features like:
* **Input Mapping**: Map previous outputs to current inputs using regex parsers.
* **Conditional Execution**: Evaluate Python-like `condition` strings (e.g., `"{1.port_80}" == "open"`) to skip or run steps.
* **Failure Policies**: Configure `on_failure` as `stop`, `skip_remaining`, or `continue`.

## Data Model Context
* **Project** -> has many **Executions** -> has many **Findings**.
* **Workflow** defines the logic for an **Execution**.