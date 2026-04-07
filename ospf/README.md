# Lab: OSPF

Open Shortest Path First routing protocol lab using Containerlab and FRR.

## Topology

5 FRR routers (R1–R5) and 3 end hosts (PC1–PC3) connected in a mesh topology:

```
        PC1
         |
   R1---R2
   |  \/ |
   |  /\ |
   R3---R4---PC3
    \   /
     R5
      |
     PC2
```

**Subnets:**

- PC1 (`192.168.1.0/24`) — connected to R1
- PC2 (`192.168.2.0/24`) — connected to R5
- PC3 (`192.168.3.0/24`) — connected to R4

Router configurations are intentionally minimal — students configure OSPF themselves.

## Files

| File | Description |
|---|---|
| `ospf.clab.yml` | Containerlab topology definition |
| `daemons` | FRR daemon config (ospfd + ripd enabled) |
| `R1.conf` – `R5.conf` | FRR startup configs (hostname only) |

## Usage

```bash
cd ~/EINTE-labs/ospf
containerlab deploy --topo ospf.clab.yml
docker exec -it clab-ospf-R1 vtysh
```

When done:

```bash
containerlab destroy --topo ospf.clab.yml
```
