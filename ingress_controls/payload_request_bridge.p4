#ifndef _PAYLOAD_REQUEST_BRIDGE_
#define _PAYLOAD_REQUEST_BRIDGE_

control PayloadRequestBridge(inout headers_t hdr,
                             in bit<16> server_mac_addr_1,
                             in bit<32> server_mac_addr_2,
                             in ipv4_addr_t server_ip_addr,
                             in bit<32> rdma_rkey,
                             in bit<24> destination_qp) {
    apply {
        hdr.bridge_payload.setValid();
        hdr.bridge_payload.server_mac_addr_1 = server_mac_addr_1;
        hdr.bridge_payload.server_mac_addr_2 = server_mac_addr_2;
        hdr.bridge_payload.server_ip_addr = server_ip_addr;
        hdr.bridge_payload.r_key = rdma_rkey;

        hdr.ib_bth.setValid();
        /* Set this here, but with opcode 0xff so Egress Parser accepts silently */
        hdr.ib_bth.opcode = ib_opcode_t.NOOP;
        hdr.ib_bth.dst_qp = destination_qp;
    }
}

#endif /* _PAYLOAD_REQUEST_BRIDGE_ */