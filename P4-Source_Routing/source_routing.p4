// SPDX-License-Identifier: Apache-2.0
/* -*- P4_16 -*- */
#include <core.p4>
#include <v1model.p4>

const bit<16> TYPE_IPV4 = 0x800;
const bit<16> TYPE_SRCROUTING = 0x1234;

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

struct metadata {
}

struct headers {
    ethernet_t              ethernet;
    srcRoute_t[MAX_HOPS]    srcRoutes; // header stack
    ipv4_t                  ipv4;
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
            default: accept;
        }
    }

    state parse_ipv4 {
        packet.extract(hdr.ipv4);
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
        if (hdr.ipv4.isValid()) {
            // Match the IPv4 destination address in the LPM table
            ipv4_lpm.apply();
        } else if (hdr.srcRoutes[0].isValid()) {
            if (hdr.srcRoutes[0].bos == 1) {
                srcRoute_finish(); // Final hop: change EtherType to IPv4
            }
            srcRoute_nhop(); // Forward to the next hop
        } else {
                drop(); // Drop packets without valid srcRoutes
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