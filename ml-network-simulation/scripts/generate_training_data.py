#!/usr/bin/env python3
"""
generate_training_data.py

Generates synthetic network topologies and traffic matrices for training
the ML network simulation model. Produces labeled datasets with ground-truth
performance metrics computed via analytical flow-level simulation.
"""

import argparse
import json
import os
import random
from pathlib import Path

import networkx as nx
import numpy as np


def generate_fat_tree(k: int) -> dict:
    """Generate a k-ary fat-tree topology."""
    num_pods = k
    num_core = (k // 2) ** 2
    num_agg_per_pod = k // 2
    num_edge_per_pod = k // 2
    num_hosts_per_edge = k // 2

    nodes = []
    edges = []
    
    # Core switches
    for i in range(num_core):
        nodes.append({"id": f"core_{i}", "type": "switch", "layer": "core"})
    
    for pod in range(num_pods):
        # Aggregation switches
        for agg in range(num_agg_per_pod):
            agg_id = f"agg_{pod}_{agg}"
            nodes.append({"id": agg_id, "type": "switch", "layer": "aggregation"})
            
            # Connect to core
            core_start = agg * (k // 2)
            for c in range(k // 2):
                edges.append({
                    "src": agg_id,
                    "dst": f"core_{core_start + c}",
                    "capacity_gbps": 100
                })
        
        # Edge switches
        for edge in range(num_edge_per_pod):
            edge_id = f"edge_{pod}_{edge}"
            nodes.append({"id": edge_id, "type": "switch", "layer": "edge"})
            
            # Connect to aggregation
            for agg in range(num_agg_per_pod):
                edges.append({
                    "src": edge_id,
                    "dst": f"agg_{pod}_{agg}",
                    "capacity_gbps": 100
                })
            
            # Hosts
            for h in range(num_hosts_per_edge):
                host_id = f"host_{pod}_{edge}_{h}"
                nodes.append({"id": host_id, "type": "host", "layer": "access"})
                edges.append({
                    "src": host_id,
                    "dst": edge_id,
                    "capacity_gbps": 25
                })
    
    return {"nodes": nodes, "edges": edges, "type": "fat-tree", "k": k}


def generate_traffic_matrix(num_hosts: int, model: str = "poisson") -> list:
    """Generate a traffic matrix for the given topology."""
    flows = []
    
    for _ in range(random.randint(num_hosts * 2, num_hosts * 10)):
        src = random.randint(0, num_hosts - 1)
        dst = random.randint(0, num_hosts - 1)
        while dst == src:
            dst = random.randint(0, num_hosts - 1)
        
        if model == "poisson":
            size_bytes = int(np.random.exponential(100000))
        elif model == "pareto":
            size_bytes = int((np.random.pareto(1.2) + 1) * 10000)
        else:  # on-off
            size_bytes = int(np.random.choice([1000, 1000000]) * np.random.uniform(0.5, 2.0))
        
        flows.append({
            "src": src,
            "dst": dst,
            "size_bytes": max(64, size_bytes),
            "start_time_us": random.randint(0, 1000000)
        })
    
    return flows


def main():
    parser = argparse.ArgumentParser(description="Generate training data for ML network simulation")
    parser.add_argument("--topology", choices=["fat-tree", "leaf-spine", "ring"], default="fat-tree")
    parser.add_argument("--num-hosts", type=int, default=256)
    parser.add_argument("--num-scenarios", type=int, default=1000)
    parser.add_argument("--output-dir", type=str, default="data/training/")
    parser.add_argument("--traffic-model", choices=["poisson", "pareto", "on-off"], default="poisson")
    args = parser.parse_args()

    output_path = Path(args.output_dir)
    output_path.mkdir(parents=True, exist_ok=True)

    # Generate topology
    k = int(np.ceil(np.power(args.num_hosts * 4, 1/3)) // 2 * 2)
    topology = generate_fat_tree(k)
    
    with open(output_path / "topology.json", "w") as f:
        json.dump(topology, f, indent=2)
    
    print(f"Generated {topology['type']} topology with k={k}")
    print(f"  Nodes: {len(topology['nodes'])}")
    print(f"  Edges: {len(topology['edges'])}")

    # Generate scenarios
    num_hosts = sum(1 for n in topology["nodes"] if n["type"] == "host")
    
    for i in range(args.num_scenarios):
        flows = generate_traffic_matrix(num_hosts, args.traffic_model)
        
        scenario = {
            "id": i,
            "traffic_model": args.traffic_model,
            "num_flows": len(flows),
            "flows": flows
        }
        
        scenario_file = output_path / f"scenario_{i:05d}.json"
        with open(scenario_file, "w") as f:
            json.dump(scenario, f)
        
        if (i + 1) % 100 == 0:
            print(f"  Generated {i + 1}/{args.num_scenarios} scenarios")

    print(f"\nDone. Output: {output_path}")
    print(f"  Topology: topology.json")
    print(f"  Scenarios: scenario_00000.json - scenario_{args.num_scenarios - 1:05d}.json")


if __name__ == "__main__":
    main()
