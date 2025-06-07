from pathlib import Path
import json
import asyncio
import contextlib
import finsy as fy
import networkx as nx
from collections import defaultdict

# Define the P4 source directory
_P4SRC = Path(__file__).parent

def ipv4_lpm_append_tags_and_forward(dstAddr: str, ports: list):
    """Create a table entry for IPv4 LPM with 2-9 source routing hops."""
    num_hops = len(ports)
    if num_hops < 2 or num_hops > 9:
        raise ValueError("Number of hops must be between 2 and 9")
    
    # Pack all ports into a bit string
    route_data = 0
    for i, port in enumerate(ports):
        bos = 1 if i == num_hops - 1 else 0
        encoded = (bos << 15) | port
        route_data |= encoded << (i * 16)
    
    # Calculate required bitwidth (16 bits per hop)
    bitwidth = num_hops * 16
    
    return +fy.P4TableEntry(
        "ipv4_lpm",
        match=fy.Match(dstAddr=dstAddr),
        action=fy.Action(f"append_{num_hops}_tags", route_data=route_data),
    )



def ipv4_lpm_drop_default():
    """Create default drop action for IPv4 LPM table."""
    return ~fy.P4TableEntry(
        "ipv4_lpm",
        action=fy.Action("drop"),
        is_default_action=True,
    )

def load_topology(json_file: Path):
    """Load network topology from JSON file."""
    with open(json_file, "r") as f:
        return json.load(f)

def build_graph(topology):
    """Build NetworkX graph from topology."""
    graph = nx.Graph()
    for link in topology["links"]:
        graph.add_edge(
            link["source"],
            link["target"],
            src_port=link["source_port"],
            dst_port=link["target_port"]
        )
    return graph

class NetworkController:
    def __init__(self, topology):
        self.topology = topology
        self.graph = build_graph(topology)
        self.switches = {}  # Track switch connections
        
        # Initialize with default drop action for each switch
        self.default_entries = {switch["name"]: [ipv4_lpm_drop_default()] 
                              for switch in topology["switches"]}

    def get_topology(self):
        """Return current topology."""
        return self.topology

    async def _write_entry(self, switch_name, entry):
        """Write a single entry to a switch."""
        if switch_name not in self.switches:
            print(f"Switch {switch_name} not connected")
            return False

        try:
            await self.switches[switch_name].write([entry])
            return True
        except Exception as e:
            print(f"Error writing to {switch_name}: {e}")
            return False

    async def initialize_switches(self):
        """Initialize all switches with default entries."""
        for switch_name, entries in self.default_entries.items():
            if switch_name in self.switches:
                await self._write_entry(switch_name, entries[0])

    async def add_communication_path(self, src_ip: str, dst_ip: str, ports: list):
        """Add source-routed path between two hosts with 2-9 hops."""
        src_host = next((h for h in self.topology["hosts"] if h["ip"] == src_ip), None)
        dst_host = next((h for h in self.topology["hosts"] if h["ip"] == dst_ip), None)
        
        if not src_host or not dst_host:
            print(f"Hosts not found: {src_ip} -> {dst_ip}")
            return False
    
        try:
            entry = ipv4_lpm_append_tags_and_forward(dst_host["ip"], ports)
            switch_name = src_host["connected_to"]
            success = await self._write_entry(switch_name, entry)
            if success:
                print(f"Added path {src_ip} -> {dst_ip} via {ports} on {switch_name}")
            return success
        except ValueError as e:
            print(f"Error: {e}")
            return False

    async def query_table_entries(self, switch_name: str):
        """Query and display table entries for a switch."""
        if switch_name not in self.switches:
            print(f"Switch {switch_name} not connected")
            return

        try:
            print(f"\nTable entries for {switch_name}:")
            async for entry in self.switches[switch_name].read(fy.P4TableEntry("ipv4_lpm")):
                print(f"  - {entry}")
        except Exception as e:
            print(f"Query error: {e}")

    async def check_table_matches(self, switch_name: str):
        """Check and display counter values for table matches."""
        if switch_name not in self.switches:
            print(f"Switch {switch_name} not connected")
            return
    
        try:
            print(f"\nCounter values for {switch_name}:")
            async for counter in self.switches[switch_name].read(
                fy.P4DirectCounterEntry("ipv4_lpm_counter")
            ):
                print(f"  - Table hits: {counter.data.packet_count}")
        except Exception as e:
            print(f"Counter read error: {e}")
            
async def main():
    """Main control plane program."""
    topology = load_topology(_P4SRC / "topo.json")
    controller = NetworkController(topology)

    # Configure switch options
    opts = fy.SwitchOptions(
        p4info=_P4SRC / "source_routing.p4info.txt",
        p4blob=_P4SRC / "source_routing.json",
    )

    # Connect to switches
    async with contextlib.AsyncExitStack() as stack:
        # Connect to all switches
        for switch in topology["switches"]:
            name = switch["name"]
            controller.switches[name] = await stack.enter_async_context(
                fy.Switch(name, f"{switch['ip']}:{switch['port']}", opts)
            )

        # Initialize switch tables
        await controller.initialize_switches()

        # Interactive CLI
        while True:
            try:
                cmd = input("\nCommand (add/query/exit): ").strip().lower()
                
                # In the main loop's "add" command case:
                if cmd == "add":
                    src_ip = input("Source IP: ")
                    dst_ip = input("Destination IP: ")
                    ports_input = input("Hop ports (comma-separated, 2-9 hops): ")
                    try:
                        ports = [int(p.strip()) for p in ports_input.split(",")]
                        await controller.add_communication_path(src_ip, dst_ip, ports)
                    except ValueError:
                        print("Invalid port numbers - must be integers")

                elif cmd == "query":
                    switch = input("Switch name: ")
                    await controller.query_table_entries(switch)

                elif cmd == "counter":
                    switch = input("Switch name: ")
                    await controller.check_table_matches(switch)
                    
                elif cmd == "exit":
                    break
                else:
                    print("Unknown command (add/query/exit)")

            except (EOFError, KeyboardInterrupt):
                break
            except Exception as e:
                print(f"Error: {e}")

if __name__ == "__main__":
    fy.run(main())