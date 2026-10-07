# Contributing

## Commits

One logical change per commit. A message is short and says why the
change is wanted, never how it was done; the diff shows how. No
`Co-Authored-By` or other trailers.

A fix to a commit that is still in review is amended into that commit,
not added on top.

## Pull requests

Every commit is its own pull request, so each can be reviewed alone.
When commits depend on each other, they form a stack with
[gh stack](https://github.com/github/gh-stack): each pull request
targets the branch of the one before it.

```bash
gh stack view          # the stack and its pull requests
gh stack push          # push every branch and update the pull requests
```

After amending a commit lower in the stack, rebase the branches above
it and push the stack again.

## Review guides

A change over 100 lines comes with `REVIEW_GUIDE.md` at the repository
root: the order to read the change in, and what deserves a close look.
It is gitignored and never committed.
