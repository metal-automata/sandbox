The Smee configuration template is setup to listen on the host network to serve DHCP, TFTP, IPXE requests.

The example and commands below assume the use of the 192.168.2.0/24 network.

1. Create or update .local-values.yaml with the sample configuration from notes/samples/.smee-local-values.yaml (.local-values.yaml is ignored from git)

2. Setup the docker network with the macvlan driver on the interface where the DHCP requests arrive
```
 > docker network create -d macvlan -o parent=enp193s0f3u2  --gateway 192.168.2.1 --subnet 192.168.2.0/24  macvlan
```

3. Connect the created network to the kind control plane
```
 > docker network connect macvlan kind-control-plane
```
  
4. Set the public_interface value to the interface name that is now available within the smee container
```
> kubectl exec deployments/tinkerbell-smee -- ip addr list | grep 192.168.2.
   inet 192.168.2.2/24 brd 192.168.2.255 scope global eth4 <---
```

5. Specify any static reservations in .local-values.yaml

6. Run `make upgrade` to have tinkerbel-smee deployed

## Clean up

```
docker network disconnect macvlan kind-control-plane
docker network rm macvlan
```
