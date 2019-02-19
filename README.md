# Ansible Playbook Test

### Dependencies
#### External
1. [docker](https://docs.docker.com)
2. [docker-compose](https://docs.docker.com/compose/)
3. [yq](http://mikefarah.github.io/yq/)
4. Passphraseless SSH public-private key pair.  If you don't have one, you can
   generate one in macOS or Linux with the following command:
  
   ```
   ssh-keygen -t rsa
   ```
  
   Specify a filename other than the default (particularly if you already have
   an SSH keypair) and **don't** supply a passphrase when prompted.  The public
   key will have the same name as the private key with *.pub* appended.

### About
This is a small application that takes an Ansible playbook and runs it on a
Docker container.  This control node is pointed at a second Docker container,
the target node, where the results of the Ansible playbook execution can be
reviewed.

### Running the program
The following commands should be run from the project root, where
`docker-compose.yml` lives.

#### Execution
Run the program with:

```
./RunPlaybook.sh -d <ansible playbook directory> [-b]
```

...where:
 
* *-d* specifies the source playbook directory, which is copied to the build
  directory and mounted as a volume in the Ansible control container.
* *-b* (optional) specifies the containers should be brought down and rebuilt.
  This should be used when the **Docker image** (environment or arguments) needs
  to change.  **Don't** use this when testing playbook changes.*
  
<sup>
  *Playbook changes should be performed in the Ansible source directory, not 
the copy placed in this project's <code>build/ansible-control</code> directory during execution.
</sup>

#### Checking logs  
The *ansible-control* container will not display output from the playbook
execution, which usually takes a while to run.  The following command allows you
to monitor Ansible's progress:

```
docker logs ansible-control --follow
```

...use `Ctrl+C` to escape when done.

#### Inspecting containers
You can review the environment in the *ansible-target* container by logging in
to it with the following command:

```
docker exec -it ansible-target /usr/bin/env bash
```

If you wish, you can also log in to the *ansible-control* container.  Be aware
it is based on a minimal (Alpine) Linux image and so does not have a `bash`
shell:

```
docker exec -it ansible-control /bin/sh
```

Type `exit` at the prompt to get out of the container.

**Note:** If you change the container names or base images, you will need to
alter the above commands as discussed in the [Docker
configuration](#docker-configuration) section.  You should also review the
[Troubleshooting](#troubleshooting) section if your chosen Linux image does not
use Python 3 by default.

### Clean up
The containers can be shut down from the project root with:

```
docker-compose down
```

The Docker container and images from which the container is built can be removed
in one go with:

```
./Cleanup.sh
```

### Docker configuration
The following items are set in the `docker-compose.yml` file:

* `BASE_IMAGE` - The base Docker Linux image, set to `gliderlabs/alpine:latest`
  for the control container and `ubuntu:latest` for the target container.  If
  not set, the `Dockerfile` for each container specifies these as the default.
  Be careful to use a similar flavour of Linux if changing the base images, or
  you will need to make appropriate adjustments to the `Dockerfile` and
  `Entrypoint.sh` files of affected containers.
* `container_name` - Set to *ansible-control* and *ansible-target*, but these
  can be altered if other names are preferred.  Check out the [Inventory
  configuration](#inventory-configuration) section if you want to change
  *ansible-target*.
* `image` - Set to *ansible_control_image* and *ansible_target_image*, but again
  can be altered if other names are preferred.
* `ANSIBLE_ROLES_PATH` - An environment variable for the *ansible-control*
  container, this is the target directory of the playbook's roles **in the
  container**.  If you follow standard Ansible structure, you should not need to
  change this.
* `ANSBILE_PLAYBOOK` - An environment variable for the *ansible-control*
  container you **must** replace with the name of your playbook file.
* `CREATE_FILES` - An environment variable for the *ansible-target* container,
  which is used to specify a comma-separated list of empty files that must be
  added when the container is built.  Use this if your Ansible script is
  expecting files but doesn't actually read them, such as `systemd` config files
  (not usually present in Docker containers).
* `volumes` - You should not need to change the Ansible playbook mapping for the
  control container.  If you do so, you will need to change `RunPlaybook.sh`,
  `ErrorHandling.sh` and `build/ansible-control/Dockerfile` to match.  The SSH
  mappings should point to your private and public key pair, which must **not**
  have a passphrase.  The same public key must be used in **both** containers.

There are other items set in this file which should not be changed.  Alter them
at your own risk.

### Inventory configuration
You need to alter the `inventory` file to match the desired host from your
Ansible playbook file.  If you change the name of the *ansible-target*
container, update this file to match it.
  
If you wish to run Ansible against multiple targets, you will need to:
1. declare all hosts in this file, with a unique container name for each
2. create an entry for each additional container in `docker-compose.yml` by
   cloning *ansible-target* and giving each service a different container and
   image name

### Troubleshooting
1. If you use an SSH key pair that requires a passphrase, you will see the
   following error in the **ansible-control** container logs:
   ```
   fatal: [ansible-target]: UNREACHABLE! => {"changed": false, "msg": "SSH Error: data could not be sent to remote host \"ansible-target\". Make sure this host can be reached over ssh", "unreachable": true}
   ```
   If you are certain your SSH key pair does **not** require a passphrase and
   you have supplied the same public key to **both** containers, log in
   to the *ansible-control* container as described in the [Inspecting
   containers](#inspecting-containers) section and run the following command:
   ```
   ssh ansible-target
   ```
   If you can successfully connect to the *ansible-target* container without
   being prompted for a password, your SSH key pair is sound and you likely have
   a Python issue instead - keep reading.
2. You must have Python & Pip installed on **both** containers (the default
   `Dockerfile` does this for you).
    1. At the time of writing, Ansible defaulted to invoking Python 2 on the
       **ansible-target** container and expected
       it to be installed in `/usr/bin/python`.  If this is missing, Ansible
       will report the same (counterintuitive) SSH error described above in the
       **ansible-control** container.  The `inventory` file is used to override
       this default behaviour and allow us to use Python 3 (see point 3 for
       further details).
    2. If Pip is missing, this error will appear in the **ansible-control**
       container:
       ```
       fatal: [ansible-target]: FAILED! => {"changed": false, "msg": "Unable to find any of pip3 to use.  pip needs to be installed."}
       ```
3. If your playbook contains an `inventory` file, add its content to the
   supplied `inventory` file in the `build/ansible-control` directory. This file
   is injected into the *ansible-control* container and assumes Python 3 is in
   use, which is the default for Ubuntu releases beyond 16.10.
   
   The `ansible_python_interpreter` directive for the *ansible-target* container
   will need to be changed if:
    1. you use a Linux base image that has a different default version of
       Python
    2. the latest version of Ansible assumes (or requires) a different Python
       version
      
   **Note:**  The `ansible_python_interpreter` directive can be deleted if the
   default Python interpreter in the *ansible-target* container matches the
   Python version expected by Ansible.
 
