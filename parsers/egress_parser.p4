#ifndef _EGRESS_PARSER_
#define _EGRESS_PARSER_

#include "../include/configuration.p4"

/* EGRESS */
parser EgressParser(packet_in pkt, out headers_t hdr, out eg_metadata_t meta, out egress_intrinsic_metadata_t eg_intr_md) {
    /* This is a mandatory state, required by Tofino Architecture */
    state start {
        pkt.extract(eg_intr_md);
        pkt_type_t pkt_type = pkt.lookahead<pkt_type_t>();
        transition select(pkt_type) {
            PKT_TYPE_MIRROR_TRUNCATE: parse_truncate_mirror;
            PKT_TYPE_MIRROR_QP_RESTORE: parse_qp_restore_mirror;
            default: parse_payload_splitter_marker;
        }
    }

    state parse_truncate_mirror {
        pkt.extract(meta.mirror_truncate);
        transition parse_ethernet;
    }

    state parse_qp_restore_mirror {
        pkt.extract(meta.mirror_qp_restore);
        transition parse_ethernet;
    }

    state parse_payload_splitter_marker {
        transition select(pkt.lookahead<bit<32>>()) {
            PAYLOAD_SPLITTER_MARKER: parse_payload_splitter;
            default: parse_ethernet;
        }
    }

    state parse_payload_splitter {
        pkt.extract(hdr.payload_splitter);
        transition parse_bridge_payload;
    }

    state parse_bridge_payload {
        pkt.extract(hdr.bridge_payload);
        transition parse_ib_bth;
    }

    state parse_ethernet {
        pkt.extract(hdr.ethernet);
        transition select(hdr.ethernet.ether_type) {
            ether_type_t.RDMA_INFO: parse_rdma_info;
            ether_type_t.IPV4: parse_ipv4;
            default: accept;
        }
    }

    state parse_rdma_info {
        pkt.extract(hdr.rdma_info);
        transition select(hdr.rdma_info.code) {
            rdma_info_code_t.QP: parse_rdma_qp_info;
            default: reject;
        }
    }

    state parse_rdma_qp_info {
        pkt.extract(hdr.rdma_qp_info);
        transition accept;
    }

    state parse_ipv4 {
        pkt.extract(hdr.ipv4);
        transition select(hdr.ipv4.protocol) {
            ipv4_protocol_t.TCP: parse_tcp;
            ipv4_protocol_t.UDP: parse_udp;
            default: accept;
        }
    }

    state parse_tcp {
        pkt.extract(hdr.tcp);
        transition accept;
    }

    state parse_udp {
        pkt.extract(hdr.udp);
        transition select(hdr.udp.dst_port) {
            UDP_PORT_ROCEV2: parse_ib_bth;
            default: accept;
        }
    }

    state parse_ib_bth {
        pkt.extract(hdr.ib_bth);
        transition select(hdr.ib_bth.opcode) {
            ib_opcode_t.RDMA_WRITE: parse_ib_reth;
            ib_opcode_t.RDMA_READ: parse_ib_reth;
            default: accept;
        }
    }

    state parse_ib_reth {
        pkt.extract(hdr.ib_reth);
        transition accept;
    }
}

control EgressDeparser(packet_out pkt, inout headers_t hdr, in eg_metadata_t meta,
                       in egress_intrinsic_metadata_for_deparser_t eg_dprsr_md) {
    Checksum() ipv4_checksum;

    apply {
        if (hdr.ib_bth.isValid()) {
            hdr.ipv4.hdr_checksum = ipv4_checksum.update({
                hdr.ipv4.version,
                hdr.ipv4.ihl,
                hdr.ipv4.dscp,
                hdr.ipv4.ecn,
                hdr.ipv4.total_len,
                hdr.ipv4.identification,
                hdr.ipv4.flags,
                hdr.ipv4.frag_offset,
                hdr.ipv4.ttl,
                hdr.ipv4.protocol,
                hdr.ipv4.src_addr,
                hdr.ipv4.dst_addr
            });
        }

        pkt.emit(hdr);
    }
}

#endif /* _EGRESS_PARSER_ */