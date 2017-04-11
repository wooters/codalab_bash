#!/usr/bin/env bash

# Use a dot-file to associate the current dir
# with a specific codalab worksheet
CL_LOCAL_WS_INFO_FILE=".cl_worksheet"

# The location of the codalab state file
__CL_STATE_FILE="${HOME}/.codalab/state.json"

# A regex for parsing the worksheet name and uuid
__CL_WS_REGEX=".+:[0-9]+::(.+)\((0x[a-f0-9]+)\)"

function CL_LOGGED_IN {
    # returns success (0) if user is logged in, failure (1) if not
    if [[ -f ${__CL_STATE_FILE} ]]; then
        if ! res=$(python -c "import sys, json; print(len(json.load(sys.stdin)['auth']))" < "${__CL_STATE_FILE}"); then
            return $?
        fi
        if [[ $res == "0" ]]; then
            return 1
        fi
        return 0
    fi
    return 1
}

function CL_STATE_CURRENT_WS_UUID {
    # Get current worksheet according to the state.json file
    python -c "import sys, json; print(json.load(sys.stdin)['sessions']['top']['worksheet_uuid'])" < "${__CL_STATE_FILE}"
}

function __CL_PARSE_WS_UUID {
    # gets the UUID of the passed in worksheet
    local out=""
    if [[ $1 =~ $__CL_WS_REGEX ]]; then
        out="${BASH_REMATCH[2]}"
    fi
    echo "$out"
}

function __CL_PARSE_WS_NAME {
    # gets the name of the passed in worksheet
    local out=""
    if [[ $1 =~ $__CL_WS_REGEX ]]; then
        out="${BASH_REMATCH[1]}"
    fi
    echo "$out"
}

function CL_GET_LOCAL_WS_UUID {
    __CL_PARSE_WS_UUID "$(cat $CL_LOCAL_WS_INFO_FILE)"
}

function CL_GET_LOCAL_WS_NAME {
    __CL_PARSE_WS_NAME "$(cat $CL_LOCAL_WS_INFO_FILE)"
}

function CL_AVAILABLE {
    # returns true if codalab cli available in PATH
    # and user is logged in
    which cl > /dev/null 2>&1 && CL_LOGGED_IN
}

function __RUN_CL_WORK {
    # If no arg passed in, just reports current worksheet
    # Using `expect` to look for the case where the user
    # is not currently logged in
    if ! cl_work_out=$(CL_AVAILABLE && expect -c "spawn -noecho cl work $1; expect \"Username:\" {exit 1}"); then
        echo "Error running the 'cl work' command. Is the codalab cli in your PATH and are you logged in?" >&2
        echo ""
        return $?
    else
        echo "$cl_work_out"
        return 0
    fi
}


#
# Command line helper utilities
#
function cl_workhere {
    # changes the active codalab worksheet to be the same as
    # what is in the cur dir (as recorded in $CL_LOCAL_WS_INFO_FILE)
    if [[ -f $CL_LOCAL_WS_INFO_FILE ]]; then
        ws_uuid=$(CL_GET_LOCAL_WS_UUID)
        if [[ "$ws_uuid" == "" ]]; then
            echo "Couldn't parse UUID from ${CL_LOCAL_WS_INFO_FILE}" >&2
            return 1
        fi
        if ! __RUN_CL_WORK "$(CL_GET_LOCAL_WS_UUID)"; then
            return $?
        fi
    else
        echo "$CL_LOCAL_WS_INFO_FILE not found" >&2
        return 1
    fi
}

function cl_bookmark {
    # saves the currently-active worksheet info into $CL_LOCAL_WS_INFO_FILE
    if ! ws_info=$(__RUN_CL_WORK); then
        return $?
    fi
    echo "Saving worksheet info to: $CL_LOCAL_WS_INFO_FILE"
    echo "${ws_info}" > ${CL_LOCAL_WS_INFO_FILE}
    return 0
}

