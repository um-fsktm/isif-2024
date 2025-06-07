#!/usr/bin/env python
from mininet.topo import Topo
from mininet.net import Mininet
from mininet.node import Host, Switch
from mininet.log import setLogLevel, info, warn, debug
from mininet.cli import CLI
import os
import time
import multiprocessing
import threading
import socket
import sys
import json

# Constants
DEFAULT_PIPECONF = "org.onosproject.pipelines.basic"
BMV2_DEFAULT_DEVICE_ID = 1
SWITCH_START_TIMEOUT = 10  # seconds
BMV2_LOG_LINES = 100
SIMPLE_SWITCH_GRPC = "simple_switch_grpc"
VALGRIND_PREFIX = "valgrind --leak-check=yes --log-file=/tmp/bmv2-valgrind-%s.log"
STRATUM_BMV2 = "stratum_bmv2"
STRATUM_BINARY = "/usr/local/bin/stratum_bmv2"
STRATUM_INIT_PIPELINE = "/stratum/bmv2/data/bmv2.json"

def parseBoolean(value):
    return str(value).lower() in ['true', '1', 'yes']

def writeToFile(filename, value):
    with open(filename, 'w') as f:
        f.write(str(value))

def pickUnusedPort():
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.bind(('localhost', 0))
    port = s.getsockname()[1]
    s.close()
    return port

def watchDog(switch):
    while not switch.stopped and not ONOSBmv2Switch.mininet_exception.value:
        if not os.path.isfile(switch.keepaliveFile):
            warn("\n*** Mininet stopped unexpectedly! Killing %s...\n" % switch.name)
            switch.killBmv2()
            break
        time.sleep(1)

class MeshTopo(Topo):
    """Full mesh topology with N switches and N hosts"""
    def __init__(self, n=5, **opts):
        Topo.__init__(self, **opts)
        
        switches = []
        hosts = []
        
        # Create switches and hosts
        for i in range(1, n+1):
            # Add switch
            switch = self.addSwitch('s%d' % i)
            switches.append(switch)
            
            # Add host with incremental MAC and IP
            host = self.addHost('h%d' % i,
                              mac='00:00:00:00:00:%02d' % i,
                              ip='10.0.0.%d/24' % i)
            hosts.append(host)
            self.addLink(host, switch)
        
        # Create full mesh between switches
        for i in range(n):
            for j in range(i+1, n):
                self.addLink(switches[i], switches[j])

class ONOSHost(Host):
    """Custom host with static ARP entries"""
    def __init__(self, name, **params):
        Host.__init__(self, name, **params)
        self.static_arp = {}

    def config(self, **params):
        result = super(ONOSHost, self).config(**params)
        
        # Disable offloading
        for off in ["rx", "tx", "sg"]:
            cmd = "/sbin/ethtool --offload %s %s off" % (self.defaultIntf(), off)
            self.cmd(cmd)
        
        # Disable IPv6
        self.cmd("sysctl -w net.ipv6.conf.all.disable_ipv6=1")
        self.cmd("sysctl -w net.ipv6.conf.default.disable_ipv6=1")
        self.cmd("sysctl -w net.ipv6.conf.lo.disable_ipv6=1")
        
        return result

    def addStaticArp(self, ip, mac):
        """Add a static ARP entry (to be called after config)"""
        self.cmd("arp -i %s -s %s %s" % (self.defaultIntf(), ip, mac))
        self.static_arp[ip] = mac

class ONOSBmv2Switch(Switch):
    """BMv2 software switch with gRPC server"""
    mininet_exception = multiprocessing.Value('i', 0)
    nextGrpcPort = 50001

    def __init__(self, name, json=None, debugger=False, loglevel="warn",
                 elogger=False, cpuport=255, notifications=False,
                 thrift=False, dryrun=False,
                 pipeconf=DEFAULT_PIPECONF, pktdump=False, valgrind=False,
                 gnmi=False, portcfg=True, onosdevid=None, stratum=False,
                 **kwargs):
        Switch.__init__(self, name, **kwargs)
        self.grpcPort = ONOSBmv2Switch.nextGrpcPort
        ONOSBmv2Switch.nextGrpcPort += 1
        self.grpcPortInternal = None
        if not thrift:
            self.thriftPort = None
        else:
            raise Exception("Support for thrift not implemented")
        self.cpuPort = cpuport
        self.json = json
        self.useStratum = parseBoolean(stratum)
        self.debugger = parseBoolean(debugger)
        self.notifications = parseBoolean(notifications)
        self.loglevel = loglevel
        self.logfile = '/tmp/bmv2-%s-log' % self.name
        self.elogger = parseBoolean(elogger)
        self.pktdump = parseBoolean(pktdump)
        self.dryrun = parseBoolean(dryrun)
        self.valgrind = parseBoolean(valgrind)
        self.netcfgfile = '/tmp/bmv2-%s-netcfg.json' % self.name
        self.chassisConfigFile = '/tmp/bmv2-%s-chassis-config.txt' % self.name
        self.pipeconfId = pipeconf
        self.injectPorts = parseBoolean(portcfg)
        self.withGnmi = parseBoolean(gnmi)
        self.onosDeviceId = "device:bmv2:%s" % self.name
        self.p4DeviceId = BMV2_DEFAULT_DEVICE_ID
        self.logfd = None
        self.bmv2popen = None
        self.stopped = True
        self.keepaliveFile = '/tmp/bmv2-%s-watchdog.out' % self.name
        self.targetName = STRATUM_BMV2 if self.useStratum else SIMPLE_SWITCH_GRPC
        self.cleanupTmpFiles()

    def getDeviceConfig(self):
        basicCfg = {
            "managementAddress": "grpc://localhost:%d?device_id=%d" % (
                self.grpcPort, self.p4DeviceId),
            "driver": "stratum-bmv2" if self.useStratum else "bmv2",
            "pipeconf": self.pipeconfId
        }
        cfgData = {
            "devices": {
                self.onosDeviceId: basicCfg
            }
        }
        return cfgData

    def start(self, controllers):
        if not self.stopped:
            warn("*** %s is already running!\n" % self.name)
            return

        self.cleanupTmpFiles()
        writeToFile("/tmp/bmv2-%s-grpc-port" % self.name, self.grpcPort)
        writeToFile(self.keepaliveFile, "1")

        if self.useStratum:
            config_dir = "/tmp/bmv2-%s-stratum" % self.name
            os.mkdir(config_dir)
            if self.grpcPortInternal is None:
                self.grpcPortInternal = pickUnusedPort()
            cmdString = self.getStratumCmdString(config_dir)
        else:
            cmdString = self.getBmv2CmdString()

        debug("\n%s\n" % cmdString)

        try:
            if not self.dryrun:
                self.stopped = False
                self.logfd = open(self.logfile, "w")
                self.logfd.write(cmdString + "\n\n" + "-" * 80 + "\n\n")
                self.logfd.flush()
                self.bmv2popen = self.popen(cmdString,
                                            stdout=self.logfd,
                                            stderr=self.logfd)
                self.waitBmv2Start()
                threading.Thread(target=watchDog, args=[self]).start()

            with open(self.netcfgfile, 'w') as fp:
                json.dump(self.getDeviceConfig(), fp, indent=4)
        except Exception:
            ONOSBmv2Switch.mininet_exception = 1
            self.killBmv2()
            self.printBmv2Log()
            raise

    def getBmv2CmdString(self):
        bmv2Args = [SIMPLE_SWITCH_GRPC] + self.bmv2Args()
        if self.valgrind:
            bmv2Args = VALGRIND_PREFIX.split() + bmv2Args
        return " ".join(bmv2Args)

    def bmv2Args(self):
        args = ['--device-id %s' % str(self.p4DeviceId)]
        for port, intf in self.intfs.items():
            if not intf.IP():
                args.append('-i %d@%s' % (port, intf.name))
        args.append('--log-console')
        args.append('-L%s' % self.loglevel)
        args.append('--no-p4')
        args.append('--thrift-port 0')
        args.append('--')
        args.append('--cpu-port %s' % self.cpuPort)
        args.append('--grpc-server-addr 0.0.0.0:%s' % self.grpcPort)
        return args

    def waitBmv2Start(self):
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        endtime = time.time() + SWITCH_START_TIMEOUT
        while True:
            port = self.grpcPortInternal if self.grpcPortInternal else self.grpcPort
            result = sock.connect_ex(('localhost', port))
            if result == 0:
                print("⚡️ %s @ %d" % (self.targetName, self.grpcPort))
                sock.close()
                break
            if endtime > time.time():
                sys.stdout.write('.')
                sys.stdout.flush()
                time.sleep(0.05)
            else:
                raise Exception("Switch did not start before timeout")

    def printBmv2Log(self):
        if os.path.isfile(self.logfile):
            print("-" * 80)
            print("%s log (from %s):" % (self.name, self.logfile))
            with open(self.logfile, 'r') as f:
                lines = f.readlines()
                if len(lines) > BMV2_LOG_LINES:
                    print("...")
                for line in lines[-BMV2_LOG_LINES:]:
                    print(line.rstrip())

    def killBmv2(self, log=False):
        self.stopped = True
        if self.bmv2popen is not None:
            self.bmv2popen.terminate()
            self.bmv2popen.wait()
            self.bmv2popen = None
        if self.logfd is not None:
            if log:
                self.logfd.write("*** PROCESS TERMINATED BY MININET ***\n")
            self.logfd.close()
            self.logfd = None

    def cleanupTmpFiles(self):
        self.cmd("rm -rf /tmp/bmv2-%s-*" % self.name)

    def stop(self, deleteIntfs=True):
        self.killBmv2(log=True)
        Switch.stop(self, deleteIntfs)

def configure_network(net):
    """Configure network settings after startup"""
    n = len(net.hosts)
    
    for host in net.hosts:
        host.cmd('ifconfig %s up' % host.defaultIntf())
    
    for i in range(1, n+1):
        host = net.get('h%d' % i)
        for j in range(1, n+1):
            if i != j:
                ip = '10.0.0.%d' % j
                mac = '00:00:00:00:00:%02d' % j
                host.addStaticArp(ip, mac)
                info('Added static ARP on h%d: %s -> %s\n' % (i, ip, mac))

def run():
    setLogLevel('info')
    
    net = Mininet(topo=MeshTopo(n=4),
                 host=ONOSHost,
                 switch=ONOSBmv2Switch,
                 controller=None,
                 autoSetMacs=True)
    
    info('Starting network...\n')
    net.start()
    
    for switch in net.switches:
        if not switch.cmd('pgrep -f "simple_switch_grpc.*%s"' % switch.name):
            info('Switch %s failed to start!\n' % switch.name)
            switch.printBmv2Log()
            net.stop()
            return
    
    configure_network(net)
    
    info("\nNetwork ready:\n")
    info("Switch gRPC ports:\n")
    for switch in net.switches:
        info("%s: gRPC %d\n" % (switch.name, switch.grpcPort))
    
    CLI(net)
    net.stop()

if __name__ == '__main__':
    run()
