The Smee configuration template is setup to listen on the host network to serve DHCP, TFTP, IPXE requests.

The commands below assume the use of the 192.168.2.0/24 network.
 
Set `enabled: true` for the smee deployment in values.yaml

Setup the docker network with the macvlan driver on the interface where the DHCP requests arrive
```
 > docker network create -d macvlan -o parent=enp193s0f3u2  --gateway 192.168.2.1 --subnet 192.168.2.0/24  macvlan
```

Connect the created network to the kind control plane
```
 > docker network connect macvlan kind-control-plane
```
  
Set the public_interface value to the interface name that is now available within the smee container
```
> kubectl exec deployments/tinkerbell-smee -- ip addr list | grep 192.168.2.
   inet 192.168.2.2/24 brd 192.168.2.255 scope global eth4 <---
```
 
Specify static reservations in templates/smee-hardware-configmap.yaml

## Clean up

```
docker network disconnect macvlan kind-control-plane
docker network rm macvlan
```
