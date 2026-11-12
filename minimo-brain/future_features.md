# Minimo MindPilot — Future Frontier & Cognitive Cloud Features
**Target:** System 2 Hybrid Architecture (Local Edge Qwen 2.5 1.5B/3B + Frontier Cloud `gemini-3.5-flash-lite`)  
**Status:** Architecture Blueprint & Staged Implementation Roadmap

---

## 1. Executive Architecture: Hybrid Edge + Cloud
Minimo MindPilot is designed as a **privacy-first, local-first assistant**. The local edge model (**Qwen 2.5 1.5B / 3B**) runs completely offline on CPU/iGPU with sub-second response times for desktop automation, media controls, task management, and fast shell execution.

Frontier cloud models (specifically **Gemini 3.5 Flash Lite** on the Google AI Studio free tier: **15 RPM, 500 RPD, 250k TPM**) are reserved strictly for high-entropy cognitive workloads:
* **Multimodal Vision:** Visual understanding of screenshots, charts, whiteboards, and receipts.
* **Long-Context Synthesis:** Synthesizing complex answers across multiple textbooks and lecture notes.
* **Complex Reasoning & Planning:** Goal decomposition, week planning, multi-step shell pipelines, and diff debugging.

All personal files, notes, and Maildir remain local. Only distilled context (e.g. top retrieved passages or explicitly snapped screenshots) is ever transmitted to the cloud.

---

## 2. Core Cloud Capabilities (User Feature Matrix)

### A. Screen Understanding (Multimodal Desktop Vision)
* **Intent:** `screen_understanding`
* **Trigger:** *"What is this error?"*, *"Explain this chart"*, *"What should I click here?"*, or `Super + Print` with active selection.
* **Execution Flow:**
  1. Capture the focused window or screen region using `grim -g "$(slurp)"` or `hyprctl activewindow`.
  2. Compress image to high-efficiency WebP/JPEG in `/tmp/minimo_screen.webp`.
  3. Send image + prompt to Gemini Flash Lite multimodal endpoint.
  4. Stream visual analysis, error cause, or exact UI button instructions directly into the MindPilot card.
* **Why Cloud:** 1.5B local models fail at spatial coordinate understanding, chart trend analysis, and dense stack trace OCR. Frontier vision models interpret complex graphs and UI hierarchies effortlessly.

---

### B. Photo & PDF Intake (Whiteboard, Receipt & Notes Ingestion)
* **Intent:** `intake_document`
* **Trigger:** Drop a photo/PDF into `~/inbox/intake/`, photograph a whiteboard, or scan a book page.
* **Execution Flow:**
  1. MindPilot detects new media file in `~/inbox/intake/`.
  2. Send file parts to Gemini Flash Lite with structured schema prompts:
     * **Whiteboard/Diagrams:** Transcribe formulas into clean LaTeX (`$$...$$`), extract bulleted mindmaps into Org-mode/Markdown.
     * **Receipts:** Extract vendor, date, line items, currency, and total amount.
     * **Book/Paper Pages:** Extract summary, core definitions, and flashcards (Anki/Org-drill format).
  3. Emit an interactive Action Card in MindPilot: `[Save to Notes]`, `[Add to Todoist]`, or `[Log Expense]`.

---

### C. SQLite Budget & Quota Tracker (Local Safeguard)
* **Intent:** System Middleware & Enforcement
* **Mechanism:**
  * Tracks every cloud request in `~/.local/share/minimo/cloud_quota.db`.
  * Maintains sliding-window counts:
    * **RPM Check:** Max 15 requests per minute (enforces safety margin at 12 RPM).
    * **RPD Check:** Max 500 requests per day (resets at midnight UTC).
  * **Graceful Degradation:** When 90% of quota is reached, a subtle badge appears in Minimo (`Cloud Quota: 450/500`). When 100% is reached, requests automatically fall back to local Qwen 2.5 1.5B/3B (or local DeepSeek-R1 8B), and the UI displays:  
    *`"Cloud quota reached for today (500/500). Running in local edge mode."`*

---

### D. Deep RAG Answers (Hybrid Local Retrieval + Cloud Synthesis)
* **Intent:** `deep_rag_synthesis`
* **Trigger:** *"Synthesize how Prandtl's lifting-line theory compares with modern vortex lattice methods across my aero books"*, *"What do my notes say about Paxos vs Raft edge cases?"*
* **Execution Flow:**
  1. **Local Privacy Retrieval:** SQLite FTS5 (BM25) + local embedding vector search (`nomic-embed-text`) runs completely offline against local notes and books.
  2. **Top Passage Filtering:** Extract only the top 5–8 most relevant passages (top 2,500 tokens).
  3. **Cloud Synthesis:** Transmit ONLY these extracted passages to Gemini Flash Lite for deep cross-document synthesis.
  4. **Output:** Cohesive, highly articulate synthesis with page citations, without ever uploading the user's private library or full PDFs.

---

### E. Goal & Weekly Planner (Interactive Todoist Project Decomposition)
* **Intent:** `project_weekly_planner`
* **Trigger:** *"Plan my week around these deadlines"*, *"Break down my aerodynamic wing design project into actionable tasks"*.
* **Execution Flow:**
  1. Ingest upcoming deadlines from Todoist + calendar schedule.
  2. Cloud model decomposes high-level goals into chronological milestones with priority flags (`P1/P2/P3`) and estimated durations.
  3. MindPilot renders an interactive **Plan Approval Card** with checkboxes.
  4. User reviews, adjusts, and clicks `[Approve Plan]`. MindPilot pushes all items to Todoist via REST API in one batch.

---

### F. Complex Command & Multi-Step Shell Script Generator
* **Intent:** `complex_cmd_generation`
* **Trigger:** Multi-step pipelines, complex `awk`/`sed`/`find` one-liners, or system administration scripts.
* **Execution Flow:**
  * **Simple Commands:** Local Qwen 2.5 handles atomic commands (`pactl`, `git status`, `systemctl restart ...`) in <250ms.
  * **Complex Pipelines:** Queries like *"Find all videos older than 30 days in ~/Downloads, compress them to H.265 using ffmpeg, and move them to ~/Archive"* escalate to cloud.
  * Generates well-commented bash script with error checks (`set -euo pipefail`).
  * Emits an interactive MindPilot card with syntax highlighting and a single-click `[Review & Execute]` safety gate.

---

### G. Code & Config Differential Debugger
* **Intent:** `code_diff_debugger`
* **Trigger:** *"Why is this QML layout failing?"*, *"Explain this git diff"*, *"Debug my Hyprland crash log"*.
* **Execution Flow:**
  1. Capture git diff (`git diff HEAD~1` or staged) or active compile error from terminal stderr.
  2. Cloud model performs root cause analysis, checks for syntax gotchas or race conditions, and explains the diff in plain English.
  3. Produces a unified diff patch ready for `git apply`.

---

## 3. Complementary Desktop-First Features (Proposed)

### H. Desktop "Ask About This" (Active Window Context Injector)
* **Concept:** Single-key contextual inquiry.
* **Mechanism:** When the user summons Minimo with `Super + Space` while focused on any window (terminal, browser, IDE), Minimo inspects `hyprctl activewindow`.
* **User Experience:** User can simply type:
  * *"Fix this"* (if in terminal with compiler error).
  * *"Summarize this section"* (if in browser or document reader).
  * *"What is this function doing?"* (if in editor).
* Minimo automatically pulls the last terminal buffer or page title without manual copy-pasting.

---

### I. Automated Quickshell / Hyprland Reload Guardian (Self-Healing Dotfiles)
* **Concept:** Instant hot-reload debugging for user desktop shell.
* **Mechanism:**
  * Watches `journalctl --user -xe -u quickshell` and Hyprland crash logs.
  * If a QML parse error or Wayland binding failure occurs, Minimo pops up a mini notification card:  
    *`"Quickshell syntax error at MinimoBlob.qml:184. Click to auto-repair."`*
  * One-click repair parses the error line, calls the cloud model for the fix, and hot-reloads Quickshell.

---

### J. Interactive Multi-Step Pipeline Wizard
* **Concept:** Step-by-step interactive execution for complex tasks.
* **Mechanism:** Rather than executing a 5-step script blindly, MindPilot renders a stepper card:
  * `[✓] Step 1: Backup config to ~/.config.bak`
  * `[ ] Step 2: Download v0.4 release from GitHub`
  * `[ ] Step 3: Symlink binary to ~/.local/bin`
* User can run steps individually or click `[Run All]`.

---

### K. Structured Plain-Text Accounting (Hledger Ingestion)
* **Concept:** Turn receipts and payment notifications into ledger entries.
* **Mechanism:** When a photo of a bill or an email receipt is processed, the model parses it into standard Plain Text Accounting format:
  ```ledger
  2026-10-26 Campus Canteen | Lunch
      expenses:food:campus          ₹180
      assets:bank:upi
  ```
  Appends directly to `~/org/finances/2026.journal` upon approval.

---

### L. Contextual Clipboard Micro-Actions
* **Concept:** Zero-latency action suggestions based on recent clipboard content.
* **Mechanism:** If user copies a URL, JSON blob, or shell snippet and opens Minimo within 60 seconds, Minimo displays subtle pill buttons:
  * URL: `[Fetch & Summarize]`, `[Bookmark to Readwise]`
  * JSON: `[Validate & Format]`, `[Convert to TypeScript Type]`
  * Error stack trace: `[Analyze Root Cause]`

---

## 4. SQLite Quota Tracker Schema (`cloud_quota.db`)

```sql
CREATE TABLE IF NOT EXISTS cloud_requests (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp REAL NOT NULL,
    model TEXT NOT NULL,
    feature TEXT NOT NULL,
    prompt_tokens INTEGER DEFAULT 0,
    completion_tokens INTEGER DEFAULT 0,
    cost_usd REAL DEFAULT 0.0,
    status TEXT NOT NULL -- 'success', 'rate_limited', 'fallback_local'
);

CREATE INDEX IF NOT EXISTS idx_cloud_timestamp ON cloud_requests(timestamp);
```

### Quota Evaluation Logic:
* **RPM Check:**  
  `SELECT COUNT(*) FROM cloud_requests WHERE timestamp > (strftime('%s','now') - 60) AND status = 'success';`  
  If `>= 12` (safety threshold for 15 RPM limit), throttle for `60 - elapsed` seconds or fall back.
* **RPD Check:**  
  `SELECT COUNT(*) FROM cloud_requests WHERE timestamp > (strftime('%s','now', 'start of day')) AND status = 'success';`  
  If `>= 490` (safety threshold for 500 RPD limit), switch to local mode until next day.

---

## 5. Escalation Decision Flow

```
                     ┌───────────────────────┐
                     │   User MindPilot Query│
                     └───────────┬───────────┘
                                 │
                 ┌───────────────┴───────────────┐
                 │ System 1: Reflex Fast-Path    │ (< 0.1ms)
                 │ (Exact commands, status, mail)│
                 └───────────────┬───────────────┘
                                 │ Not hit
                 ┌───────────────▼───────────────┐
                 │ System 2: Local Edge Qwen     │ (< 250ms)
                 │ (Intent routing, atomic cmds) │
                 └───────────────┬───────────────┘
                                 │
         ┌───────────────────────┴───────────────────────┐
         │ Needs Cloud Frontier Cognitive Reasoning?    │
         │ (Vision, Deep Synthesis, Weekly Planner, Diff)│
         └───────────────────────┬───────────────────────┘
                                 │ YES
                 ┌───────────────▼───────────────┐
                 │ Quota Guard (cloud_quota.db)  │
                 │ 15 RPM / 500 RPD check        │
                 └───────┬───────────────┬───────┘
                         │ Quota OK      │ Quota Exceeded
         ┌───────────────▼─────┐   ┌─────▼───────────────┐
         │ Gemini 3.5 Flash    │   │ Graceful Fallback to│
         │ Lite (Streaming API)│   │ Local DeepSeek /    │
         │ (~1.2s response)    │   │ Local Qwen 2.5 3B   │
         └─────────────────────┘   └─────────────────────┘
```
