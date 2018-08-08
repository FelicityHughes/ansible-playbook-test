#!/bin/sh

export PATH=${ANSIBLE_PATH}:${PATH}
ansible-playbook -i inventory "${ANSIBLE_PLAYBOOK}"

exec "${@}"
