#ifndef _PAYLOAD_REQUEST_
#define _PAYLOAD_REQUEST_

#include "../include/types.p4"

control PayloadRequest(inout headers_t hdr, in bit<24> sequence_number) {
    /* RDMA READ Action */
    action send_rdma_read_request() {
        hdr.ethernet.setValid();

        /* Chosen RDMA Server MAC Address */
        hdr.ethernet.dst_addr_1 = hdr.bridge_payload.server_mac_addr_1;
        hdr.ethernet.dst_addr_2 = hdr.bridge_payload.server_mac_addr_2;
        /* Fake MAC Address as source */
        hdr.ethernet.src_addr = 0x000000000001;
        hdr.ethernet.ether_type = ether_type_t.IPV4;

        hdr.ipv4.setValid();
        hdr.ipv4.version = 4;
        hdr.ipv4.ihl = 5;
        hdr.ipv4.flags = 2;
        hdr.ipv4.protocol = ipv4_protocol_t.UDP;

        /* Static RDMA Client IP Address where the connection is opened */
        hdr.ipv4.src_addr = RDMA_IP;
        /* Chosen RDMA Server IP Address */
        hdr.ipv4.dst_addr = hdr.bridge_payload.server_ip_addr;
        hdr.ipv4.ttl = 64;
        hdr.ipv4.total_len = hdr.ipv4.minSizeInBytes() + hdr.udp.minSizeInBytes() + hdr.ib_bth.minSizeInBytes() + hdr.ib_reth.minSizeInBytes() + 4;

        hdr.udp.setValid();
        hdr.udp.src_port = 0;
        hdr.udp.dst_port = UDP_PORT_ROCEV2;
        hdr.udp.checksum = 0;
        hdr.udp.length = hdr.udp.minSizeInBytes() + hdr.ib_bth.minSizeInBytes() + hdr.ib_reth.minSizeInBytes() + 4;

        hdr.ib_bth.setValid();
        hdr.ib_bth.opcode = ib_opcode_t.RDMA_READ;
        hdr.ib_bth.se = 0;
        hdr.ib_bth.migration_req = 1;
        hdr.ib_bth.pad_count = 0;
        hdr.ib_bth.transport_version = 0;
        hdr.ib_bth.partition_key = 0xffff;
        hdr.ib_bth.reserved = 0;
        hdr.ib_bth.ack = 1;
        hdr.ib_bth.reserved2 = 0;
        hdr.ib_bth.psn = sequence_number;

        hdr.ib_reth.setValid();
        hdr.ib_reth.addr = hdr.payload_splitter.payload_address;
        hdr.ib_reth.remote_key = hdr.bridge_payload.r_key;
        hdr.ib_reth.dma_len1 = 0;
        hdr.ib_reth.dma_len2 = hdr.payload_splitter.payload_len;

        hdr.payload_splitter.setInvalid();
        hdr.bridge_payload.setInvalid();
    }

    apply {
        send_rdma_read_request();
    }
}

#endif /* _PAYLOAD_REQUEST_ */