# Import local repositories into Forgejo

`scripts/import-local-repos-to-forgejo.sh` imports every direct Git repository
under `~/Projects` into private repositories owned by `ryan` at
`forgejo.home.rpca.uk`. It preserves existing remotes, adds a separate
`forgejo` remote, and pushes all committed branches and tags.

Uncommitted changes are deliberately not staged, committed, or pushed. Clean or
commit them separately when ready.

## One-time access token

In Forgejo, open **Settings > Applications > Generate New Token** and create a
short-lived token named `local-repo-import` with:

- repository access: **All (public, private, and limited)**;
- scope: **`write:repository`**.

Run the importer locally; it prompts for the token without echoing or storing
it in Git, shell history, or Git remote URLs:

```sh
cd ~/Projects/homelab
./scripts/import-local-repos-to-forgejo.sh
```

After a successful import, revoke the token in Forgejo. Future pushes can use
a normal Forgejo SSH key or a repository-scoped credential.
