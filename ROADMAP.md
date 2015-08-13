# ROADMAP

## Versions

We will support two versions "for a little while":

* `0.2.x` - the original code, `master` branch. Bugfixes for critical issues only.
* `0.9.x` - in flux, beta - `v1-pre` branch. API is explicitly open to breaking.
* `1.0.x` - final v1 - locked API. Flows from `0.9.x` - `v1-pre` branch.

## NPM versions

We will publish two versions "for a little while":

* `0.2.x`
* `0.9.x-beta` -> `1.0.x-beta` -> `1.0.0`

## What's a little while?

When beta `1.0.0` is stable and large services are running in production on it for ~weeks and we've locked the API, we'll publish `v1.0.0` and deprecate `0.2.x`. At that point, `0.2.x` will not be supported and all downstream users must upgrade.

## New features

New features should be implemented against `v1-pre`. New feature requests will not be merged against `master`.