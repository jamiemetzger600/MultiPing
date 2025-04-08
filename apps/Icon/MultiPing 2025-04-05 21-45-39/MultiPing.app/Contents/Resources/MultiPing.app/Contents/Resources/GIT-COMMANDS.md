# 📘 Git Commands for MultiPing Project

## 📦 Setup (done once)
```bash
cd "path/to/MultiPing"
git init
git add .
git commit -m "Initial stable base"
```

## 💾 Save changes (do often!)
```bash
git add .
git commit -m "Describe what changed"
```

## 📚 View history
```bash
git log
```

## 🧭 Create a new branch to try something
```bash
git checkout -b new-feature-name
```

## 🔁 Switch back to main working version
```bash
git checkout main
```

## 🚨 Undo local changes (CAUTION!)
```bash
git restore <filename>
```

## ⏪ Roll back to a previous version
```bash
git checkout HEAD~1       # Go back 1 version
```

> 💡 Use `HEAD~2` for 2 versions ago, and so on

## 📄 Check current branch & status
```bash
git status
git branch
```