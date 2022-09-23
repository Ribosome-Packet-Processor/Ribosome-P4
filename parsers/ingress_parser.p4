#ifndef _INGRESS_PARSER_
#define _INGRESS_PARSER_

#include "configuration.p4"

parser IngressParser(packet_in pkt, out headers_t hdr, out ig_metadata_t meta, out ingress_intrinsic_metadata_t ig_intr_md) {
    /* This is a mandatory state, required by Tofino Architecture */
    state start {
        pkt.extract(ig_intr_md);
        pkt.advance(PORT_METADATA_SIZE);
        meta.l4_lookup = {0, 0};
        transition select(ig_intr_md.ingress_port) {
            NF_PORT: check_if_split;
            default: parse_ethernet;
        }
    }

    state check_if_split {
        /* First bit of Ethernet is 1 if we split the packet */
        meta.is_split = pkt.lookahead<bit<48>>()[7:0];
        /* Split in chunks only if it was originally split */
        transition select(meta.is_split) {
            0x1: parse_chunks;
            default: accept;
        }
    }

    state parse_chunks {
        pkt.extract(hdr.hdr_chunks);
        transition select(hdr.hdr_chunks.blk_5[7:0]) {
            ipv4_protocol_t.UDP: parse_payload_splitter_marker;
            ipv4_protocol_t.TCP: parse_chunks_tcp;
            default: accept;
        }
    }

    state parse_chunks_tcp {
        pkt.extract(hdr.hdr_chunks_tcp);
        transition parse_payload_splitter_marker;
    }

    state parse_payload_splitter_marker {
        transition select(pkt.lookahead<bit<32>>()) {
            PAYLOAD_SPLITTER_MARKER: parse_payload_splitter;
            default: accept;
        }
    }

    state parse_payload_splitter {
        pkt.extract(hdr.payload_splitter);
        transition parse_payload_request;
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
            rdma_info_code_t.MEM: parse_rdma_mem_info;
            rdma_info_code_t.ETH: parse_rdma_eth_info;
            default: accept;
        }
    }

    state parse_rdma_qp_info {
        pkt.extract(hdr.rdma_qp_info);
        transition accept;
    }

    state parse_rdma_mem_info {
        pkt.extract(hdr.rdma_mem_info);
        transition accept;
    }

    state parse_rdma_eth_info {
        pkt.extract(hdr.rdma_eth_info);
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
        meta.l4_lookup = { hdr.tcp.src_port, hdr.tcp.dst_port };
        transition check_ip_len;
    }

    state parse_udp {
        pkt.extract(hdr.udp);
        meta.l4_lookup = { hdr.udp.src_port, hdr.udp.dst_port };
        transition select(hdr.udp.dst_port) {
            UDP_PORT_ROCEV2: parse_ib_bth;
            default: check_ip_len;
        }
    }

    state check_ip_len {
        transition select(hdr.ipv4.total_len) {
            #if SPLIT==64
                0x003F &&& 0xFFC0: dont_split; // <= 63
                0x0040: dont_split; // == 64
            #elif SPLIT==128
                0x007F &&& 0xFF80: dont_split; // <= 127
                0x0080: dont_split; // == 128
            #elif SPLIT==256
                0x00FF &&& 0xFF00: dont_split; // <= 255
                0x0100: dont_split; // == 256
            #elif SPLIT==512
                0x01FF &&& 0xFE00: dont_split; // <= 511
                0x0200: dont_split; // == 512
            #elif SPLIT==1024
                0x03FF &&& 0xFC00: dont_split; // <= 1023
                0x0400: dont_split; // == 1024
            #endif
            default: split;
        }
    }

    state dont_split {
        meta.to_split = 0x0;
        transition accept;
    }

    state split {
        meta.to_split = 0x1;
        transition accept;
    }

    state parse_ib_bth {
        meta.to_split = 0x1;
        pkt.extract(hdr.ib_bth);
        transition select(hdr.ib_bth.opcode) {
            ib_opcode_t.RDMA_ACK: parse_ib_aeth;
            ib_opcode_t.RDMA_READ_RESPONSE: parse_ib_aeth;
            default: accept;
        }
    }

    state parse_ib_aeth {
        pkt.extract(hdr.ib_aeth);
        transition parse_payload_request;
    }

    state parse_payload_request {
        pkt.extract(hdr.payload_request);
        transition select(hdr.payload_request.padding) {
            1: parse_padding_1;
            2: parse_padding_2;
            3: parse_padding_3;
            default: accept;
        }
    }

    state parse_padding_1 {
        pkt.extract(hdr.padding_1);
        transition accept;
    }

    state parse_padding_2 {
        pkt.extract(hdr.padding_2);
        transition accept;
    }

    state parse_padding_3 {
        pkt.extract(hdr.padding_3);
        transition accept;
    }
}

control IngressDeparser(packet_out pkt, inout headers_t hdr, in ig_metadata_t meta,
                        in ingress_intrinsic_metadata_for_deparser_t ig_dprsr_md) {
    Mirror() mirror;

    apply {
        if (ig_dprsr_md.mirror_type == TRUNCATE_MIRROR_TYPE) {
            mirror.emit<mirror_truncate_h>(meta.mirror_session, {
                meta.packet_type,
                meta.payload_addr,
                meta.payload_len,
                meta.hdr_idx,
                meta.server_qp_index,
                meta.server_index
            });
        } else if (ig_dprsr_md.mirror_type == QP_RESTORE_MIRROR_TYPE) {
            mirror.emit<mirror_qp_restore_h>(meta.mirror_session, {
                meta.packet_type,
                meta.server_mac_addr_1,
                meta.server_mac_addr_2,
                meta.restore_qp_index
            });
        }

        pkt.emit(hdr);
    }
}

#endif /* _INGRESS_PARSER_ */