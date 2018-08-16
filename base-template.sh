#!/bin/sh
# Base Git hook template from https://github.com/rycus86/githooks
#
# It allows you to have a .githooks folder per-project that contains
# its hooks to execute on various Git triggers.
#
# Version: 1808.161837-66b427

#####################################################
# Execute the current hook,
#   that in turn executes the hooks in the repo
#
# Returns:
#   0 when successfully finished, 1 otherwise
#####################################################
process_git_hook() {
    are_githooks_disabled && return 0
    set_main_variables
    check_for_updates_if_needed
    execute_old_hook_if_available "$@" || return 1
    execute_global_shared_hooks "$@" || return 1
    execute_local_shared_hooks "$@" || return 1
    execute_all_hooks_in "$(pwd)/.githooks" "$@" || return 1
}

#####################################################
# Checks if Githooks is completely disabled
#   for the current repository or globally.
#   This can be done with Git config or using
#   the ${GITHOOKS_DISABLE} environment variable.
#
# Returns:
#   0 when disabled, 1 otherwise
#####################################################
are_githooks_disabled() {
    [ -n "$GITHOOKS_DISABLE" ] && return 0

    GITHOOKS_CONFIG_DISABLE=$(git config --get githooks.disable)
    if [ "$GITHOOKS_CONFIG_DISABLE" = "y" ] || [ "$GITHOOKS_CONFIG_DISABLE" = "Y" ]; then
        return 0
    fi

    return 1
}

#####################################################
# Set up the main variables that
#   we will throughout the hook.
#
# Sets ${HOOK_NAME}
# Sets ${HOOK_FOLDER}
# Resets ${ACCEPT_CHANGES}
#
# Returns:
#   None
#####################################################
set_main_variables() {
    HOOK_NAME=$(basename "$0")
    HOOK_FOLDER=$(dirname "$0")
    ACCEPT_CHANGES=
}

#####################################################
# Executes the old hook if we moved one
#   while installing our hooks.
#
# Returns:
#   1 if the old hook failed, 0 otherwise
#####################################################
execute_old_hook_if_available() {
    if [ -x "${HOOK_FOLDER}/${HOOK_NAME}.replaced.githook" ]; then
        ABSOLUTE_FOLDER=$(cd "${HOOK_FOLDER}" && pwd)
        execute_hook "${ABSOLUTE_FOLDER}/${HOOK_NAME}.replaced.githook" "$@" || return 1
    fi
}

#####################################################
# Check if we have shared hooks set up globally,
#   and execute all of them if we do.
#
# Returns:
#   1 if the hooks fail, 0 otherwise
#####################################################
execute_global_shared_hooks() {
    SHARED_HOOKS=$(git config --global --get githooks.shared)

    if [ -n "$SHARED_HOOKS" ]; then
        process_shared_hooks "$SHARED_HOOKS" "$HOOK_NAME" "$@" || return 1
    fi
}

#####################################################
# Check if we have shared hooks set up
#   within the current repository,
#   and execute all of them if we do.
#
# Returns:
#   1 if the hooks fail, 0 otherwise
#####################################################
execute_local_shared_hooks() {
    if [ -f "$(pwd)/.githooks/.shared" ]; then
        SHARED_HOOKS=$(grep -E "^[^#].+$" <"$(pwd)/.githooks/.shared")
        process_shared_hooks "$SHARED_HOOKS" "$HOOK_NAME" "$@" || return 1
    fi
}

#####################################################
# Executes all hook files or scripts in the
#   directory passed in on the first argument.
#
# Returns:
#   1 if the hooks fail, 0 otherwise
#####################################################
execute_all_hooks_in() {
    PARENT="$1"
    shift

    # Execute all hooks in a directory, or a file named as the hook
    if [ -d "${PARENT}/${HOOK_NAME}" ]; then
        for HOOK_FILE in "${PARENT}/${HOOK_NAME}"/*; do
            execute_hook "$HOOK_FILE" "$@" || return 1
        done

    elif [ -f "${PARENT}/${HOOK_NAME}" ]; then
        execute_hook "${PARENT}/${HOOK_NAME}" "$@" || return 1

    fi
}

#####################################################
# Executes a single hook file or script
#   at the path passed in on the first argument.
#
# Returns:
#   0 if the hook is ignored,
#     otherwise the exit code of the hook
#####################################################
execute_hook() {
    HOOK_PATH="$1"
    shift

    # stop if the file does not exist
    [ -f "$HOOK_PATH" ] || return 0

    # stop if the file is ignored
    is_file_ignored && return 0

    check_and_execute_hook "$@"
    return $?
}

#####################################################
# Checks if the hook file at ${HOOK_PATH}
#   is ignored and should not be executed.
#
# Returns:
#   0 if ignored, 1 otherwise
#####################################################
is_file_ignored() {
    HOOK_FILENAME=$(basename "$HOOK_PATH")
    IS_IGNORED=""

    # If there are .ignore files, read the list of patterns to exclude.
    ALL_IGNORE_FILE=$(mktemp)
    if [ -f ".githooks/.ignore" ]; then
        cat ".githooks/.ignore" >"$ALL_IGNORE_FILE"
        echo >>"$ALL_IGNORE_FILE"
    fi
    if [ -f ".githooks/${HOOK_NAME}/.ignore" ]; then
        cat ".githooks/${HOOK_NAME}/.ignore" >>"$ALL_IGNORE_FILE"
        echo >>"$ALL_IGNORE_FILE"
    fi

    # Check if the filename matches any of the ignored patterns
    while IFS= read -r IGNORED; do
        if [ -z "$IGNORED" ] || [ "$IGNORED" != "${IGNORED#\#}" ]; then
            continue
        fi

        if [ -z "${HOOK_FILENAME##$IGNORED}" ]; then
            IS_IGNORED="y"
            break
        fi
    done <"$ALL_IGNORE_FILE"

    # Remove the temporary file
    rm -f "$ALL_IGNORE_FILE"

    if [ -n "$IS_IGNORED" ]; then
        return 0
    else
        return 1
    fi
}

check_and_execute_hook() {
    TRUSTED_REPO=

    if [ -f ".githooks/trust-all" ]; then
        TRUST_ALL_CONFIG=$(git config --local --get githooks.trust.all)
        TRUST_ALL_RESULT=$?

        # shellcheck disable=SC2181
        if [ $TRUST_ALL_RESULT -ne 0 ]; then
            echo "! This repository wants you to trust all current and future hooks without prompting"
            printf "  Do you want to allow running every current and future hooks? [y/N] "
            read -r TRUST_ALL_HOOKS </dev/tty

            if [ "$TRUST_ALL_HOOKS" = "y" ] || [ "$TRUST_ALL_HOOKS" = "Y" ]; then
                git config githooks.trust.all Y
                TRUSTED_REPO="Y"
            else
                git config githooks.trust.all N
            fi
        elif [ $TRUST_ALL_RESULT -eq 0 ] && [ "$TRUST_ALL_CONFIG" = "Y" ]; then
            TRUSTED_REPO="Y"
        fi
    fi

    if [ "$TRUSTED_REPO" != "Y" ]; then
        # get hash of the hook contents
        if ! MD5_HASH=$(md5 -r "$HOOK_PATH" 2>/dev/null); then
            MD5_HASH=$(md5sum "$HOOK_PATH" 2>/dev/null)
        fi
        MD5_HASH=$(echo "$MD5_HASH" | awk "{ print \$1 }")
        CURRENT_HASHES=$(grep "$HOOK_PATH" .git/.githooks.checksum 2>/dev/null)
        # check against the previous hash
        if ! echo "$CURRENT_HASHES" | grep -q "$MD5_HASH $HOOK_PATH" >/dev/null 2>&1; then
            if [ -z "$CURRENT_HASHES" ]; then
                MESSAGE="New hook file found"
            elif echo "$CURRENT_HASHES" | grep -q "disabled> $HOOK_PATH" >/dev/null 2>&1; then
                echo "* Skipping disabled $HOOK_PATH"
                echo "  Edit or delete the $(pwd)/.git/.githooks.checksum file to enable it again"
                return 0
            else
                MESSAGE="Hook file changed"
            fi

            echo "? $MESSAGE: $HOOK_PATH"

            if [ "$ACCEPT_CHANGES" = "a" ] || [ "$ACCEPT_CHANGES" = "A" ]; then
                echo "  Already accepted"
            else
                printf "  Do you you accept the changes? (Yes, all, no, disable) [Y/a/n/d] "
                read -r ACCEPT_CHANGES </dev/tty

                if [ "$ACCEPT_CHANGES" = "n" ] || [ "$ACCEPT_CHANGES" = "N" ]; then
                    echo "* Not running $HOOK_FILE"
                    return 0
                fi

                if [ "$ACCEPT_CHANGES" = "d" ] || [ "$ACCEPT_CHANGES" = "D" ]; then
                    echo "* Disabled $HOOK_PATH"
                    echo "  Edit or delete the $(pwd)/.git/.githooks.checksum file to enable it again"

                    echo "disabled> $HOOK_PATH" >>.git/.githooks.checksum
                    return 0
                fi
            fi

            # save the new accepted checksum
            echo "$MD5_HASH $HOOK_PATH" >>.git/.githooks.checksum
        fi
    fi

    if [ -x "$HOOK_PATH" ]; then
        # Run as an executable file
        "$HOOK_PATH" "$@"
        return $?

    elif [ -f "$HOOK_PATH" ]; then
        # Run as a Shell script
        sh "$HOOK_PATH" "$@"
        return $?

    fi

    return 0
}

process_shared_hooks() {
    SHARED_REPOS_LIST="$1"
    shift
    HOOK_NAME="$1"
    shift

    # run an init/update if we are after a "git pull" or triggered manually
    if [ "$HOOK_NAME" = "post-merge" ] || [ "$HOOK_NAME" = ".githooks.shared.trigger" ]; then
        # split on comma and newline
        IFS=",
        "

        for SHARED_REPO in $SHARED_REPOS_LIST; do
            mkdir -p ~/.githooks.shared

            NORMALIZED_NAME=$(echo "$SHARED_REPO" |
                sed -E "s#.*[:/](.+/.+)\\.git#\\1#" |
                sed -E "s/[^a-zA-Z0-9]/_/g")

            if [ -d ~/.githooks.shared/"$NORMALIZED_NAME"/.git ]; then
                echo "* Updating shared hooks from: $SHARED_REPO"
                PULL_OUTPUT=$(cd ~/.githooks.shared/"$NORMALIZED_NAME" && git pull 2>&1)
                # shellcheck disable=SC2181
                if [ $? -ne 0 ]; then
                    echo "! Update failed, git pull output:"
                    echo "$PULL_OUTPUT"
                fi
            else
                echo "* Retrieving shared hooks from: $SHARED_REPO"
                CLONE_OUTPUT=$(cd ~/.githooks.shared && git clone "$SHARED_REPO" "$NORMALIZED_NAME" 2>&1)
                # shellcheck disable=SC2181
                if [ $? -ne 0 ]; then
                    echo "! Clone failed, git clone output:"
                    echo "$CLONE_OUTPUT"
                fi
            fi
        done

        unset IFS
    fi

    for SHARED_ROOT in ~/.githooks.shared/*; do
        REMOTE_URL=$(cd "$SHARED_ROOT" && git config --get remote.origin.url)
        ACTIVE_REPO=$(echo "$SHARED_REPOS_LIST" | grep -o "$REMOTE_URL")
        if [ "$ACTIVE_REPO" != "$REMOTE_URL" ]; then
            continue
        fi

        if [ -d "${SHARED_ROOT}/.githooks" ]; then
            execute_all_hooks_in "${SHARED_ROOT}/.githooks" "$@" || return 1
        elif [ -d "$SHARED_ROOT" ]; then
            execute_all_hooks_in "$SHARED_ROOT" "$@" || return 1
        fi
    done

    return 0
}

check_for_updates_if_needed() {
    [ "$HOOK_NAME" != "post-commit" ] && return

    UPDATES_ENABLED=$(git config --get githooks.autoupdate.enabled)
    [ "$UPDATES_ENABLED" != "Y" ] && return

    LAST_UPDATE=$(git config --global --get githooks.autoupdate.lastrun)
    if [ -z "$LAST_UPDATE" ]; then
        LAST_UPDATE=0
    fi

    CURRENT_TIME=$(date +%s)
    ELAPSED_TIME=$((CURRENT_TIME - LAST_UPDATE))
    ONE_DAY=86400

    if [ $ELAPSED_TIME -lt $ONE_DAY ]; then
        return # it is not time to update yet
    fi

    git config --global githooks.autoupdate.lastrun "$(date +%s)"

    DOWNLOAD_URL="https://raw.githubusercontent.com/rycus86/githooks/master/install.sh"

    echo "^ Checking for updates ..."

    if curl --version >/dev/null 2>&1; then
        INSTALL_SCRIPT=$(curl -fsSL "$DOWNLOAD_URL" 2>/dev/null)

    elif wget --version >/dev/null 2>&1; then
        INSTALL_SCRIPT=$(wget -O- "$DOWNLOAD_URL" 2>/dev/null)

    else
        echo "! Cannot check for updates - needs either curl or wget"
        return
    fi

    # shellcheck disable=SC2181
    if [ $? -ne 0 ]; then
        echo "! Failed to check for updates"
        return
    fi

    CURRENT_VERSION=$(grep "^# Version: .*" "$0" | sed "s/^# Version: //")
    LATEST_VERSION=$(echo "$INSTALL_SCRIPT" | grep "^# Version: .*" | sed "s/^# Version: //")

    UPDATE_AVAILABLE=$(echo "$CURRENT_VERSION $LATEST_VERSION" | awk "{ print (\$1 >= \$2) }")
    if [ "$UPDATE_AVAILABLE" = "0" ]; then
        echo "* There is a new Githooks update available: Version $LATEST_VERSION"
        printf "    Would you like to install it now? [Y/n] "
        read -r EXECUTE_UPDATE </dev/tty

        if [ -z "$EXECUTE_UPDATE" ] || [ "$EXECUTE_UPDATE" = "y" ] || [ "$EXECUTE_UPDATE" = "Y" ]; then
            IS_SINGLE_REPO=$(git config --get --local githooks.single.install)

            if [ "$IS_SINGLE_REPO" = "yes" ]; then
                if sh -c "$INSTALL_SCRIPT" -- --single; then
                    return
                fi
            else
                if sh -c "$INSTALL_SCRIPT"; then
                    return
                fi
            fi
        fi

        if [ "$IS_SINGLE_REPO" != "yes" ]; then
            GLOBAL_CONFIG="--global"
        fi

        echo "  If you would like to disable auto-updates, run:"
        echo "    \$ git config ${GLOBAL_CONFIG} githooks.autoupdate.enabled N"
    fi
}

process_git_hook "$@" || exit 1
