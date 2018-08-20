#!/usr/bin/env bash


################################################################################
# This script tests the validity of an Ansible playbook by running it across
# two Docker containers.  The playbook is run from a 'control' container and
# pointed at a 'target' container.
#
# The directory of the playbook is specified on the command line (-d) and it is
# copied to the build directory, where it is mounted as a volume into the
# Ansible control container.
#
# If the environment or arguments to Docker need to change substantially,
# use the -b flag to bring the containers down and rebuild them.  This flag
# takes precedence over the -c flag.
#
# The -c (copy playbook) flag is useful when you only wish to change the Ansible
# playbook.  It will bring the containers down and restart them with the changes
# mounted in a fresh volume.  NEVER change the playbook in the build directory -
# always change the playbook source so changes are not lost on a container
# restart.
################################################################################


# Include error handling functionality.
. ./ErrorHandling.sh


################################################################################
# File and command info.
################################################################################
readonly USAGE="${0} -d <playbook_dir> [-b(uild)] [-c(opy playbook)]"


################################################################################
# Exit states.
################################################################################
readonly BAD_ARGUMENT_ERROR=90
readonly MISSING_DIR_ERROR=91
readonly COPY_ERROR=92


################################################################################
# Command line switch environment variables.
################################################################################
COPY_PLAYBOOK="${FALSE}"
PLAYBOOK_DIR=""
REBUILD="${FALSE}"


################################################################################
# Checks command line arguments are valid and have valid arguments.
#
# @param $@ All arguments passed on the command line.
################################################################################
check_args() {
  local dir_specified="${FALSE}"
  local file_specified="${FALSE}"

  while [[ ${#} -gt 0 ]]; do
    case "${1}" in
      -b)
        if ! [[ "${2}" =~ ^-[bcd]$ ]] && [[ ${#} -gt 1 ]]; then
          exit_with_error "${BAD_ARGUMENT_ERROR}" \
                          "Option ${1} does not require an argument.  Usage:  ${USAGE}"
        else
          REBUILD="${TRUE}"
        fi
        ;;
      -c)
        if ! [[ "${2}" =~ ^-[bcd]$ ]] && [[ ${#} -gt 1 ]]; then
          exit_with_error "${BAD_ARGUMENT_ERROR}" \
                          "Option ${1} does not require an argument.  Usage:  ${USAGE}"
        else
          COPY_PLAYBOOK="${TRUE}"
        fi
        ;;
      -d)
        while ! [[ "${2}" =~ ^-[bcd]$ ]] && [[ ${#} -gt 1 ]]; do
          PLAYBOOK_DIR="${2}"
          shift
        done

        if [[ ${PLAYBOOK_DIR} == "" ]]; then
          exit_with_error "${BAD_ARGUMENT_ERROR}" \
                          "Option ${1} requires an argument.  Usage:  ${USAGE}"
        else
          dir_specified="${TRUE}"
        fi
        ;;
      *)
        exit_with_error "${BAD_ARGUMENT_ERROR}" \
                        "Invalid option: ${1}.  Usage:  ${USAGE}"
        ;;
    esac
    shift
  done

  if ((dir_specified == FALSE)); then
    exit_with_error "${MISSING_DIR_ERROR}" \
                    "No directory specified!  Usage:  ${USAGE}"
  fi
}


################################################################################
# Retrieves the playbook directory required for the build and copies it to the
# ansible-control directory.
#################################################################################
get_playbook_dir() {
  local file_increment=0
  local new_inventory_name="inventory"
  local return_val="${SUCCESS}"

  # Make sure we only have playbook directory relevant for this script run.
  remove_copied_playbook

  cp -r "${PLAYBOOK_DIR}" "${PLAYBOOK_COPY}"
  return_val="${?}"
  if ((return_val != SUCCESS)); then
    exit_with_error ${COPY_ERROR} \
                    "Could not copy playbook directory *${PLAYBOOK_DIR}*!"
  fi

  # Copy over our inventory hack, ensuring we preserve any pre-existing one.
  if [[ -e "${PLAYBOOK_COPY}/inventory" ]]; then
    new_inventory_name="inventory.orig"

    while [[ -e "${PLAYBOOK_COPY}/${new_inventory_name}" ]]; do
      new_inventory_name="inventory.orig.${file_increment}"
    done

    mv "${PLAYBOOK_COPY}/inventory" "${PLAYBOOK_COPY}/${new_inventory_name}"
  fi

  cp "${CONTROL_DIR}/inventory" "${PLAYBOOK_COPY}"
  return_val="${?}"
  if ((return_val != SUCCESS)); then
    exit_with_error ${COPY_ERROR} \
                    "Could not copy inventory file to *${PLAYBOOK_COPY}*!"
  fi

  cd "${WORKING_DIR}" || \
     exit_with_error ${MISSING_DIR_ERROR} \
                     "Could not change to ${WORKING_DIR} dir."
}


#################################################################################
# Entry point to the program.  Valid command line options are described at the
# top of the script.
#
# @param ARGS Command line flags, including -d <playbook_dir> and the optional
#             -b (build containers) and -c (copy playbook).
#################################################################################
main() {
  ARGS=("${@}")
  check_args "${ARGS[@]}"
  get_playbook_dir

  if ((REBUILD == TRUE)); then
    remove_docker_containers "${TRUE}"
    docker-compose up --build -d
  elif ((COPY_PLAYBOOK == TRUE)); then
    remove_docker_containers "${TRUE}"
    docker-compose up -d
  else
    remove_docker_containers "${FALSE}"
    docker-compose up -d
  fi
}


################################################################################
# Set up for bomb-proof exit, then run the script
################################################################################
trap_with_signal cleanup HUP INT QUIT ABRT TERM EXIT

main "${@}"
exit ${SUCCESS}
