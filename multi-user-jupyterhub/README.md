# Guide to setup Jupyterhub environment for hands-on lab

## Folders in this repository
**/p4mn-jupyter** contains docker file to build a jupyter notebook installed with mininet and bmv2. When user login from jupyterhub, a new container with this image will be spawned for the user.
**/jupyterhub-deploy-docker/basic-example** contains docker compose file to run Jupyterhub and the jupyterhub_config.py is for the jupyterhub configuration.
**/caddy-lb** contains docker compose file to deploy caddy reverse proxy for your Jupyterhub. #By default Jupyterhub is only running https.

## Setup the environment in your machine.

### Building the jupyter notebook image 
1. cd **/p4mn-jupyter**
2. **/data** folder contains files to share with the users.
3. ```sudo docker build -t p4mn .```
4. the dockerfile compilation might take some time.

### Build and run Jupyterhub
1. cd **/jupyterhub-deploy-docker/basic-example**
2. jupyterhub_config.py contains authentication methods, spawner config, allowed user, etc. You may refer to Jupyterhub documentation if need modification.
3. edit docker-compose.yml ip address and port listening based on your environment
```
    ports:
      - "100.100.2.2:8000:8000"
```
4. user_create.sh contains the list of user and password to be created and access to the Jupyterhub.
5. Deploy the Jupyterhub software and run it in background ```sudo docker compose up -d```
6. Access the Jupyterhub container and create users
```
sudo docker exec -it jupyterhub /bin/bash
cd /
./user_create.sh
```

Now you should be able to login to your jupyterhub environment with http. If you need https, you will need to configure public DNS record and point to your public ip.

### Build and run Caddy reverse proxy(for HTTPS access)
1. Add public A record in your DNS server and point to your Jupyterhub server IP address.
2. **cd /caddy-lb**
3. Caddyfile contains reverse proxy configuration. Modify it with your domain name and backend Jupyterhub server IP address and port.
4. Caddy reverse proxy will create letencrypt certificate automatically.
5. ```sudo docker compose up``` to run the Caddy reverse proxy for the first time. If no error, stop it and run again with ```sudo docker compose up -d```.
6. You should now be able to access Jupyterhub from the configured domain name with HTTPS.
