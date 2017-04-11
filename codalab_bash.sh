#!/usr/bin/env bash

export HAVE_CL_BASH=1

# Use a dot-file to associate the current dir
# with a specific codalab worksheet
CL_LOCAL_WS_INFO_FILE="${CL_LOCAL_WS_INFO_FILE:-.cl_worksheet}"

# The location of the codalab state file
CL_STATE_FILE="${CL_STATE_FILE:-${HOME}/.codalab/state.json}"

# A regex for parsing the worksheet name and uuid
# from a string of the form:
#    ::name(uuid)
# as returned by the `cl work` command
__CL_WS_REGEX="::(.+)\((0x[a-f0-9]+)\)"

__CL_SUCCESS=0
__CL_FAILURE=1

function __CL_PARSE_WS_UUID {
    # gets the UUID of the passed in worksheet
    local out
    out=""
    if [[ $1 =~ $__CL_WS_REGEX ]]; then
        out="${BASH_REMATCH[2]}"
    fi
    echo "$out"
}

function __CL_PARSE_WS_NAME {
    # gets the name of the passed in worksheet
    local out
    out=""
    if [[ $1 =~ $__CL_WS_REGEX ]]; then
        out="${BASH_REMATCH[1]}"
    fi
    echo "$out"
}

function __RUN_CL_WORK {
    # If no arg passed in, just returns the current worksheet
    local cl_work_out
    if ! cl_work_out=$(CL_AVAILABLE && cl work "$1"); then
        echo "Error running the 'cl work' command. Is the codalab cli in your PATH and are you logged in?" >&2
        echo ""
        return $__CL_FAILURE
    else
        echo "${cl_work_out}"
    fi
}

function CL_LOGGED_IN {
    # returns success (0) if user is logged in, failure (1) if not
    local res
    if [[ -f "${CL_STATE_FILE}" ]]; then
        if ! res=$(python -c "import sys, json; print(len(json.load(sys.stdin)['auth']))" < "${CL_STATE_FILE}"); then
            return $?
        fi
        if [[ $res == "0" ]]; then
            return $__CL_FAILURE
        fi
        return $__CL_SUCCESS
    fi
    return $__CL_FAILURE
}

function CL_AVAILABLE {
    # returns success if codalab cli available in PATH
    # and user is logged in
    CL_LOGGED_IN && which cl > /dev/null 2>&1
}

function CL_GET_LOCAL_WS_INFO {
    if [[ -f "${CL_LOCAL_WS_INFO_FILE}" ]]; then
        cat "${CL_LOCAL_WS_INFO_FILE}"
    else
        echo ""
        return $__CL_FAILURE
    fi
}

function CL_GET_LOCAL_WS_UUID {
    local ws_info
    if ws_info=$(CL_GET_LOCAL_WS_INFO); then
        __CL_PARSE_WS_UUID "${ws_info}"
    else
        echo ""
        return $__CL_FAILURE
    fi
}

function CL_GET_LOCAL_WS_NAME {
    local ws_info
    if ws_info=$(CL_GET_LOCAL_WS_INFO); then
        __CL_PARSE_WS_NAME "${ws_info}"
    else
        echo ""
        return $__CL_FAILURE
    fi
}

function CL_GET_STATE_WS_UUID {
    # Get current worksheet UUID according to the state.json file
    if [[ -f "${CL_STATE_FILE}" ]]; then
        python -c "import sys, json; print(json.load(sys.stdin)['sessions']['top']['worksheet_uuid'])" < "${CL_STATE_FILE}"
    else
        echo ""
        return $__CL_FAILURE
    fi
}

function CL_GET_STATE_WS_SERVER {
    # Get current server according to the state.json file
    if [[ -f "${CL_STATE_FILE}" ]]; then
        python -c "import sys, json; print(json.load(sys.stdin)['sessions']['top']['address'])" < "${CL_STATE_FILE}"
    else
        echo ""
        return $__CL_FAILURE
    fi
}

function CL_WS_IS_CONSISTENT {
    # Returns success if:
    #   1. The user is logged in to codalab
    #   2. The worksheet listed in the local worksheet info file
    #      is the same as the active worksheet in the codalab
    #      state file
    local state_ws_uuid
    local local_ws_uuid
    if CL_LOGGED_IN; then
        if ! state_ws_uuid=$(CL_GET_STATE_WS_UUID); then
            return $__CL_FAILURE
        fi
        if ! local_ws_uuid=$(CL_GET_LOCAL_WS_UUID); then
            return $__CL_FAILURE
        fi
        [ "${state_ws_uuid}" == "${local_ws_uuid}" ]
    else
        return $__CL_FAILURE
    fi
}

function CL_PROMPT_INFO {
    # Returns a short string for the local worksheet
    # suitable for display in a prompt
    local ws_name
    local ws_uuid
    if [[ -f "${CL_LOCAL_WS_INFO_FILE}" ]]; then
        if ! ws_name=$(CL_GET_LOCAL_WS_NAME); then
            echo ""
            return $__CL_FAILURE
        fi
        if ! ws_uuid=$(CL_GET_LOCAL_WS_UUID); then
            echo ""
            return $__CL_FAILURE
        fi
        echo "${ws_name}(${ws_uuid:0:8})"
    else
        echo ""
        return $__CL_FAILURE
    fi
}

#
# Command line helper utilities
#

function cl_workhere {
    # changes the active codalab worksheet to be the same as
    # the one stored locally (in $CL_LOCAL_WS_INFO_FILE)
    local ws_uuid
    local ws_info
    if [[ -f "${CL_LOCAL_WS_INFO_FILE}" ]]; then
        if CL_WS_IS_CONSISTENT; then
            return $__CL_SUCCESS
        fi
        if ! ws_uuid=$(CL_GET_LOCAL_WS_UUID); then
            echo "Couldn't get worksheet UUID from ${CL_LOCAL_WS_INFO_FILE}" >&2
            return $__CL_FAILURE
        fi
        if ! ws_info=$(__RUN_CL_WORK "${ws_uuid}"); then
            return $__CL_FAILURE
        fi
        # save it locally so that we have the worksheet name
        # and not just the uuid
        echo "${ws_info}" > "${CL_LOCAL_WS_INFO_FILE}"
    else
        echo "$CL_LOCAL_WS_INFO_FILE file not found." >&2
        echo "run 'cl_bookmark' to record the current worksheet in this dir" >&2
        return $__CL_FAILURE
    fi
}

function cl_bookmark {
    # saves the currently-active worksheet info into $CL_LOCAL_WS_INFO_FILE
    local ws_info
    if ! ws_info=$(__RUN_CL_WORK); then
        return $__CL_FAILURE
    fi
    echo "Saving active worksheet info to: $CL_LOCAL_WS_INFO_FILE"
    echo "${ws_info}" > "${CL_LOCAL_WS_INFO_FILE}"
}
