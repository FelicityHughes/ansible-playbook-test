ARG BASE_IMAGE=ubuntu:latest
FROM $BASE_IMAGE

RUN apt-get update && apt-get -y upgrade && \
    apt-get install -y locales openssh-server python3-pip rsyslog sudo && \
    apt-get clean && rm -fr /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Create user - ubuntu - for ssh access and enable sudo operations
RUN groupadd -r ubuntu && useradd -rmg ubuntu ubuntu && \
    echo 'ubuntu ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers
RUN su - ubuntu -c "mkdir ~/.ssh"

# Various options to make SSH access easier when testing Ansible playbooks
RUN sed -i "s/UsePrivilegeSeparation.*/UsePrivilegeSeparation no/g" /etc/ssh/sshd_config && \
    sed -i "s/StrictModes.*/StrictModes no/g" /etc/ssh/sshd_config && \
    touch /home/ubuntu/.Xauthority && update-locale && mkdir -p /var/run/sshd

COPY Entrypoint.sh /usr/local/bin
RUN chmod u+x /usr/local/bin/Entrypoint.sh

ENTRYPOINT ["Entrypoint.sh"]
CMD ["/bin/bash"]
