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
| mm-node | 100.100.6.6  |

Running BMV2 switches in each node, with full mesh VXLAN tunnels to each node.
![P4 Overlay topology](https://github.com/user-attachments/assets/2b7c6e11-8596-40ee-b2cf-b896fc58f145)


### Connectivity Check
Ping test between each nodes success.

## How to

To setup BMV2+VXLAN in docker containers, refer to [link](https://github.com/um-fsktm/isif-2025/tree/main/BMV2-VXLAN-setup).

To setup Jupyterhub environment, that spawn containers with mininet+bmv2 installed, refer to [link](https://github.com/um-fsktm/isif-2025/tree/main/multi-user-jupyterhub).

# Training guide
1. First training session 1.5h [Introduction to P4 hands-on lab](https://github.com/um-fsktm/isif-2025/tree/57e499c4501676a1a89e6a3593dc7b9860840557/training-materials/Introduction%20to%20P4%2022-Feb-2025) - 20+ participants via Webex
