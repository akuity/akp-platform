# Onboarding a new app

Adding an app touches exactly one place: a new directory under `apps/`.
`bootstrap/` never changes — its ApplicationSets discover `apps/*/argocd` and
`apps/*/kargo` from git and deploy them automatically on merge.

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
│   ├── appproject.yaml        # name: orders, sync-wave -1
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

- [ ] `argocd/appproject.yaml` carries `argocd.argoproj.io/sync-wave: "-1"` so
      the AppProject exists before the ApplicationSet that references it.
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
