# Onboarding a new app

Adding an app touches exactly one place: a new directory under `apps/`.
`bootstrap/` never changes — its ApplicationSets discover `apps/*/argocd` and
`apps/*/kargo` from git and deploy them automatically on merge.

## Before you touch anything

The `guestbook-*` app directories and `kargo-shared/` are demos, not
scaffolding to keep. Copying the closest example (below) is the right way to
start — but copy, then cut down, don't just rename fields and leave
everything else:

- **Delete stages/tasks you don't use.** Don't rename an example stage
  (`uat` → `non-prod`, say) and leave the rest of that stage's structure in
  place if it doesn't match your actual promotion flow — figure out your
  dev/staging/prod (or whatever) shape first, then write only those stages.
- **`kargo-shared/`'s CustomPromotionSteps are opt-in**, not a dependency
  every app needs. If your app doesn't call one, don't wire the app up to
  reference it — and if nothing in your fork uses `kargo-shared/` at all,
  it's safe to delete the directory and its bootstrap Application entirely.
- **Every field in the example `appproject.yaml` / `kargo/project.yaml` is
  either load-bearing (keep it) or a placeholder (replace it)** — see the
  inline comments in each file before assuming a field is boilerplate.

If you're not sure whether something is convention or example content, check
whether it's mentioned in this doc's "naming convention" or "required
layout" sections below — if it isn't, it's probably example content.

## The naming convention (load-bearing)

Pick one name and reuse it everywhere. For an app named `orders`:

| Thing | Value |
|---|---|
| Directory | `apps/orders/` |
| Argo CD AppProject | `orders` (bootstrap templates `project: '{{path[1]}}'`) |
| Kargo Project | `orders` |
| Argo CD Applications | `orders-<stage>` |
| Namespaces | `orders-<stage>` |
| Rendered branches (if used) | `rendered/orders/<stage>` (see [environments.md](environments.md)) |

## Required layout

```
apps/orders/
├── README.md                  # what the app is, which pattern it uses
├── argocd/
│   ├── appproject.yaml        # name: orders
│   └── appset.yaml            # one Application per env, authorized-stage annotations
├── kargo/
│   ├── project.yaml           # sync-wave -1
│   ├── warehouse.yaml
│   ├── stages.yaml
│   └── tasks.yaml
└── base/ | env/ | chart/      # the app's manifests
```

Start by copying the closest example:

- `guestbook-rendered` — Kustomize, hydrated env branches (most auditable)
- `guestbook-kustomize` — Kustomize, tag bumps committed to main (simplest)
- `guestbook-helm` — Helm, values bumps committed to main
- `guestbook-helm-rendered` — Helm, hydrated env branches (best base for
  previews/golden paths)

## Checklist before opening the PR

- [ ] `kargo/project.yaml` carries `argocd.argoproj.io/sync-wave: "-1"` so the
      project namespace exists before its Warehouse/Stages.
- [ ] Every Application the pipeline syncs carries
      `kargo.akuity.io/authorized-stage: <project>:<stage>` — without it the
      `argocd-update` step is refused.
- [ ] PromotionTask paths are repo-root-relative:
      `./src/apps/orders/env/...`.
- [ ] If promotions **commit to main**: the Warehouse must be image-only (or
      exclude the paths promotions write) — otherwise every promotion creates
      new Freight in a loop.
- [ ] If promotions **push rendered branches**: scope the git subscription
      with `includePaths: [apps/orders]` so other apps' changes don't create
      Freight.
- [ ] Do **not** set a `shard:` field on Stages unless you know your shard
      name — pinning to a nonexistent shard makes promotions hang silently.
- [ ] New Kargo project ⇒ new git credentials (they're per-project). Add the
      project to `add-credentials.sh`, or use one shared/global credential —
      see "Option B" under step 4 in the root README.

## What you should NOT need to do

- Edit anything in `bootstrap/`.
- Create a per-app app-of-apps or a `kargo-crs.yaml` Application.
- Copy `personalize.sh` / `download-cli.sh` into your app directory.
- Invent new image-tag or branch naming schemes — reuse the contracts above.
