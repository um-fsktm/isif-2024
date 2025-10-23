# Guide to setup Jupyterhub environment for hands-on lab
## What is this about
Jupyterhub is a multi-user environment. It is able to spawn sandbox containers for each user. This repository will guide you to setup a Jupyterhub service that spawn containers(installed with Mininet, BMV2 software switch) for each user.

## Folders in this repository
**/p4mn-jupyter** contains docker file to build a jupyter notebook installed with mininet and bmv2. When user login from jupyterhub, a new container with this image will be spawned for the user.<br/>
**/jupyterhub-deploy-docker/basic-example** contains docker compose file to run Jupyterhub and the jupyterhub_config.py is for the jupyterhub configuration.<br/>

## Setup the environment in your machine.

### Building the jupyter notebook image 
1. cd **/p4mn-jupyter**
2. **/data** folder contains files to share with the users.
3. ```sudo docker build -t p4mn .```
4. the dockerfile compilation might take some time.

### Build and run Jupyterhub
1. cd **/jupyterhub-deploy-docker/basic-example**
2. *jupyterhub_config.py* contains authentication methods, spawner config, allowed user, etc. You may refer to Jupyterhub documentation if need modification.
3. edit *docker-compose.yml* ip address and port listening based on your environment
```
    ports:
      - "100.100.2.2:8000:8000"
```
4. *user_create.sh* contains the list of user and password to be created and access to the Jupyterhub.
5. Deploy the Jupyterhub software and run it in background ```sudo docker compose up -d```
6. Access the Jupyterhub container and create users.(the default admin user password is P@ssw0rd which in the user_create.sh script)
```
sudo docker exec -it jupyterhub /bin/bash
cd /
chmod 777 user_create.sh
./user_create.sh
```

Now you should be able to login to your jupyterhub environment with http.
