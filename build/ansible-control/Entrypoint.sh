#!/bin/sh

ansible-playbook -i inventory "${ANSIBLE_PLAYBOOK}"

exec "${@}"
