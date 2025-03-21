# isif-2024
Design, Development and Transfer of Technology of a P4-based SDN Security Playground across multiple economies.

## Playground network

Full mesh of Wireguard tunnel between machines over Internet through tailscale software.

| Node  | IP Address |
| ------------- | ------------- |
| my-node1  | 100.100.1.1  |
| my-node2  | 100.100.2.2  |
| ncku-node  | 100.100.3.3  |
| nuol-node  | 100.100.4.4  |
| sg-node | 100.100.5.5  |

Running BMV2 switches in each node, with full mesh VXLAN tunnels to each node.

![ISIF topology drawio](https://github.com/user-attachments/assets/c8f98b78-2623-4f63-8a4a-c25095be908c)

### Connectivity Check
Ping test between each nodes success.

## How to

To setup BMV2+VXLAN in docker containers, refer to [link](https://github.com/um-fsktm/isif-2025/tree/main/BMV2-VXLAN-setup).

To setup Jupyterhub environment, that spawn containers with mininet+bmv2 installed, refer to [link](https://github.com/um-fsktm/isif-2025/tree/main/multi-user-jupyterhub).

# Training guide
1. First training session 1.5h [Introduction to P4 hands-on lab](https://github.com/um-fsktm/isif-2025/tree/57e499c4501676a1a89e6a3593dc7b9860840557/training-materials/Introduction%20to%20P4%2022-Feb-2025) - 20+ participants via Webex
