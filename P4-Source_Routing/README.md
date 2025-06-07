P4 source routing source code and files to run

Dockerfile deploy a jupyter notebook container that installed with P4 lab related tools, for example mininet, p4c, python.

Build the container image, it will take awhile.
```
sudo docker build -t p4-test .
```

After completely build, run the container
```
sudo docker run -d --privileged -p <your listening IP address>:8888:8888 p4-test
sudo docker exec -it <container name> /bin/bash
```
Execute ```jupyter server list``` to retrieve token to access the jupyter notebook.

After enter into the notebook, install necessary dependencies
```
pip install finsy
pip install networkx
chmod +X mesh_topo2.py
```

```
p4c --target bmv2 --arch v1model --p4runtime-files source_routing.p4info.txt source_routing.p4

```
