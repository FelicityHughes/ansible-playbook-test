ARG BASE_IMAGE=alpine:latest
FROM $BASE_IMAGE

RUN apk add curl openssh-client python py-boto py-dateutil py-httplib2 \
                py-jinja2 py-paramiko py-pip py-setuptools py-yaml tar && \
    pip install --upgrade pip && rm -rf /var/cache/apk/*

RUN mkdir -p /etc/ansible/ /ansible/playbook
COPY hosts /etc/ansible

RUN pip install ansible && \
    rm -fr ansible.tar.gz /ansible/docs /ansible/examples /ansible/packaging

COPY Entrypoint.sh /usr/local/bin
RUN chmod u+x /usr/local/bin/Entrypoint.sh

WORKDIR /ansible/playbook

ENTRYPOINT ["Entrypoint.sh"]
CMD ["/bin/sh"]
