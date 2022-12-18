/* -*- P4_16 -*- */

#include <core.p4>
#include <tna.p4>

#include "include/headers.p4"
#include "include/registers.p4"

#include "parsers/ingress_parser.p4"
#include "parsers/egress_parser.p4"

#include "ingress_controls/default_switch.p4"
#include "ingress_controls/switch_to_nf.p4"
#include "ingress_controls/store_rdma_qp_info.p4"
#include "ingress_controls/store_rdma_mem_info.p4"
#include "ingress_controls/store_rdma_eth_info.p4"
#include "ingress_controls/payload_split.p4"
#include "ingress_controls/store_header.p4"
#include "ingress_controls/payload_request_bridge.p4"
#include "ingress_controls/packet_reconstruct.p4"
#include "ingress_controls/qp_restore_mirror.p4"

#include "egress_controls/store_qp_seq_n.p4"
#include "egress_controls/truncate_headers.p4"
#include "egress_controls/ib_len_fix.p4"
#include "egress_controls/payload_request.p4"
#include "egress_controls/qp_restore.p4"

/* INGRESS */
control Ingress(inout headers_t hdr, inout ig_metadata_t meta, in ingress_intrinsic_metadata_t ig_intr_md,
                in ingress_intrinsic_metadata_from_parser_t ig_prsr_md,
                inout ingress_intrinsic_metadata_for_deparser_t ig_dprsr_md,
                inout ingress_intrinsic_metadata_for_tm_t ig_tm_md) {
    DefaultSwitch() default_switch;
    SwitchToNF() switch_to_nf;
    StoreRDMAQPInfo() store_rdma_qp_info;
    StoreRDMAMemInfo() store_rdma_mem_info;
    StoreRDMAEthInfo() store_rdma_eth_info;
    PayloadSplit() payload_split;
    StoreHeader() store_header;
    PayloadRequestBridge() payload_request_bridge;
    PacketReconstruct() packet_reconstruct;
    QPRestoreMirror() qp_restore_mirror;

    /* Server Information Read */
    RegisterAction<bit<16>, _, bit<16>>(server_mac_address_1) server_mac_address_1_read = {
        void apply(inout bit<16> value, out bit<16> read_value) {
            read_value = value;
        }
    };
    RegisterAction<bit<32>, _, bit<32>>(server_mac_address_2) server_mac_address_2_read = {
        void apply(inout bit<32> value, out bit<32> read_value) {
            read_value = value;
        }
    };
    RegisterAction<ipv4_addr_t, _, ipv4_addr_t>(server_ip_address) server_ip_address_read = {
        void apply(inout ipv4_addr_t value, out ipv4_addr_t read_value) {
            read_value = value;
        }
    };
    RegisterAction<bit<16>, _, PortId_t>(server_port) server_port_read = {
        void apply(inout bit<16> value, out PortId_t read_value) {
            read_value = (PortId_t) value;
        }
    };

    /* QP Enable/Disable/Restore Actions */
    RegisterAction<bit<16>, _, bit<16>>(enabled_qp) disable_qp = {
        void apply(inout bit<16> value, out bit<16> read_value) {
            value = 0;
        }
    };
    RegisterAction<bit<16>, _, bit<16>>(enabled_qp) enabled_qp_read = {
        void apply(inout bit<16> value, out bit<16> read_value) {
            read_value = value;

            if (value > 1) {
                value = value - 1;
            }
        }
    };
    RegisterAction<bit<1>, _, bit<1>>(restore_qp) restore_qp_read = {
        void apply(inout bit<1> value, out bit<1> read_value) {
            read_value = value;
            value = 0;
        }
    };

    /* QP Read Action */
    RegisterAction<bit<32>, _, bit<24>>(qp) qp_read = {
        void apply(inout bit<32> value, out bit<24> read_value) {
            read_value = value[23:0];
        }
    };

    /* Remote Key Read Action */
    RegisterAction<bit<32>, _, bit<32>>(remote_key) remote_key_read = {
        void apply(inout bit<32> value, out bit<32> read_value) {
            read_value = value;
        }
    };

    bit<16> current_server_idx;
    bit<16> current_qp_index;
    bit<16> tmp_qp;
    action to_qp_and_server(bit<16> selected_qp, bit<16> selected_server) {
        tmp_qp = selected_qp;
        current_server_idx = selected_server;
    }

    Hash<bit<8>>(HashAlgorithm_t.CRC16) qp_mapping_hash;
    ActionProfile(size=TOTAL_QP) qp_mapping_profile;
    ActionSelector(
        action_profile = qp_mapping_profile,
        hash = qp_mapping_hash,
        mode = SelectorMode_t.FAIR,
        max_group_size = TOTAL_QP,
        num_groups = 1
    ) qp_mapping_sel;

    table qp_mapping {
        key = {
            meta.to_split: exact;
            hdr.ipv4.src_addr: selector;
            hdr.ipv4.dst_addr: selector;
            hdr.ipv4.protocol: selector;
            meta.l4_lookup.src_port: selector;
            meta.l4_lookup.dst_port: selector;
        }
        actions = {
            to_qp_and_server;
        }
        size = 1;
        implementation = qp_mapping_sel;
    }

    action send(PortId_t port) {
        ig_tm_md.ucast_egress_port = port;
        ig_tm_md.bypass_egress = 0x1;
    }

    action drop() {
        ig_dprsr_md.drop_ctl = 0x1;
    }

    table blacklist {
        key = {
            hdr.ipv4.dst_addr: lpm;
        }
        actions = {
            send;
            drop;
        }
        size = 1024;
    }

    apply {
        if (!hdr.rdma_info.isValid() && meta.is_split == 0 && meta.to_split == 0) {
            default_switch.apply(hdr, ig_intr_md, ig_dprsr_md, ig_tm_md);
        } else if (hdr.rdma_info.isValid()) {
            if (hdr.rdma_qp_info.isValid()) {
                store_rdma_qp_info.apply(hdr);

                /* Assign a port in order to move this packet on the egress */
                ig_tm_md.ucast_egress_port = SERVER_1_PORT;
            } else if (hdr.rdma_mem_info.isValid()) {
                store_rdma_mem_info.apply(hdr);

                /* Drop this packet */
                ig_dprsr_md.drop_ctl = 0x1;
            } else if (hdr.rdma_eth_info.isValid()) {
                store_rdma_eth_info.apply(hdr, ig_intr_md);

                /* Drop this packet */
                ig_dprsr_md.drop_ctl = 0x1;
            }
        } else if (hdr.ib_aeth.isValid() && hdr.ib_aeth.opcode == 0x03) {
            disable_qp.execute(hdr.ib_bth.dst_qp);
        } else if (blacklist.apply().hit) {

        } else {
            PortId_t server_port_idx = 0;
            bit<16> server_mac_addr_1 = 0;
            bit<32> server_mac_addr_2 = 0;
            ipv4_addr_t server_ip_addr = 0;
            bit<16> enabled_queue = 0;
            bit<32> rkey = 0;
            bit<24> queue_pair = 0;
            if ((hdr.ipv4.isValid() && !hdr.ib_bth.isValid()) ||
                (hdr.hdr_chunks.isValid() && hdr.payload_splitter.isValid())) {
                if (hdr.ipv4.isValid() && !hdr.ib_bth.isValid()) {
                    qp_mapping.apply();
                    current_qp_index = tmp_qp;
                } else if (hdr.hdr_chunks.isValid() && hdr.payload_splitter.isValid()) {
                    current_qp_index = hdr.payload_splitter.server_qp_index;
                    current_server_idx = hdr.payload_splitter.server_index;
                }

                server_port_idx = server_port_read.execute(current_server_idx);
                server_mac_addr_1 = server_mac_address_1_read.execute(current_server_idx);
                server_mac_addr_2 = server_mac_address_2_read.execute(current_server_idx);

                enabled_queue = enabled_qp_read.execute(current_qp_index);
                if (enabled_queue == 1) {
                    server_ip_addr = server_ip_address_read.execute(current_server_idx);
                    rkey = remote_key_read.execute(current_server_idx);
                    queue_pair = qp_read.execute(current_qp_index);

                    /* Send to the chosen RDMA Server port */
                    ig_tm_md.ucast_egress_port = server_port_idx;
                } else if (enabled_queue == 0) {
                    bit<1> should_restore = restore_qp_read.execute(current_qp_index);
                    if (should_restore == 1) {
                        qp_restore_mirror.apply(hdr, meta, ig_dprsr_md,
                                                current_server_idx, server_mac_addr_1, server_mac_addr_2,
                                                current_qp_index);

                        if (ig_intr_md.ingress_port == NF_PORT) {
                            /* Drop this packet */
                            ig_dprsr_md.drop_ctl = 0x1;
                        } else {
                            /* We cannot split the packet, send it directly to the NF */
                            switch_to_nf.apply(hdr, ig_tm_md);
                        }
                    }
                }
            }

            if (hdr.ipv4.isValid() && !hdr.ib_bth.isValid()) {
                /* Packet Sender packets */
                if (enabled_queue == 1) {
                    payload_split.apply(hdr, meta, ig_dprsr_md, ig_tm_md,
                                        current_server_idx, server_mac_addr_1, server_mac_addr_2, server_ip_addr,
                                        rkey, queue_pair, current_qp_index);
                } else {
                    /* We cannot split the packet, send it directly to the NF */
                    switch_to_nf.apply(hdr, ig_tm_md);
                }
            } else if (hdr.hdr_chunks.isValid() && hdr.payload_splitter.isValid()) {
                if (enabled_queue == 1) {
                    /* Store header chunks */
                    store_header.apply(hdr, meta);

                    /* Mirror this packet on the egress and craft the RDMA READ Request */
                    payload_request_bridge.apply(hdr, server_mac_addr_1, server_mac_addr_2, server_ip_addr, rkey, queue_pair);
                } else {
                    /* We cannot reconstruct the packet, drop the headers */
                    ig_dprsr_md.drop_ctl = 0x1;
                }
            } else if (hdr.ib_bth.isValid() && hdr.ib_bth.opcode == ib_opcode_t.RDMA_READ_RESPONSE) {
                /* Received RDMA Read Response, reconstruct the original packet */
                packet_reconstruct.apply(hdr, meta, ig_intr_md, ig_tm_md);
            } else {
                default_switch.apply(hdr, ig_intr_md, ig_dprsr_md, ig_tm_md);
            }
        }
    }
}

/* EGRESS */
control Egress(inout headers_t hdr, inout eg_metadata_t meta, in egress_intrinsic_metadata_t eg_intr_md,
               in egress_intrinsic_metadata_from_parser_t eg_prsr_md,
               inout egress_intrinsic_metadata_for_deparser_t eg_dprsr_md,
               inout egress_intrinsic_metadata_for_output_port_t eg_oport_md) {
    StoreQPSeqNum() store_qp_seq_num;
    TruncateHeaders() truncate_headers;
    IBLenFix() ib_len_fix;
    PayloadRequest() payload_request;
    QPRestore() qp_restore;

    /* Sequence Number Increment Action */
    RegisterAction<bit<32>, _, bit<24>>(seq_n) seq_n_inc = {
        void apply(inout bit<32> value, out bit<24> read_value) {
            read_value = value[23:0];

            if (value >= 0x00ffffff) {
                value = 0x0;
            } else {
                value = value + 1;
            }
        }
    };

    apply {
        if (hdr.rdma_qp_info.isValid()) {
            store_qp_seq_num.apply(hdr);
            eg_dprsr_md.drop_ctl = 0x1;
        } else if (meta.mirror_truncate.isValid()) {
            /* Cloned packet, append custom headers and fix lengths */
            truncate_headers.apply(hdr, meta);
        } else if (meta.mirror_qp_restore.isValid()) {
            qp_restore.apply(hdr, meta);
        } else if (hdr.bridge_payload.isValid()) {
            bit<24> sequence_number = seq_n_inc.execute(hdr.payload_splitter.server_qp_index);
            payload_request.apply(hdr, sequence_number);
        } else {
            if (hdr.ib_bth.isValid()) {
                if (hdr.ib_bth.opcode == ib_opcode_t.RDMA_WRITE) {
                    /* hdr.ib_bth.psn contains the QP Index, see payload_split */
                    hdr.ib_bth.psn = seq_n_inc.execute(hdr.ib_bth.psn);

                    ib_len_fix.apply(hdr);
                }
            }
        }
    }
}

Pipeline(
    IngressParser(),
    Ingress(),
    IngressDeparser(),
    EgressParser(),
    Egress(),
    EgressDeparser()
) pipe;

Switch(pipe) main;
