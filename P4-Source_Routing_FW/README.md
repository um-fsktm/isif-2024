P4 source routing with firewall code and necessary files

Dockerfile deploy a jupyter notebook container that installed with P4 lab related tools, for example mininet, p4c, python.

Build the container image, it will take awhile.
```
sudo docker build -t p4-test .
```

After completely build, run the container
```
sudo docker run -d --privileged -p <your listening IP address>:8888:8888 p4-test
```
use ```sudo docker ps``` to see the container name.

Enter to the container and retrieve the jupyter notebook token.
```
sudo docker exec -it <container name> /bin/bash
jupyter server list
```

After enter into the notebook, install necessary dependencies
```
pip install finsy
pip install networkx
chmod +X mesh_topo2.py
```

Compile the P4 program.
```
p4c --target bmv2 --arch v1model --p4runtime-files source_routing.p4info.txt source_routing.p4
```

Open a tab, run the mininet with preconfigured file.
```
sudo ./mesh_topo2.py
```

Open another tab, run the python controller program.
```
python controller3.py
```


