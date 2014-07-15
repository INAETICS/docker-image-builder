image-builder-service
=====================

Provides a service to build Docker images automatically, given a repository
name and Git repository URL.

Run on local machine using Docker
---------------------------------
* [Install Docker](https://docs.docker.com/installation/);
* Clone this repository: `git clone git://github.com/INAETICS/image-builder-service.git`;
* Start the image by running `./image-builder-service start`;
* Verify that the service is up and running by checking the output of "docker ps" and "docker logs".

Run in Vagrant
--------------
* Install Vagrant & VirtualBox
* Clone this repository
* Configure discovery in coreos-userdata (optional)
* Run `vagrant up`
* No frontend yet

