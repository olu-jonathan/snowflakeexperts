# Task DAG — Parent-Child Relationship

## How Task Chains Work

Only the **root task** has a `SCHEDULE`. Child tasks use `AFTER` to define their dependency.

```
        ┌───────────────────────────────┐
        │     pipeline_step1_load       │  ← ROOT TASK (has SCHEDULE)
        │     SCHEDULE = '60 MINUTE'    │
        └───────────────┬───────────────┘
                        │
                        │  executes AFTER step 1 succeeds
                        ▼
        ┌───────────────────────────────────┐
        │   pipeline_step2_transform        │  ← CHILD TASK (no schedule)
        │   AFTER pipeline_step1_load       │
        └───────────────┬───────────────────┘
                        │
                        │  executes AFTER step 2 succeeds
                        ▼
        ┌───────────────────────────────────────┐
        │       pipeline_step3_log              │  ← GRANDCHILD TASK
        │   AFTER pipeline_step2_transform      │
        └───────────────────────────────────────┘
```

---

## Rules

```
    ╔══════════════════════════════════════════════════════════════╗
    ║  TO RESUME:   resume children FIRST, then root (bottom-up) ║
    ║  TO SUSPEND:  suspend root FIRST, then children (top-down) ║
    ╚══════════════════════════════════════════════════════════════╝
```

---

## Multiple Children (Fan-Out)

A root task can trigger multiple children in parallel:

```
                ┌───────────────────────┐
                │    root_task          │
                │  SCHEDULE = '1 HOUR'  │
                └───┬───────────┬───────┘
                    │           │
          ┌─────────┘           └─────────┐
          ▼                               ▼
┌─────────────────────┐       ┌─────────────────────┐
│  child_transform_a  │       │  child_transform_b  │
│  AFTER root_task    │       │  AFTER root_task    │
└─────────┬───────────┘       └─────────┬───────────┘
          │                             │
          └──────────┐   ┌──────────────┘
                     ▼   ▼
            ┌─────────────────────┐
            │   final_merge_task  │
            │ AFTER child_a, b    │
            └─────────────────────┘
```

In this pattern:
- `child_transform_a` and `child_transform_b` run **in parallel** after root completes
- `final_merge_task` runs only after **both** children succeed

---

## Key Points

| Concept | Detail |
|---------|--------|
| Root task | Only task with a `SCHEDULE` — starts the DAG |
| Child task | Uses `AFTER parent_task` — no schedule of its own |
| Fan-out | Multiple children with `AFTER` same parent run in parallel |
| Fan-in | A task with multiple `AFTER` predecessors waits for ALL to finish |
| Max depth | Up to 1,000 tasks in a single DAG |
| Failure | If a parent fails, children do NOT execute |
