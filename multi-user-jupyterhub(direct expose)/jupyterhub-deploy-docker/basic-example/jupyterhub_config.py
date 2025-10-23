# Copyright (c) Jupyter Development Team.
# Distributed under the terms of the Modified BSD License.

# Configuration file for JupyterHub
import os

c = get_config()  # noqa: F821

# We rely on environment variables to configure JupyterHub so that we
# avoid having to rebuild the JupyterHub container every time we change a
# configuration parameter.

# Spawn single-user servers as Docker containers
c.JupyterHub.spawner_class = "dockerspawner.DockerSpawner"

c.JupyterHub.log_level = 'DEBUG'

# Spawn containers from this image
c.DockerSpawner.image = os.environ["DOCKER_NOTEBOOK_IMAGE"]

c.DockerSpawner.extra_host_config = {
    'privileged': True,  # Run containers in privileged mode
}

#c.DockerSpawner.cmd = ['--topo', 'linear,3']

# Connect containers to this Docker network
network_name = os.environ["DOCKER_NETWORK_NAME"]
c.DockerSpawner.use_internal_ip = True
c.DockerSpawner.network_name = network_name

# Explicitly set notebook directory because we'll be mounting a volume to it.
# Most `jupyter/docker-stacks` *-notebook images run the Notebook server as
# user `jovyan`, and set the notebook directory to `/home/jovyan/work`.
# We follow the same convention.
notebook_dir = os.environ.get("DOCKER_NOTEBOOK_DIR", "/home/jovyan/work")
c.DockerSpawner.notebook_dir = notebook_dir

c.DockerSpawner.default_url = '/lab/tree/Home_page.ipynb'

# Mount the real user's Docker volume on the host to the notebook user's
# notebook directory in the container
c.DockerSpawner.volumes = {"jupyterhub-user-{username}": notebook_dir}

c.Spawner.http_timeout = 120

# Remove containers once they are stopped
c.DockerSpawner.remove = True

# For debugging arguments passed to spawned containers
c.DockerSpawner.debug = True

# User containers will access hub by container name on the Docker network
c.JupyterHub.hub_ip = "jupyterhub"
c.JupyterHub.hub_port = 8080

# Persist hub data on volume mounted inside container
c.JupyterHub.cookie_secret_file = "/data/jupyterhub_cookie_secret"
c.JupyterHub.db_url = "sqlite:////data/jupyterhub.sqlite"

# Allow all signed-up users to login
#c.Authenticator.allow_all = True

c.Authenticator.allowed_users = {
'apnic_isif01','apnic_isif02', 
'apnic_isif03','apnic_isif04', 
'apnic_isif05','apnic_isif06', 
'apnic_isif07','apnic_isif08', 
'apnic_isif09','apnic_isif10', 
'apnic_isif11','apnic_isif12', 
'apnic_isif13', 'apnic_isif14', 
'apnic_isif15', 'apnic_isif16', 
'apnic_isif17', 'apnic_isif18', 
'apnic_isif19', 'apnic_isif20', 
'apnic_isif21', 'apnic_isif22', 
'apnic_isif23', 'apnic_isif24', 
'apnic_isif25', 'apnic_isif26', 
'apnic_isif27', 'apnic_isif28', 
'apnic_isif29', 'apnic_isif30',
}

# Authenticate users with Native Authenticator
#c.JupyterHub.authenticator_class = "nativeauthenticator.NativeAuthenticator"

# Allow anyone to sign-up without approval
#c.NativeAuthenticator.open_signup = True


# Allowed admins
admin = os.environ.get("JUPYTERHUB_ADMIN")
if admin:
    c.Authenticator.admin_users = [admin]
