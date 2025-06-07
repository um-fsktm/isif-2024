## Verifying connectivity for the overlay VXLAN networks deploy with P4-BMV2 containers.

1. Displaying node IP Address information.
 ![image](https://github.com/user-attachments/assets/683191f1-b6c0-4c5b-a5c9-153f7cac840f)
2. Verify reachability between 2 nodes.
 ![image](https://github.com/user-attachments/assets/436e2162-9963-47ab-91d0-022a4bd5c7ae)
3. Establish VXLAN tunnel.
   ![image](https://github.com/user-attachments/assets/26b38a47-bcfa-41fc-8cbd-5e7998e32433)
4. Run BMV2 docker container in each host, attach the VXLAN interface to it.
   ![image](https://github.com/user-attachments/assets/f603c20b-0411-4238-a851-92d580e50cb4)

5. Use a machine as controller node, connect to the BMV2 switches, and insert the forwarding rules.
   ![image](https://github.com/user-attachments/assets/2527f41f-fe07-42bb-9153-9022d85d687a)

6. Verify end hosts can ping each other.
    ![image](https://github.com/user-attachments/assets/938ff208-7930-4e01-83ba-1581f7026346)
