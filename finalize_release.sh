#!/bin/bash

set -e

source common_functions.sh

readonly PROGRAM_NAME=$(basename $0)
readonly ARGS="$@"

usage() {
	cat <<- EOF	
	usage: ${PROGRAM_NAME} <options>
	
	    -r, --repository     Github repository to update
	    -n, --name           release name
	    -t, --git-tag        Git tag for the reelase
	    -b, --git-branch	 the original Git source branch for this release, which will be deleted
	    -h, --help           print this message
	EOF
}

parse_args() {
	local arg=
	for arg in ${ARGS} 
	do
		local delim=""
		case "$arg" in
		# translate long options to short for getopts
			--repository)		args="${args}-r ";;
			--name)				args="${args}-n ";;
			--git-tag)			args="${args}-t ";;
			--git-branch)		args="${args}-b ";;
			--help)				args="${args}-h ";;
			*)	[[ "${arg:0:1}" == "-" ]] || delim="\""
					args="${args}${delim}${arg}${delim} ";;
		esac
	done

	eval set -- $args
		
	while getopts "r:n:t:b:h" OPTION
	do
		case $OPTION in
			r)
				readonly REPOSITORY=$OPTARG
				;;
			n)
				readonly NAME=$OPTARG
				;;
			t)
				readonly GIT_TAG=$OPTARG
				;;
			b)
				readonly GIT_BRANCH=$OPTARG
				;;
			h)
				usage
				exit 0
				;;
		esac
	done
	
	if [[ -z "${REPOSITORY}" ]] || [[ -z "${NAME}" ]] || [[ -z "${GIT_TAG}" ]] || [[ -z "${GIT_BRANCH}" ]]
	then
		echo "Repository, release name, Git tag, and Git branch are required" 1>&2
		usage
		exit 1
	fi
}

main() {
	parse_args

	local readonly workspace="finalize_release_workspace"
	local readonly github_base='git+ssh://git@github.com'
	local readonly github_api_base='https://api.github.com'

	local git_exec=
	find_git_exec git_exec

	local github_api_token=
	get_github_api_token github_api_token

	enter_workspace workspace

	echo "** Cloning ${REPOSITORY}..."
	${git_exec} clone "${github_base}/${REPOSITORY}" repo
	cd repo
	echo "** Done"

	echo ""
	echo "** Merging ${GIT_TAG} to develop..."
	${git_exec} checkout develop
	${git_exec} merge --no-edit ${GIT_TAG}
	${git_exec} push origin develop:develop
	echo "** Done"

	echo ""
	echo "** Merging ${GIT_TAG} to master..."
	${git_exec} checkout master
	${git_exec} merge -m "Merging branch ${GIT_BRANCH} to master (tag: ${GIT_TAG})" "${GIT_TAG}"
	${git_exec} push origin master:master
	${git_exec} tag -a ${NAME} -m "deploy ${NAME} to prod"
	${git_exec} push origin ${NAME}
	echo "** Done"

	echo ""
	echo "** Deleting ${GIT_BRANCH}..."
	${git_exec} push origin --delete ${GIT_BRANCH}
	echo "** Done"

	echo ""
	echo "** Create Github release..."
	local readonly release_url="${github_api_base}/repos/${REPOSITORY}/releases"
	local readonly release_json=$(cat <<- EOF
	{
	    "tag_name":"${NAME}",
	    "name":"Collaterate Production Release ${NAME}"
	}
	EOF
	)
	
	local readonly response=$( curl -qSsw '\n%{http_code}' -u ":${github_api_token}" -X POST "${release_url}" -d "${release_json}" ) 2>/dev/null
	local readonly response_status=$(echo "${response}" | tail -n1)
	if [[ "201" != "${response_status}" ]]
	then
		echo "Release was not created. API response HTTP status: ${response_status}" 1>&2
		echo "${response}" 1>&2
		exit 1
	else
		echo "Release ${NAME} created"
	fi
	
	echo "** Done"

	leave_workspace workspace

	exit 0
}

main