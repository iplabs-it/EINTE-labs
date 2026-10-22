# Lab: BGP

Introductory BGP lab using Containerlab and FRR: four autonomous systems, eBGP sessions, prefix advertisement, AS_PATH filtering, aggregation, prepending, selective advertisement and Local Preference.

## Topology

4 routers (R1–R4), each in its own AS, and 3 end hosts (H11, H12, S41):

```
   H11 (192.168.110.100/26)                             S41 (192.168.140.41/24)
      \                                                   /
  192.168.110.64/26   10.0.12.0/30            10.0.24.0/30   192.168.140.0/24
       R1 ------------------------- R2 -------------------------- R4
     AS 100   \                   AS 200                 /     AS 400
     Nobank    \  10.0.13.0/30              10.0.34.0/30        Datastor
      /         \------------------- R3 ---------------/
   H12 (192.168.110.200/26)        AS 300
   192.168.110.192/26              SlowNet
```

**Autonomous Systems:**

- AS 100, Nobank: R1 (customer, an enterprise), loopback 1.1.1.1/32, two customer LANs (H11, H12)
- AS 200, FastNet: R2 (ISP 1), loopback 2.2.2.2/32
- AS 300, SlowNet: R3 (ISP 2), loopback 3.3.3.3/32
- AS 400, Datastor: R4 (content provider), loopback 4.4.4.4/32, server LAN (S41)

**Addressing:**

- Customer LANs: `192.168.110.64/26` (H11, gateway R1 eth1 .65) and `192.168.110.192/26` (H12, gateway R1 eth4 .193)
- Server LAN: `192.168.140.0/24` (S41, gateway R4 eth1 .1)
- Inter-AS links: `10.0.12.0/30` (R1–R2), `10.0.13.0/30` (R1–R3), `10.0.24.0/30` (R2–R4), `10.0.34.0/30` (R3–R4)

The routers come with interface addresses only; all BGP configuration is done by the students. The hosts have a default route to their router.

## Files

| File | Description |
|---|---|
| `bgp.clab.yml` | Containerlab topology definition |
| `daemons` | FRR daemon config (bgpd enabled) |
| `R1.conf` – `R4.conf` | Initial router configs (interfaces and loopbacks) |

## Getting the Lab

Check whether a copy of the repository already exists on the VM:

```bash
ls -d ~/EINTE-labs/.git
```

**Case A, the path is printed (repository already there):**

```bash
cd ~/EINTE-labs
git fetch
git merge --no-edit origin/lab2-bgp
```

**Case B, "No such file or directory" (no repository yet):**

```bash
cd ~
git clone https://github.com/iplabs-it/EINTE-labs.git
cd EINTE-labs
git merge --no-edit origin/lab2-bgp
```

## Usage

```bash
cd ~/EINTE-labs/bgp
containerlab deploy
docker exec -it clab-bgp-R1 vtysh
```

Checkpoint after each task and package at the end:

```bash
bash ~/EINTE-labs/common/checkpoint.sh task1
bash ~/EINTE-labs/common/package_submission.sh bgp
```

When done:

```bash
containerlab destroy
```
