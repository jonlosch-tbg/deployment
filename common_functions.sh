# Functions that can be used by several deployment scripts.
#
# Note: for functions that need to return a value, the value is written to the first
# argument passed in. By convention, these functions use variables prefixed with "__"
# to avoid colliding with the return variable name.

find_git_exec() {
	local __resultvar=$1

	local __default_git_exec="$(which git)"
	local __git_exec=${GIT_EXEC:-${__default_git_exec}}
	
	if [[ -z "${__git_exec}" ]]
	then
		echo "No git executable found. Please specify a valid path to git using the GIT_EXEC environment variable." 1>&2
		exit 1
	fi
	
	printf -v "$__resultvar" '%s' "${__git_exec}"
}

cleanup_workspace() {
	local readonly workspace=$1
	if [[ -d "${workspace}" ]]
	then
		rm -fr "${workspace}"
	fi	
}

enter_workspace() {
	local readonly workspace=$1
	cleanup_workspace workspace
	mkdir "${workspace}"
	pushd "${workspace}" 2>&1 > /dev/null
}

leave_workspace() {
	local readonly workspace=$1
	popd 2>&1 > /dev/null
	cleanup_workspace workspace
}

get_github_api_token() {
	local __resultvar=$1
	
	local readonly __token_file=${GITHUB_API_TOKEN_FILE:-~/".ssh/github_api_token"}
	local readonly __token=$(<"${__token_file}")
	
	if [[ -z "${__token}" ]]
	then
		echo "Git token file not found. Please specify a valid file path using the GITHUB_API_TOKEN_FILE environment variable." 1>&2
		exit 1
	fi
	
	printf -v "$__resultvar" '%s' "${__token}"
}
