#ifndef _DEFAULT_SWITCH_
#define _DEFAULT_SWITCH_

#include "../include/configuration.p4"
#include "../ingress_controls/switch_to_nf.p4"

control DefaultSwitch(inout headers_t hdr,
                      in ingress_intrinsic_metadata_t ig_intr_md,
                      inout ingress_intrinsic_metadata_for_deparser_t ig_dprsr_md,
                      inout ingress_intrinsic_metadata_for_tm_t ig_tm_md) {
    action forward_to_nf() {
        ig_tm_md.ucast_egress_port = NF_PORT;

        hdr.ethernet.src_addr[7:0] = 0x0;
    }

    action drop() {
        ig_dprsr_md.drop_ctl = 0x1;
    }

    @ternary(1)
    table forwarding {
        key = {
            ig_intr_md.ingress_port: exact;
        }
        actions = {
            forward_to_nf;
            @defaultonly drop;
        }
        size = 4;
        default_action = drop;
        const entries = {
            OUTPUT_1_PORT: forward_to_nf();
            OUTPUT_2_PORT: forward_to_nf();
            OUTPUT_3_PORT: forward_to_nf();
            OUTPUT_4_PORT: forward_to_nf();
        }
    }

    Random<bit<2>>() random_gen;
    apply {
        /* Do not process this packet on the egress */
        ig_tm_md.bypass_egress = 0x1;

        if (ig_intr_md.ingress_port == NF_PORT) {
            bit<2> random_port = random_gen.get();

            if (random_port == 0) {
                ig_tm_md.ucast_egress_port = OUTPUT_1_PORT;
            } else if (random_port == 1) {
                ig_tm_md.ucast_egress_port = OUTPUT_2_PORT;
            } else if (random_port == 2) {
                ig_tm_md.ucast_egress_port = OUTPUT_3_PORT;
            } else if (random_port == 3) {
                ig_tm_md.ucast_egress_port = OUTPUT_4_PORT;
            }
        } else {
            forwarding.apply();
        }
    }
}

#endif /* _DEFAULT_SWITCH_ */