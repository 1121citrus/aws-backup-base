# Contributing

## Protected branches and tags

`main` cannot be force-pushed or deleted. The required GitHub Actions checks
are listed in **Settings > Rules > Rulesets > Require main checks**. Missing
or failed checks block updates; GitHub also accepts skipped and neutral
results. The repository owner is the only actor allowed to create, update,
or delete `v*` tags.

Inspect and fix failed Actions runs before retrying. If a check is missing,
verify that its workflow runs on the source branch. After renaming a check,
verify the new name on a branch and update the ruleset before promoting that
change to `main`.
