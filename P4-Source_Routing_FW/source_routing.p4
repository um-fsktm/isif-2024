// SPDX-License-Identifier: Apache-2.0
/* -*- P4_16 -*- */
#include <core.p4>
#include <v1model.p4>

const bit<16> TYPE_IPV4 = 0x800;
const bit<16> TYPE_SRCROUTING = 0x1234;
const bit<8>  TYPE_TCP  = 6;

#define BLOOM_FILTER_ENTRIES 4096
#define BLOOM_FILTER_BIT_WIDTH 1

#define MAX_HOPS 9

/*************************************************************************
*********************** H E A D E R S  ***********************************
*************************************************************************/

typedef bit<9>  egressSpec_t;
typedef bit<48> macAddr_t;
typedef bit<32> ip4Addr_t;

header ethernet_t {
    macAddr_t dstAddr;
    macAddr_t srcAddr;
    bit<16>   etherType;
}

header srcRoute_t {
    bit<1>    bos;       // Bottom of Stack (BOS) flag
    bit<15>   port;      // Output port for this hop
}

header ipv4_t {
    bit<4>    version;
    bit<4>    ihl;
    bit<8>    diffserv;
    bit<16>   totalLen;
    bit<16>   identification;
    bit<3>    flags;
    bit<13>   fragOffset;
    bit<8>    ttl;
    bit<8>    protocol;
    bit<16>   hdrChecksum;
    ip4Addr_t srcAddr;
    ip4Addr_t dstAddr;
}

header tcp_t{
    bit<16> srcPort;
    bit<16> dstPort;
    bit<32> seqNo;
    bit<32> ackNo;
    bit<4>  dataOffset;
    bit<4>  res;
    bit<1>  cwr;
    bit<1>  ece;
    bit<1>  urg;
    bit<1>  ack;
    bit<1>  psh;
    bit<1>  rst;
    bit<1>  syn;
    bit<1>  fin;
    bit<16> window;
    bit<16> checksum;
    bit<16> urgentPtr;
}


struct metadata {
}

struct headers {
    ethernet_t              ethernet;
    srcRoute_t[MAX_HOPS]    srcRoutes; // header stack
    ipv4_t                  ipv4;
    tcp_t                   tcp;
}

/*************************************************************************
*********************** P A R S E R  ***********************************
*************************************************************************/

parser MyParser(packet_in packet,
                out headers hdr,
                inout metadata meta,
                inout standard_metadata_t standard_metadata) {

    state start {
        transition parse_ethernet;
    }

    state parse_ethernet {
        packet.extract(hdr.ethernet);
        transition select(hdr.ethernet.etherType) {
            TYPE_SRCROUTING: parse_srcRouting;
            TYPE_IPV4: parse_ipv4;
            default: accept;
        }
    }

    state parse_srcRouting {
        packet.extract(hdr.srcRoutes.next);
        transition select(hdr.srcRoutes.last.bos) {
            0: parse_srcRouting; 
            1: parse_ipv4;
            default: accept;
        }
    }

   state parse_ipv4 {
        packet.extract(hdr.ipv4);
        transition select(hdr.ipv4.protocol){
            TYPE_TCP: tcp;
            default: accept;
        }
    }

    state tcp {
       packet.extract(hdr.tcp);
       transition accept;
    }


}

/*************************************************************************
************   C H E C K S U M    V E R I F I C A T I O N   *************
*************************************************************************/

control MyVerifyChecksum(inout headers hdr, inout metadata meta) {
    apply {  }
}

/*************************************************************************
**************  I N G R E S S   P R O C E S S I N G   *******************
*************************************************************************/

control MyIngress(inout headers hdr,
                  inout metadata meta,
                  inout standard_metadata_t standard_metadata) {

    action drop() {
        mark_to_drop(standard_metadata);
    }

    action srcRoute_nhop() {
        // Set the egress port based on the top of the stack
        standard_metadata.egress_spec = (bit<9>)hdr.srcRoutes[0].port;
        // Pop the top entry from the stack
        hdr.srcRoutes.pop_front(1);
    }

    action srcRoute_finish() {
        // Change the Ethernet type to IPv4 when the stack is exhausted
        hdr.ethernet.etherType = TYPE_IPV4;
    }

    action update_ttl() {
        // Decrement the TTL field in the IPv4 header
        hdr.ipv4.ttl = hdr.ipv4.ttl - 1;
    }

action append_2_tags(bit<32> route_data) {
    // Set Ethernet type to source routing
    hdr.ethernet.etherType = TYPE_SRCROUTING;

    // Always set both route entries (controller guarantees 2 hops)
    hdr.srcRoutes[0].setValid();
    hdr.srcRoutes[0].bos = 0;  // First hop is never BOS
    hdr.srcRoutes[0].port = (bit<15>)(route_data & 0x7FFF);
    
    hdr.srcRoutes[1].setValid();
    hdr.srcRoutes[1].bos = 1;  // Second hop is always BOS
    hdr.srcRoutes[1].port = (bit<15>)((route_data >> 16) & 0x7FFF);
    
    // Immediately forward to first hop
    srcRoute_nhop();
}

action append_3_tags(bit<48> route_data) {
    // Set Ethernet type to source routing
    hdr.ethernet.etherType = TYPE_SRCROUTING;

    // Always set both route entries (controller guarantees 2 hops)
    hdr.srcRoutes[0].setValid();
    hdr.srcRoutes[0].bos = 0;  // First hop is never BOS
    hdr.srcRoutes[0].port = (bit<15>)(route_data & 0x7FFF);
    
    hdr.srcRoutes[1].setValid();
    hdr.srcRoutes[1].bos = 0;  // Second hop is always BOS
    hdr.srcRoutes[1].port = (bit<15>)((route_data >> 16) & 0x7FFF);

    hdr.srcRoutes[2].setValid();
    hdr.srcRoutes[2].bos = 1;  // Second hop is always BOS
    hdr.srcRoutes[2].port = (bit<15>)((route_data >> 32) & 0x7FFF);
    
    // Immediately forward to first hop
    srcRoute_nhop();
}

action append_4_tags(bit<64> route_data) {
    // Set Ethernet type to source routing
    hdr.ethernet.etherType = TYPE_SRCROUTING;

    // Always set both route entries (controller guarantees 2 hops)
    hdr.srcRoutes[0].setValid();
    hdr.srcRoutes[0].bos = 0;  // First hop is never BOS
    hdr.srcRoutes[0].port = (bit<15>)(route_data & 0x7FFF);
    
    hdr.srcRoutes[1].setValid();
    hdr.srcRoutes[1].bos = 0;  // Second hop is always BOS
    hdr.srcRoutes[1].port = (bit<15>)((route_data >> 16) & 0x7FFF);

    hdr.srcRoutes[2].setValid();
    hdr.srcRoutes[2].bos = 0;  // Second hop is always BOS
    hdr.srcRoutes[2].port = (bit<15>)((route_data >> 32) & 0x7FFF);

    hdr.srcRoutes[3].setValid();
    hdr.srcRoutes[3].bos = 1;  // Second hop is always BOS
    hdr.srcRoutes[3].port = (bit<15>)((route_data >> 48) & 0x7FFF);
    
    // Immediately forward to first hop
    srcRoute_nhop();
}

action append_5_tags(bit<80> route_data) {
    // Set Ethernet type to source routing
    hdr.ethernet.etherType = TYPE_SRCROUTING;

    // Always set both route entries (controller guarantees 2 hops)
    hdr.srcRoutes[0].setValid();
    hdr.srcRoutes[0].bos = 0;  // First hop is never BOS
    hdr.srcRoutes[0].port = (bit<15>)(route_data & 0x7FFF);
    
    hdr.srcRoutes[1].setValid();
    hdr.srcRoutes[1].bos = 0;  // Second hop is always BOS
    hdr.srcRoutes[1].port = (bit<15>)((route_data >> 16) & 0x7FFF);

    hdr.srcRoutes[2].setValid();
    hdr.srcRoutes[2].bos = 0;  // Second hop is always BOS
    hdr.srcRoutes[2].port = (bit<15>)((route_data >> 32) & 0x7FFF);

    hdr.srcRoutes[3].setValid();
    hdr.srcRoutes[3].bos = 0;  // Second hop is always BOS
    hdr.srcRoutes[3].port = (bit<15>)((route_data >> 48) & 0x7FFF);

    hdr.srcRoutes[4].setValid();
    hdr.srcRoutes[4].bos = 1;  // Second hop is always BOS
    hdr.srcRoutes[4].port = (bit<15>)((route_data >> 64) & 0x7FFF);
    
    // Immediately forward to first hop
    srcRoute_nhop();
}

action append_6_tags(bit<96> route_data) {
    // Set Ethernet type to source routing
    hdr.ethernet.etherType = TYPE_SRCROUTING;

    // Always set both route entries (controller guarantees 2 hops)
    hdr.srcRoutes[0].setValid();
    hdr.srcRoutes[0].bos = 0;  // First hop is never BOS
    hdr.srcRoutes[0].port = (bit<15>)(route_data & 0x7FFF);
    
    hdr.srcRoutes[1].setValid();
    hdr.srcRoutes[1].bos = 0;  // Second hop is always BOS
    hdr.srcRoutes[1].port = (bit<15>)((route_data >> 16) & 0x7FFF);

    hdr.srcRoutes[2].setValid();
    hdr.srcRoutes[2].bos = 0;  // Second hop is always BOS
    hdr.srcRoutes[2].port = (bit<15>)((route_data >> 32) & 0x7FFF);

    hdr.srcRoutes[3].setValid();
    hdr.srcRoutes[3].bos = 0;  // Second hop is always BOS
    hdr.srcRoutes[3].port = (bit<15>)((route_data >> 48) & 0x7FFF);

    hdr.srcRoutes[4].setValid();
    hdr.srcRoutes[4].bos = 0;  // Second hop is always BOS
    hdr.srcRoutes[4].port = (bit<15>)((route_data >> 64) & 0x7FFF);

    hdr.srcRoutes[5].setValid();
    hdr.srcRoutes[5].bos = 1;  // Second hop is always BOS
    hdr.srcRoutes[5].port = (bit<15>)((route_data >> 80) & 0x7FFF);
    
    // Immediately forward to first hop
    srcRoute_nhop();
}

action append_7_tags(bit<112> route_data) {
    // Set Ethernet type to source routing
    hdr.ethernet.etherType = TYPE_SRCROUTING;

    // Always set both route entries (controller guarantees 2 hops)
    hdr.srcRoutes[0].setValid();
    hdr.srcRoutes[0].bos = 0;  // First hop is never BOS
    hdr.srcRoutes[0].port = (bit<15>)(route_data & 0x7FFF);
    
    hdr.srcRoutes[1].setValid();
    hdr.srcRoutes[1].bos = 0;  // Second hop is always BOS
    hdr.srcRoutes[1].port = (bit<15>)((route_data >> 16) & 0x7FFF);

    hdr.srcRoutes[2].setValid();
    hdr.srcRoutes[2].bos = 0;  // Second hop is always BOS
    hdr.srcRoutes[2].port = (bit<15>)((route_data >> 32) & 0x7FFF);

    hdr.srcRoutes[3].setValid();
    hdr.srcRoutes[3].bos = 0;  // Second hop is always BOS
    hdr.srcRoutes[3].port = (bit<15>)((route_data >> 48) & 0x7FFF);

    hdr.srcRoutes[4].setValid();
    hdr.srcRoutes[4].bos = 0;  // Second hop is always BOS
    hdr.srcRoutes[4].port = (bit<15>)((route_data >> 64) & 0x7FFF);

    hdr.srcRoutes[5].setValid();
    hdr.srcRoutes[5].bos = 0;  // Second hop is always BOS
    hdr.srcRoutes[5].port = (bit<15>)((route_data >> 80) & 0x7FFF);

    hdr.srcRoutes[6].setValid();
    hdr.srcRoutes[6].bos = 1;  // Second hop is always BOS
    hdr.srcRoutes[6].port = (bit<15>)((route_data >> 96) & 0x7FFF);
    
    // Immediately forward to first hop
    srcRoute_nhop();
}

action append_8_tags(bit<128> route_data) {
    // Set Ethernet type to source routing
    hdr.ethernet.etherType = TYPE_SRCROUTING;

    // Always set both route entries (controller guarantees 2 hops)
    hdr.srcRoutes[0].setValid();
    hdr.srcRoutes[0].bos = 0;  // First hop is never BOS
    hdr.srcRoutes[0].port = (bit<15>)(route_data & 0x7FFF);
    
    hdr.srcRoutes[1].setValid();
    hdr.srcRoutes[1].bos = 0;  // Second hop is always BOS
    hdr.srcRoutes[1].port = (bit<15>)((route_data >> 16) & 0x7FFF);

    hdr.srcRoutes[2].setValid();
    hdr.srcRoutes[2].bos = 0;  // Second hop is always BOS
    hdr.srcRoutes[2].port = (bit<15>)((route_data >> 32) & 0x7FFF);

    hdr.srcRoutes[3].setValid();
    hdr.srcRoutes[3].bos = 0;  // Second hop is always BOS
    hdr.srcRoutes[3].port = (bit<15>)((route_data >> 48) & 0x7FFF);

    hdr.srcRoutes[4].setValid();
    hdr.srcRoutes[4].bos = 0;  // Second hop is always BOS
    hdr.srcRoutes[4].port = (bit<15>)((route_data >> 64) & 0x7FFF);

    hdr.srcRoutes[5].setValid();
    hdr.srcRoutes[5].bos = 0;  // Second hop is always BOS
    hdr.srcRoutes[5].port = (bit<15>)((route_data >> 80) & 0x7FFF);

    hdr.srcRoutes[6].setValid();
    hdr.srcRoutes[6].bos = 1;  // Second hop is always BOS
    hdr.srcRoutes[6].port = (bit<15>)((route_data >> 96) & 0x7FFF);

    hdr.srcRoutes[7].setValid();
    hdr.srcRoutes[7].bos = 1;  // Second hop is always BOS
    hdr.srcRoutes[7].port = (bit<15>)((route_data >> 112) & 0x7FFF);
    
    // Immediately forward to first hop
    srcRoute_nhop();
}

action append_9_tags(bit<144> route_data) {
    // Set Ethernet type to source routing
    hdr.ethernet.etherType = TYPE_SRCROUTING;

    // Always set both route entries (controller guarantees 2 hops)
    hdr.srcRoutes[0].setValid();
    hdr.srcRoutes[0].bos = 0;  // First hop is never BOS
    hdr.srcRoutes[0].port = (bit<15>)(route_data & 0x7FFF);
    
    hdr.srcRoutes[1].setValid();
    hdr.srcRoutes[1].bos = 0;  // Second hop is always BOS
    hdr.srcRoutes[1].port = (bit<15>)((route_data >> 16) & 0x7FFF);

    hdr.srcRoutes[2].setValid();
    hdr.srcRoutes[2].bos = 0;  // Second hop is always BOS
    hdr.srcRoutes[2].port = (bit<15>)((route_data >> 32) & 0x7FFF);

    hdr.srcRoutes[3].setValid();
    hdr.srcRoutes[3].bos = 0;  // Second hop is always BOS
    hdr.srcRoutes[3].port = (bit<15>)((route_data >> 48) & 0x7FFF);

    hdr.srcRoutes[4].setValid();
    hdr.srcRoutes[4].bos = 0;  // Second hop is always BOS
    hdr.srcRoutes[4].port = (bit<15>)((route_data >> 64) & 0x7FFF);

    hdr.srcRoutes[5].setValid();
    hdr.srcRoutes[5].bos = 0;  // Second hop is always BOS
    hdr.srcRoutes[5].port = (bit<15>)((route_data >> 80) & 0x7FFF);

    hdr.srcRoutes[6].setValid();
    hdr.srcRoutes[6].bos = 0;  // Second hop is always BOS
    hdr.srcRoutes[6].port = (bit<15>)((route_data >> 96) & 0x7FFF);

    hdr.srcRoutes[7].setValid();
    hdr.srcRoutes[7].bos = 0;  // Second hop is always BOS
    hdr.srcRoutes[7].port = (bit<15>)((route_data >> 112) & 0x7FFF);

    hdr.srcRoutes[8].setValid();
    hdr.srcRoutes[8].bos = 1;  // Second hop is always BOS
    hdr.srcRoutes[8].port = (bit<15>)((route_data >> 128) & 0x7FFF);
    
    // Immediately forward to first hop
    srcRoute_nhop();
}
    register<bit<BLOOM_FILTER_BIT_WIDTH>>(BLOOM_FILTER_ENTRIES) bloom_filter_1;
    register<bit<BLOOM_FILTER_BIT_WIDTH>>(BLOOM_FILTER_ENTRIES) bloom_filter_2;
    bit<32> reg_pos_one; bit<32> reg_pos_two;
    bit<1> reg_val_one; bit<1> reg_val_two;
    bit<1> direction;
    action set_direction(bit<1> dir) {
        direction = dir;
    }

    table check_ports {
        key = {
            standard_metadata.ingress_port: exact;
            standard_metadata.egress_spec: exact;
        }
        actions = {
            set_direction;
            NoAction;
        }
        size = 1024;
        default_action = NoAction();
    }


    action compute_hashes(ip4Addr_t ipAddr1, ip4Addr_t ipAddr2, bit<16> port1, bit<16> port2){
       //Get register position
       hash(reg_pos_one, HashAlgorithm.crc16, (bit<32>)0, {ipAddr1,
                                                           ipAddr2,
                                                           port1,
                                                           port2,
                                                           hdr.ipv4.protocol},
                                                           (bit<32>)BLOOM_FILTER_ENTRIES);

       hash(reg_pos_two, HashAlgorithm.crc32, (bit<32>)0, {ipAddr1,
                                                           ipAddr2,
                                                           port1,
                                                           port2,
                                                           hdr.ipv4.protocol},
                                                           (bit<32>)BLOOM_FILTER_ENTRIES);
    }


    table ipv4_lpm {
        key = {
            hdr.ipv4.dstAddr: lpm;
        }
        actions = {
            append_2_tags;
            append_3_tags;
            append_4_tags;
            append_5_tags;
            append_6_tags;
            append_7_tags;
            append_8_tags;
            append_9_tags;
            drop;
        }

        @name("ipv4_lpm_counter")
        counters = direct_counter(CounterType.packets);
        default_action = drop();
    }



    apply {
            if (hdr.srcRoutes[0].isValid()) {
            if (hdr.srcRoutes[0].bos == 1) {
                srcRoute_finish(); // Final hop: change EtherType to IPv4
            }
            srcRoute_nhop(); // Forward to the next hop
        }        
            else if (hdr.ipv4.isValid()){
                ipv4_lpm.apply();
            } 
            
            else {
                drop(); // Drop packets without valid srcRoutes
            }

                direction = 0; // default
                if (check_ports.apply().hit) {
                    // test and set the bloom filter
                    if (direction == 0) {
                        compute_hashes(hdr.ipv4.srcAddr, hdr.ipv4.dstAddr, hdr.tcp.srcPort, hdr.tcp.dstPort);
                    }
                    else {
                        compute_hashes(hdr.ipv4.dstAddr, hdr.ipv4.srcAddr, hdr.tcp.dstPort, hdr.tcp.srcPort);
                    }
                    // Packet comes from internal network
                    if (direction == 0){
                        // If there is a syn we update the bloom filter and add the entry
                        if (hdr.tcp.syn == 1){
                            bloom_filter_1.write(reg_pos_one, 1);
                            bloom_filter_2.write(reg_pos_two, 1);
                        }
                    }
                    // Packet comes from outside
                    else if (direction == 1){
                        // Read bloom filter cells to check if there are 1's
                        bloom_filter_1.read(reg_val_one, reg_pos_one);
                        bloom_filter_2.read(reg_val_two, reg_pos_two);
                        // only allow flow to pass if both entries are set
                        if (reg_val_one != 1 || reg_val_two != 1){
                            drop();
                        }
                    }
                }




    }
}

/*************************************************************************
****************  E G R E S S   P R O C E S S I N G   *******************
*************************************************************************/

control MyEgress(inout headers hdr,
                 inout metadata meta,
                 inout standard_metadata_t standard_metadata) {
    apply {  }
}

/*************************************************************************
*************   C H E C K S U M    C O M P U T A T I O N   **************
*************************************************************************/

control MyComputeChecksum(inout headers hdr, inout metadata meta) {
    apply {  }
}

/*************************************************************************
***********************  D E P A R S E R  *******************************
*************************************************************************/

control MyDeparser(packet_out packet, in headers hdr) {
    apply {
        packet.emit(hdr.ethernet);
        packet.emit(hdr.srcRoutes); // Emit the stacked srcRoute_t headers
        packet.emit(hdr.ipv4);
        packet.emit(hdr.tcp);
    }
}

/*************************************************************************
***********************  S W I T C H  *******************************
*************************************************************************/

V1Switch(
MyParser(),
MyVerifyChecksum(),
MyIngress(),
MyEgress(),
MyComputeChecksum(),
MyDeparser()
) main;