# Bars - Detailed Feature & Function Context

This document provides a deep dive into the specific features, functions, and components of the Bars, based on a comprehensive codebase analysis.

## 1. Backend Core Services & Features

The backend is built with FastAPI and heavily utilizes asynchronous patterns (`asyncio`, `Aiohttp`, `Aiosqlite`). Business logic is cleanly separated into the `app/core` layer.

### 1.1 Task Orchestrator (`orchestrator.py`)
The orchestrator is the heart of command execution and handles multiple complex scenarios:
*   **Asynchronous Execution**: Uses background tasks to manage command lifecycles without blocking API routes.
*   **Batch Execution (Iterative Mode)**: If a command is provided with a list of targets natively not supported by the tool, the orchestrator spawns a "Parent" execution and multiple "Child" executions for each target, running up to `BATCH_CONCURRENCY` tasks in parallel.
*   **Temporary File Management**: If a command template requires a file input (defined by `parameter_schema` with `var_type: "file"`), the orchestrator automatically writes the variable contents to a temporary file in `storage/tmp/`, passes the filepath to the agent, and securely deletes the file post-execution.
*   **Automatic Asset Discovery**: Scans execution outputs for IPs iteratively updating the `Host` database table. Also integrates with specialized parsers.
*   **Variable Injection**: Extracts parsed outputs based on predefined Regex schemas and injects them into `ProjectVariable` for use in subsequent tasks.

### 1.2 Flow Manager (`flow_manager.py`)
Orchestrates multi-step pipelines triggered by user actions or automated workflows:
*   **Event-Driven Pipeline**: Listens to execution completion events to trigger downstream actions.
*   **Topological Execution**: Evaluates the graph structure to support parallel execution of tasks that share the same depth or lack dependencies.
*   **Variable Chaining & Mapping**: Maps regex-parsed outputs of a source step to the inputs/variables of a target step (e.g., passing `{source_step.open_ports}` into standard `{targets}`).
*   **Conditional Execution**: Evaluates Python-like condition strings (e.g., `"{1.port_80}" == "open"`) to dynamically skip or proceed with steps.
*   **Failure Control**: Respects `on_failure` policies (`stop`, `skip_remaining`, `continue`) to handle misbehaving tasks safely.

### 1.3 Parsers & Templating (`parser.py`, `templating.py`, `share_parser.py`)
*   **Regex Template Engine**: Jinja2-style syntax resolves variables like `{target}` or `{checklist_item.key}` dynamically prior to execution.
*   **Share Parser**: A dedicated parser that processes outputs from tools like SMBMap or NetExec, automatically populating the `DiscoveredFile` (Shares) table with structured data.
*   **Service Parser**: Identifies standard service/port combinations (from outputs like RustScan/Nmap) and updates the `Service` definitions linked to an asset in real-time.

### 1.4 Collaboration & Synchronization (`sync.py`, `sync_worker.py`)
*   **Multi-Node Event Replication**: Enables two operators on separate machines to collaborate.
*   **Logical Clocks & Cursors**: Employs a logical timestamp `logical_ts` cursor to track synced events.
*   **Deterministic Ingestion**: Remote events are sorted and ingested based on database constraint dependencies (e.g., Users → Projects → Hosts → Executions) to prevent foreign key errors.

### 1.5 Real-Time Notifications (`notifications.py`)
*   **WebSocket Broadcasting**: Pushes `EXECUTION_UPDATE`, `HOST_CREATED`, and `VARIABLE_UPDATED` events directly to the React frontend, eliminating the need for HTTP polling.

## 2. Frontend Architecture & State Management

The frontend leverages React 18, Vite, and Zustand for robust, snappy interactions.

### 2.1 State Management (Zustand Stores - `stores/index.js`)
*   `useAppStore`: Manages global UI state (sidebar toggles, active notifications, WebSocket connection status).
*   `useAuthStore`: Handles JWT authentication, initialization, and token storage.
*   `useProjectsStore`: Caches project lists, details, and dynamic variables.
*   `useHostsStore`: Manages asset lists, ensuring quick sorting and filtering in the UI.
*   `useChecklistsStore`: Manages dynamic task checklists, groups, claims, and execution statuses.
*   `useExecutionsStore`: Separates running executions from historical ones, ensuring real-time log polling binds efficiently to active components.

### 2.2 Core View Components
*   **Project Detail (`ProjectDetail.jsx`)**: The heavy-lifting dashboard component. Manages the host list (AssetsView), variables, checklist groups, and triggers command execution workflows.
*   **Flow Editor (`FlowEditor.jsx` & `FlowViewer.jsx`)**: Powered by `reactflow`. Provides a visual drag-and-drop node interface. Users can link outputs to inputs, create complex conditionals, and save topological configurations into the DB.
*   **Host Dashboard (`HostDashboard.jsx`)**: A drilled-down view of a specific target, showing its services, discovered files/shares, and a targeted timeline of commands executed purely against it.

## 3. Host Agent Execution Model

*   **Standalone Process (`host_agent/main.py`)**: A lightweight FastAPI wrapper meant to run directly on the host OS (outside of Docker boundaries) to enable native network access (like VPN bounds) and tool execution.
*   **Server-Sent Events (SSE)**: Uses the `/run_and_stream` endpoint. When the backend Orchestrator calls this, the Agent spawns a subprocess using `asyncio.create_subprocess_shell`.
*   **Process Streaming**: Asynchronous queues pipe `stdout` and `stderr` back to the backend in real-time.
*   **Lifecycle Management**: Incorporates strict timeouts and process-group (PGID) termination (`SIGTERM`) to kill hanging child processes securely.

## 4. Advanced Data Models

*   **Variables**: Split between `ProjectVariable` (scoped globally to an engagement) and localized Host parameters.
*   **Checklist Claims**: Optimistic locking model where operators can "claim" a checklist item to notify collaborators they are actively working on it.
*   **Flow Steps**: Hierarchical models where a `Flow` contains `FlowStep`s, mapped to `ChecklistItem`s, enriched with regex mapping schemas.

## 5. Summary of Key UX/UI Implementations
*   Glassmorphic dark-mode aesthetics using TailwindCSS.
*   Dynamic table sorting (e.g., IP addresses sorted numerically rather than strings).
*   Search interface parsing massive logs with regex support across executions.
*   Floating terminal/output viewers (`OutputModal`) with log tracking.
