# Githooks

This project uses [Githooks](https://github.com/rycus86/githooks), that allows running [Git hooks](https://git-scm.com/docs/githooks) checked into this repository. This folder contains hooks that should be executed by everyone who interacts with this source repository. For a documentation on how this works and how to get it [installed](https://github.com/rycus86/githooks#installation), check the project [README](https://github.com/rycus86/githooks/blob/master/README.md) in the [rycus86/githooks](https://github.com/rycus86/githooks) GitHub repository.

## Brief summary

The [directories or files](https://github.com/rycus86/githooks#layout-and-options) in this folder tell Git to execute certain scripts on various [trigger events](https://github.com/rycus86/githooks#supported-hooks), before or after a commit, on every checkout, before a push for example - assuming [Githooks](https://github.com/rycus86/githooks) is already [installed](https://github.com/rycus86/githooks#installation) and [enabled](https://github.com/rycus86/githooks#opt-in-hooks) for the repository. The directory or file names refer to these events, like `pre-commit`, `post-commit`, `post-checkout`, `pre-push`, etc. If they are folders, each file inside them is treated as a hook script (unless [ignored](https://github.com/rycus86/githooks#ignoring-files)), and will be executed when Git runs the hooks as part of the command issued by the user.

### Is this safe?

[Githooks](https://github.com/rycus86/githooks) uses an [opt-in model](https://github.com/rycus86/githooks#opt-in-hooks), where it will ask for confirmation whether new or changed scripts should be run or not (or disabled).

### How do I add a new hook script?

Either create a file with the [Git hook](https://github.com/rycus86/githooks#supported-hooks) name, or a directory (recommended) inside the `.githooks` folder, and place files with the individual steps that should be executed for that event inside. If the file is executable, it will be invoked directly, otherwise it is assumed to be a Shell script - unless this file matches one of the [ignore patterns](https://github.com/rycus86/githooks#ignoring-files) in the `.githooks` area.

## More information

You can find more information about how this all works in the [README](https://github.com/rycus86/githooks/blob/master/README.md) of the [Githooks](https://github.com/rycus86/githooks) project repository.

If you find it useful, please show your support by starring the project in GitHub!