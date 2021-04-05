#!/bin/bash
#
# httpipe-ctn
# A building block for container based pipelines

set -o nounset
set -o errexit
set -o pipefail
shopt -s expand_aliases

#-----------------------#
# DEFAULT FLAGS SECTION #
#-----------------------#

declare HTTPIPE_DRY_RUN="${HTTPIPE_DRY_RUN:-}"

#-------------------------------#
# DEFAULT CONFIGURATION SECTION #
#-------------------------------#

##
# Network ports used for data transfers
declare -ri HTTPIPE_INPUT_PORT="${HTTPIPE_INPUT_PORT:=8080}"
declare -ri HTTPIPE_OUTPUT_PORT="${HTTPIPE_OUTPUT_PORT:=8081}"

##
# Staging paths for data to be transferred along the pipeline
# ${HTTPIPE_INPUT_DIR} contains data received from the previous node
# ${HTTPIPE_OUTPUT_DIR} contains data to be transferred to the next node
#
declare -r HTTPIPE_INPUT_DIR="${HTTPIPE_INPUT_DIR:=${XDG_RUNTIME_DIR}/httpipe/in}"
declare -r HTTPIPE_OUTPUT_DIR="${HTTPIPR_OUTPUT_DIR:=${XDG_RUNTIME_DIR}/httpipe/out}"

##
# Paths of the "data packs"
# "Data packs" are file archives packing data found in the input/output
# directories, and are the canon transfer unit in the context of httpipe.
# They are trasparently created, unpacked and deleted before/after
# each transfer, as appropriate.
#
declare -r HTTPIPE_OUTPUT_PACK="${HTTPIPE_OUTPUT_DIR}/pack.httpipe.tar"
declare -r HTTPIPE_INPUT_PACK="${HTTPIPE_INPUT_DIR}/pack.httpipe.tar"

##
# The data processor application
# This application should implement the business logic of the node.
# It gets exposed the ${HTTPIPE_INPUT_DIR} and ${HTTPIPE_OUTPUT_DIR} environment
# variables
#
declare -r HTTPIPE_PROCESSOR="${HTTPIPE_PROCESSOR:=./processor.sh}"

#------------------------------#
# FUNCTION DEFINITIONS SECTION #
#------------------------------#

function echop
{
	declare strbuf=""

	for p in ${ECHO_PREFIXES:-} ; do
		strbuf="${strbuf}[$p]"
	done

	strbuf="${strbuf} $*"
	command echo "$strbuf"
}

alias echo='echop'

## Echo the arguments as an error message, then exit 1
function error
{
	ECHO_PREFIXES="HTTPIPE ERROR" echop "$@" >&2
	exit 1
}

## Echo the arguments as a warning
function warn
{
	ECHO_PREFIXES="HTTPIPE WARN" echop "$@" >&2
}

##
# Display an error message with a variable and it's value and exit
#
# @param 1 variable name
#
function throwConfigError
{
	# shellcheck disable=2155
	declare value="$( unalias echo ; eval echo "\$$1" )"
	error "Invalid $1 = '$value'"
}

function web-pull
{
	: # TODO
}

function web-recv
{
	: # TODO
	# nc -lp ${HTTPIPE_INPUT_PORT} |\
	# curl -o "${HTTPIPE_INPUT_DIR}" --abstract-unix-socket /dev/stdin
}

function web-push
{
	: # TODO
}

function web-serve
{
	: # TODO
	# curl -F "data=@${HTTPIPE_OUTPUT_FILE}" --abstract-unix-socket /dev/stdout |\
	# nc -lp ${HTTPIPE_OUTPUT_PORT}
}

function pack-data
{
	: # TODO
}

function unpack-data
{
	: # TODO
}

function warnIoFlagsOverwrite
{
	if [ -n "${HTTPIPE_IOFLAGS:-}" ] ; then
		warn "HTTPIPE_MODE != 'custom', ignoring HTTPIPE_IOFLAGS"
	fi
}

#------------------------#
# INITIALIZATION SECTION #
#------------------------#

ECHO_PREFIXES='HTTPIPE'

if [ -n "${HTTPIPE_DRY_RUN}" ] ; then
	warn "Starting in DRY RUN mode"
fi

if [ -z "${HTTPIPE_MODE:-}" ] && [ -z "${HTTPIPE_IOFLAGS:-}" ] ; then
	HTTPIPE_MODE=pulling
	warn "HTTPIPE_MODE not set, defaulting to 'pulling' mode"
fi

declare -r HTTPIPE_MODE

echo "Using HTTPIPE_MODE = '${HTTPIPE_MODE}'"

# Derive internal value of HTTPIPE_IOFLAGS from HTTPIPE_MODE
case "${HTTPIPE_MODE}" in

	"pulling")
	warnIoFlagsOverwrite
	HTTPIPE_IOFLAGS=( pull serve )
	;;

	"pushing")
	warnIoFlagsOverwrite
	HTTPIPE_IOFLAGS=( recv push )
	;;

	"custom")

	if [ -z "${HTTPIPE_IOFLAGS:-}" ] ; then
		error "When HTTPIPE_MODE = 'custom', HTTPIPE_IOFLAGS must be set"
	fi

	# NOTE 1:
	# Linux process environment doesn't support arrays
	# so a conversion is needed
	#
	# NOTE 2:
	# Disabling SC2128 is fine because at this point HTTPIPE_IOFLAGS
	# still comes from the environment
	#
	# shellcheck disable=2128
	IFS="," read -ra HTTPIPE_IOFLAGS <<< "${HTTPIPE_IOFLAGS}"

	;;

	*) throwConfigError HTTPIPE_MODE ;;

esac

declare -r HTTPIPE_IOFLAGS

mkdir -p "$HTTPIPE_INPUT_DIR" "$HTTPIPE_OUTPUT_DIR"

#--------------------------#
# DATA ACQUISITION SECTION #
#--------------------------#

ECHO_PREFIXES='HTTPIPE INPUT'

# Launch data input process
echo "Setting input mode to '${HTTPIPE_IOFLAGS[0]}'"
case ${HTTPIPE_IOFLAGS[0]} in

	"pull")
	# TODO: Add data source indication
	echo Pulling data from ...
	web-pull
	;;

	"recv")
	echo "Waiting for data on socket at URI: http://0.0.0.0:${HTTPIPE_INPUT_PORT}"
	web-recv
	;;

	*)
	# NOTE: Curly braces are needed to get the error message right
	throwConfigError "{HTTPIPE_IOFLAGS[0]}"
	;;

esac

unpack-data

echo "Data downloaded"

#-------------------------#
# DATA PROCESSING SECTION #
#-------------------------#

ECHO_PREFIXES='HTTPIPE PROC'

echo "Running data processor"

export HTTPIPE_INPUT_DIR HTTPIPE_OUTPUT_DIR

declare -i processorExitCode=0
${HTTPIPE_PROCESSOR} || processorExitCode=$?

if [ $processorExitCode -gt 0 ] ; then
	error "Data processor exited with code $processorExitCode"
fi

#---------------------#
# DATA OUTPUT SECTION #
#---------------------#

ECHO_PREFIXES='HTTPIPE OUTPUT'

# Begin data output process
echo "Setting output mode to '${HTTPIPE_IOFLAGS[1]}'"

pack-data

case ${HTTPIPE_IOFLAGS[1]} in

	"push")
	echo "Pushing data to ..."
	web-push
	;;

	"serve")

	echo "Serving data on socket at URI: http://0.0.0.0:${HTTPIPE_OUTPUT_PORT}"
	web-serve
	;;

	*)
	throwConfigError "HTTPIPE_IOFLAGS[1]"
	;;

esac

echo "Data uploaded"

#-----------------#
# CLEANUP SECTION #
#-----------------#

ECHO_PREFIXES="HTTPIPE"

echo Operations concluded on this node. Bye !
