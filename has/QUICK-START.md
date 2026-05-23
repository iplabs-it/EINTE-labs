# HAS Lab - Quick Start

## Build and Start the Lab

```bash
./setup-lab.sh
```

The script will guide you through building images and deploying the lab.

## Access Grafana Dashboard

Open in browser: **http://localhost:3000/d/has-lab/has-lab-dashboard**

Login: `admin` / `admin`

## Open Traffic Shaper Terminal

```bash
./scripts/run_demo.sh shape
```

Inside the shaper shell, use these commands:

```bash
./shape_traffic.sh excellent   # 10 Mbit/s, 10ms delay
./shape_traffic.sh good        # 5 Mbit/s, 20ms delay
./shape_traffic.sh moderate    # 3 Mbit/s, 50ms delay
./shape_traffic.sh poor        # 1 Mbit/s, 100ms delay
./shape_traffic.sh terrible    # 500 Kbit/s, 200ms delay
./shape_traffic.sh scenario    # Auto-cycle through all conditions
./shape_traffic.sh show        # Show current settings
```

Watch the Grafana dashboard as the ABR algorithm adapts to changing network conditions.

## Important Notes

- **Client starts automatically** - The streaming client begins immediately after lab deployment. Do not run `./scripts/run_demo.sh start`.

- **Content generation takes time** - The first-time content preparation (video encoding) may take **over 10 minutes** depending on your system.

- **Lab exercises** - See [LAB_EXERCISES.md](LAB_EXERCISES.md) for the complete student exercise guide.

## Useful URLs

| Service | URL |
|---------|-----|
| Grafana Dashboard | http://localhost:3000/d/has-lab/has-lab-dashboard |
| Prometheus | http://localhost:9090 |

## Destroy Lab

```bash
sudo containerlab destroy --topo clab-topology.yaml --cleanup
```
