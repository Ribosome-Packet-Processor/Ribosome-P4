#ifndef _QP_RESTORE_MIRROR_
#define _QP_RESTORE_MIRROR_

#include "../include/types.p4"

control QPRestoreMirror(inout headers_t hdr, inout ig_metadata_t meta,
                        inout ingress_intrinsic_metadata_for_deparser_t ig_dprsr_md,
                        in bit<16> current_server_idx,
                        in bit<16> server_mac_addr_1,
                        in bit<32> server_mac_addr_2,
                        in bit<16> qp_idx) {
    apply {
        meta.server_mac_addr_1 = server_mac_addr_1;
        meta.server_mac_addr_2 = server_mac_addr_2;
        meta.restore_qp_index = qp_idx;

        ig_dprsr_md.mirror_type = QP_RESTORE_MIRROR_TYPE;
        meta.mirror_session = QP_RESTORE_MIRROR_SESSION + ((bit<10>) current_server_idx);
        meta.packet_type = PKT_TYPE_MIRROR_QP_RESTORE;
    }
}

#endif /* _QP_RESTORE_MIRROR_ */