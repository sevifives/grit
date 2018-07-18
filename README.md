# Grit
Grit is just a simple tool to align your multiple repositories. It's just a proxy for git commands to your main repo and your other repos.

## Get started:
```
git clone https://github.com/mlintern/grit.git ~/.grit
chmod +x ~/.grit/grit.rb
ln -s ~/.grit/grit.rb /usr/local/bin/grit
```

### Create a new project:
```
[master][~/proj]$ grit init
```

Will generate .grit/config.yml

## Sample config.yml
```
---
:root: /Users/Bono/the_world
:repositories:
  - :name: Sproutcore
    :path: frameworks/sproutcore
  - :name: SCUI
    :path: frameworks/scui
:ignore_root: false
```

### Add Repository:
```
grit add-repository new_name path/to/repo
```

### Remove Repository:
```
grit remove-repository new_name
```

### Execute Commands:
grit status

```
[master][~/proj]$ grit status
Performing operation status on Root
# On branch master
# Your branch is ahead of 'origin/master' by 1 commit.
#
nothing to commit (working directory clean)

Performing operation status on Sproutcore
# On branch master
nothing to commit (working directory clean)

Performing operation status on SCUI
# On branch master
nothing to commit (working directory clean)
```

### grit on REPO_NAME_CASE GIT_OPERATION
will perform that operation on the repo you want
```
[master][~/orion]$ grit on sproutcore st
# sproutcore$ git st
# On branch master
nothing to commit (working directory clean)
```

### and to make git ignoring easier...
```
git config --global core.excludesfile ~/.gitignore
printf ".grit/" >> ~/.gitignore
```
