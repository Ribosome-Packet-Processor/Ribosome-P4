#ifndef _QP_RESTORE_
#define _QP_RESTORE_

#include "../include/types.p4"

control QPRestore(inout headers_t hdr, inout eg_metadata_t meta) {
    apply {
        hdr.ethernet.dst_addr_1 = meta.mirror_qp_restore.server_mac_addr_1;
        hdr.ethernet.dst_addr_2 = meta.mirror_qp_restore.server_mac_addr_2;
        hdr.ethernet.src_addr = 0x000000000001;
        hdr.ethernet.ether_type = ether_type_t.CLIENT_QP_REFRESH;
        hdr.qp_restore.setValid();
        hdr.qp_restore.index = meta.mirror_qp_restore.qp_index;

        /* Disable all the headers */
        hdr.ipv4.setInvalid();
        hdr.tcp.setInvalid();
        hdr.udp.setInvalid();
        hdr.payload_splitter.setInvalid();
        hdr.bridge_payload.setInvalid();
        hdr.ib_bth.setInvalid();
        hdr.ib_reth.setInvalid();
        hdr.ib_aeth.setInvalid();
        hdr.payload_request.setInvalid();
    }
}

#endif /* _QP_RESTORE_ */