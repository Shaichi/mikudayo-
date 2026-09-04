# `.sdd/` — Spec-Driven Development + ADD cho Miku Japanese Conversation

Thư mục này chứa toàn bộ SDD + ADD artifact cho repository. Adoption theo
skill `sdd-adopt` — profile ban đầu ở `architecture-profile.md` có
`PENDING HUMAN REVIEW` cho mọi binding mâu thuẫn hoặc chưa resolve.

## Cấu trúc

```text
.sdd/
├── README.md                  File này
├── architecture-profile.md    Source of truth cho tech stack (PENDING HUMAN REVIEW)
├── shared_context.md          Cross-feature notes (sửa sau khi profile approved)
├── mcp-config.yaml            MCP server bindings cho SDD toolchain (placeholder)
├── constraints/
│   ├── global.md              Cross-cutting non-negotiables
│   ├── business.md            Domain-specific constraints
│   └── safety.md              API key, audio, voice rights
├── features/                  Mỗi feature có CONTEXT/SPEC/PLAN/TASKS
└── reviews/
    └── adopt-mikudayo.md      AI recommendation của adoption này
```

`CONSTITUTION.md`, `AGENTS.md` được đặt ở root; chỉ thay đổi qua RFC
(`/sdd-rfc --approve=<n>`).

## Bắt đầu

1. Human Director/Tech Lead review `.sdd/architecture-profile.md` §11
   (PENDING HUMAN REVIEW) — chốt các binding mâu thuẫn.
2. Sau khi profile approved → `/sdd-context --feature=feat-001-<slug>` để
   bắt đầu feature mới.
3. `/sdd-review` để ghi nhận Human Final Review cho mỗi artifact.

## Slash commands

Tất cả slash command `/sdd-*`, `/add-*`, `/git-*` đã có sẵn trong skill
catalog. Chạy từ session Claude Code hiện tại.

## Quy tắc

- Không commit `.env`, audio runtime, SQLite runtime, installer ngoài dự án.
- Không self-approve recommendation. Luôn `PENDING HUMAN REVIEW` cho đến
  khi Human Director/Tech Lead dùng `/sdd-review`.
- Stack binding conflict (URP vs Built-in RP, NDK version) phải resolve
  trước khi chạy `/sdd-plan` hoặc `/sdd-tasks`.