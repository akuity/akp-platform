# akp-platform — Akuity Platform Quickstart

A batteries-included GitOps platform repo for the [Akuity Platform](https://akuity.io)
(hosted Argo CD + Kargo). Fork it, run one script, apply **one** manifest, and you
get four working promotion pipelines demonstrating the four fundamental
GitOps delivery patterns — then grow into app monorepos, Terraform-managed
infrastructure, and team onboarding without restructuring anything.

This repo is one of three, and works standalone:

| Repo | Role | Needed for the quickstart? |
|---|---|---|
| **akp-platform** (this repo) | All GitOps config: Argo CD apps, Kargo pipelines | ✅ yes — works alone |
| [akp-monorepo](https://github.com/akuity/akp-monorepo) | App source code + CI that builds images | optional — [add it later](docs/add-monorepo.md) |
| [akp-infra](https://github.com/akuity/akp-infra) | Terraform for Argo CD/Kargo instances, clusters, agents | optional — [its own journey](docs/add-infra.md) |

## What you get

```
                            ┌────────────────────────────────────────────┐
 bootstrap/platform-aoa ──► │ argocd-apps ApplicationSet (apps/*/argocd) │──► AppProjects + app ApplicationSets
 (the ONE thing you apply)  │ kargo-apps  ApplicationSet (apps/*/kargo)  │──► Kargo Projects/Warehouses/Stages
                            └────────────────────────────────────────────┘
```

Four self-contained example apps, one per delivery pattern (each is
`Warehouse → dev → staging → prod`, watching the public
`ghcr.io/akuity/guestbook` image so nothing needs to be built):

| | **Promotions commit to `main`** | **Promotions push to `rendered/*` branches** |
|---|---|---|
| **Kustomize** | [`apps/guestbook-kustomize`](apps/guestbook-kustomize/) — bump overlay tag on main | [`apps/guestbook-rendered`](apps/guestbook-rendered/) — `kustomize build` → hydrated branch |
| **Helm** | [`apps/guestbook-helm`](apps/guestbook-helm/) — bump values tag on main | [`apps/guestbook-helm-rendered`](apps/guestbook-helm-rendered/) — `helm template` → hydrated branch |

Each app directory has a README explaining its pattern and trade-offs. The
convention throughout (and the thing to internalize): **the `apps/<name>/`
directory name IS the Argo CD AppProject name IS the Kargo Project name.**
Bootstrap discovers apps by directory — onboarding never touches `bootstrap/`.

## Prerequisites

- An Akuity Platform organization with an **Argo CD instance** and a **Kargo
  instance** (create them in the UI, or declaratively with
  [akp-infra](https://github.com/akuity/akp-infra)).
- A workload cluster connected to Argo CD (any name — the personalize script
  asks for it).
- The Kargo instance registered in Argo CD as a cluster destination
  (Akuity does this when you link the instances; default name `kargo`).
- `argocd` CLI logged in to your instance; `kargo` CLI
  (`./download-cli.sh /usr/local/bin/kargo`) logged in
  (`kargo login <your-kargo-url>`).
- A GitHub account and a token with **repo write** access to your fork
  (Kargo pushes promotion commits/branches).

## Quickstart

**1. Fork this repo** (keep the name `akp-platform` and keep it public —
Argo CD and Kargo read it anonymously), then clone your fork.

**2. Personalize it** — rewrites the placeholder org/cluster names in-place:

```sh
./personalize.sh
git add -A && git commit -m "personalize" && git push
```

**3. Bootstrap** — the only two manifests you ever apply by hand. This repo
never assumes Argo CD's built-in `default` AppProject is usable — many orgs
lock it down to deny-by-default as a security baseline, and bootstrap works
unmodified either way because it brings its own scoped project. Run these
**in order** — `platform-aoa` references the `akp-bootstrap` project, so it
must exist first:

```sh
# 1. The AppProject platform-aoa depends on.
argocd proj create -f bootstrap/akp-bootstrap-project.yaml --upsert

# 2. The root app-of-apps.
argocd app create -f bootstrap/platform-aoa.yaml --upsert
```

Both steps use the `argocd` CLI you're already logged in with. On Akuity the
Argo CD control plane is hosted, so you have no kubeconfig for it, and
`kubectl apply` would land in whatever cluster your current context points at.
`--upsert` makes both commands safe to re-run. After step 2, `platform-aoa`
syncs `bootstrap/` and adopts the project, so from then on it's managed from
git like everything else.

If you only run step 2 (e.g. re-running after an interrupted bootstrap),
Argo CD will reject it or leave it perpetually out-of-sync with a
"project akp-bootstrap not found"-style error — re-run step 1 first.

Within a minute or two you should see `platform-aoa`, `argocd-*`, and
`kargo-*` Applications in Argo CD, and four Projects in the Kargo UI.

**4. Give Kargo git credentials** — promotions push commits to your fork.
Two ways to do it:

*Option A — per-project (the default here; zero instance setup).* Kargo
credentials are namespaced per project — that's Kargo's isolation model, and
it works on a stock instance with nothing but the CLI. The script adds the
same token to all four projects for you:

```sh
./add-credentials.sh   # prompts for GitHub username + token once
```

*Option B — one shared (global) credential.* Kargo can treat designated
namespaces (conventionally `kargo-shared-resources`) as a global credential
source that all projects fall back to — one secret instead of a copy per
project. This needs the global-credentials namespace enabled in your Kargo
instance settings first; on the Akuity Platform you can then deliver the
secret via agent secret-sync from a workload cluster. Sketch (check the
[Akuity docs](https://docs.akuity.io) for current labels/settings):

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: github-creds
  namespace: akuity              # on your workload cluster; the agent syncs it up
  labels:
    kargo.akuity.io/secret-sync: kargo-shared-resources
    kargo.akuity.io/cred-type: git
stringData:
  repoURL: https://github.com/<your-org>/.*
  repoURLIsRegex: "true"
  username: <github-username>
  password: <token-with-repo-write>
```

Option A gets you promoting fastest; switch to Option B when per-project
copies of the same token start to feel like sprawl (many projects, token
rotation).

**5. Promote!** Open the Kargo UI, pick a project (start with
`guestbook-rendered`), and promote the freshest Freight into `dev`, then on
through `staging` and `prod`. Then do the same in the other three projects
and compare what each promotion did to git:

- `guestbook-rendered` / `guestbook-helm-rendered` → new commits on
  `rendered/<app>/<stage>` branches (plain rendered YAML)
- `guestbook-kustomize` / `guestbook-helm` → new commits on `main`
  (a one-line tag bump)

> **Expected:** the two `*-rendered` apps show Argo CD comparison errors until
> their first promotion — the rendered branches don't exist yet. Promoting to
> `dev` creates them.

> **Requires Akuity-hosted Kargo:** `kargo-shared/` uses the
> `ee.kargo.akuity.io` API group. On a Kargo without it, the `kargo-shared`
> app reports `no matches for kind CustomPromotionStep` — expected, and nothing
> else is affected. See [`kargo-shared/`](kargo-shared/).

## Choosing a pattern

- **Start with `guestbook-rendered`** if you want maximum auditability: every
  environment's exact manifests live on a plain-YAML branch.
- **`guestbook-kustomize` / `guestbook-helm`** if you want the simplest
  possible model: one branch, promotions are readable one-line commits.
- **`guestbook-helm-rendered`** if you author in Helm but want hydrated
  output — it's also the primitive behind PR-preview environments and
  templated golden paths, so it's the best base to grow from.

Delete the app directories you don't want — bootstrap prunes them
automatically (that's the point).

Wondering why two of these push to branches when you've read that
branch-based environments are an anti-pattern? See
**[docs/environments.md](docs/environments.md)** — rendered branches are
storage, not environments, and the distinction matters before you copy the
pattern into a real repo.

## Growing beyond the quickstart

- **[Environments and rendered output](docs/environments.md)** — where
  rendered manifests live and why, the `env/` vs `rendered/` split, and the
  alternatives (rendering into `main`, a shared branch, a separate repo).
- **[Onboard a real app / team](docs/onboarding.md)** — the conventions and
  checklist for adding `apps/<your-app>/`.
- **[Add the app monorepo](docs/add-monorepo.md)** — build your own images
  with CI and point Warehouses at them instead of the public guestbook.
- **[Manage the platform with Terraform](docs/add-infra.md)** — the
  [akp-infra](https://github.com/akuity/akp-infra) journey: instances,
  clusters, and agents as code.

## Repo layout

```
bootstrap/            # akp-bootstrap-project.yaml, platform-aoa.yaml, the
                      #   two discovery ApplicationSets, and the kargo-shared
                      #   Application
kargo-shared/         # CustomPromotionSteps shared by every Kargo Project
apps/<name>/          # one self-contained app: argocd/ + kargo/ + manifests
  argocd/             #   AppProject + ApplicationSet (platform-team owned)
  kargo/              #   Project, Warehouse, Stages, PromotionTask, analysis
  base|env|chart/     #   the app's manifests (app-team owned)
docs/                 # onboarding + growth guides
```

`.github/CODEOWNERS` shows the intended ownership split: platform team gates
`bootstrap/`, `kargo-shared/`, and every app's `argocd/` + `kargo/`; app teams
own their manifests.

Need a promotion to do something no built-in Kargo step covers — run a
migration, call a policy engine, post a notification? See
[`kargo-shared/`](kargo-shared/), which ships two runnable examples and a
commented-out invocation in `guestbook-kustomize`.
