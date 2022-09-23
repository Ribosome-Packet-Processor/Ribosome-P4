#ifndef _SWITCH_TO_NF_
#define _SWITCH_TO_NF_

#include "../include/configuration.p4"

control SwitchToNF(inout headers_t hdr,
                   inout ingress_intrinsic_metadata_for_tm_t ig_tm_md) {
    apply {
        /* Do not process this packet on the egress */
        ig_tm_md.bypass_egress = 0x1;

        ig_tm_md.ucast_egress_port = NF_PORT;

        hdr.ethernet.src_addr[7:0] = 0x0;
    }
}

#endif /* _SWITCH_TO_NF_ */