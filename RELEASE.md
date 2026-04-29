# Release Process

## Automated Release Workflow

This repository uses automated releases triggered by VERSION file changes.

### How It Works

1. **Update VERSION file on main**
   ```bash
   echo "1.30" > VERSION
   git add VERSION
   git commit -m "chore: bump version to 1.30"
   git push origin main
   ```

2. **Auto-Trigger**
   - `.github/workflows/release.yml` detects VERSION change
   - Creates git tag: `v1.30`
   - Generates GitHub Release with automatic release notes
   - **Tag is created on main commit** (not feature branch)

### Important Notes

⚠️ **ALWAYS update VERSION on main, NEVER on feature branches**

**Correct workflow:**
```bash
# On main
git pull origin main
echo "1.30" > VERSION
git push origin main
# → Workflow auto-creates v1.30 tag ✅
```

**Incorrect workflow:**
```bash
# On feature branch
echo "1.30" > VERSION
git push origin fix/my-feature
# → Tag created on wrong branch ❌
```

### Manual Release (if needed)

```bash
# Ensure on main with latest changes
git checkout main
git pull origin main

# Create tag
git tag -a v1.30 -m "Release v1.30"
git push origin v1.30

# Create GitHub Release (optional, workflow will do this)
gh release create v1.30 --generate-notes
```

### Troubleshooting

**Tag points to wrong commit:**
```bash
# Delete wrong tag
git tag -d v1.30
git push origin :refs/tags/v1.30

# Recreate on correct commit
git checkout main
git pull origin main
echo "1.30" > VERSION
git push origin main
# Workflow will auto-create correct tag
```

**Workflow didn't trigger:**
- Check `.github/workflows/release.yml` exists
- Ensure VERSION file change was pushed to main
- Check Actions tab for logs

---

**Important:** Tags must always point to main commits, never feature branches. The automated workflow ensures this if you follow the process above.
