#ifndef _HEADERS_
#define _HEADERS_

#include "types.p4"

/* Chunked header */
/* This is sized to contain UDP */
@pa_no_overlay("ingress", "hdr.hdr_chunks.blk_0")
@pa_no_overlay("ingress", "hdr.hdr_chunks.blk_1")
@pa_no_overlay("ingress", "hdr.hdr_chunks.blk_2")
@pa_no_overlay("ingress", "hdr.hdr_chunks.blk_3")
@pa_no_overlay("ingress", "hdr.hdr_chunks.blk_4")
@pa_no_overlay("ingress", "hdr.hdr_chunks.blk_5")
@pa_no_overlay("ingress", "hdr.hdr_chunks.blk_6")
@pa_no_overlay("ingress", "hdr.hdr_chunks.blk_7")
@pa_no_overlay("ingress", "hdr.hdr_chunks.blk_8")
@pa_no_overlay("ingress", "hdr.hdr_chunks.blk_9")
@pa_no_overlay("ingress", "hdr.hdr_chunks.blk_10")
header hdr_chunk_h {
    bit<32> blk_0;
    bit<32> blk_1;
    bit<32> blk_2;
    bit<32> blk_3;
    bit<32> blk_4;
    bit<32> blk_5;
    bit<32> blk_6;
    bit<32> blk_7;
    bit<32> blk_8;
    bit<32> blk_9;
    bit<16> blk_10;
}

@pa_no_overlay("ingress", "hdr.hdr_chunks_tcp.blk_11")
@pa_no_overlay("ingress", "hdr.hdr_chunks_tcp.blk_12")
@pa_no_overlay("ingress", "hdr.hdr_chunks_tcp.blk_13")
@pa_no_overlay("ingress", "hdr.hdr_chunks_tcp.blk_14")
header hdr_chunk_tcp_h {
    bit<16> blk_11;
    bit<32> blk_12;
    bit<32> blk_13;
    bit<16> blk_14;
}

/* Mirroring */
header mirror_truncate_h {
    pkt_type_t pkt_type;
    bit<64> payload_addr;
    bit<16> payload_len;
    bit<16> hdr_idx;
    bit<16> server_qp_index;
    bit<16> server_index;
}

header mirror_qp_restore_h {
    pkt_type_t pkt_type;
    bit<16> server_mac_addr_1;
    bit<32> server_mac_addr_2;
    bit<16> qp_index;
}

/* RDMA Info Header */
header rdma_info_h {
    rdma_info_code_t code;
}

header rdma_qp_info_h {
    bit<16> enable_timer;
    bit<16> index;
    bit<32> dst_qp;
}

header rdma_mem_info_h {
    bit<16> server_id;
    bit<32> remote_address1;
    bit<32> remote_address2;
    bit<32> remote_key;
}

header rdma_eth_info_h {
    bit<16> server_id;
    @padding bit<16> unused_bits;
    bit<16> mac_address1;
    bit<32> mac_address2;
    bit<32> ip_address;
}

/* QP Restore Header */
header qp_restore_h {
    bit<16> index;
}

/* Standard headers */
header ethernet_h {
    bit<16> dst_addr_1;
    bit<32> dst_addr_2;
    mac_addr_t src_addr;
    ether_type_t ether_type;
}

header ipv4_h {
    bit<4> version;
    bit<4> ihl;
    bit<6> dscp;
    bit<2> ecn;
    bit<16> total_len;
    bit<16> identification;
    bit<3> flags;
    bit<13> frag_offset;
    bit<8> ttl;
    ipv4_protocol_t protocol;
    bit<16> hdr_checksum;
    ipv4_addr_t src_addr;
    ipv4_addr_t dst_addr;
}

header tcp_h {
    bit<16> src_port;
    bit<16> dst_port;
    bit<32> seq_n;
    bit<32> ack_n;
    bit<4> data_offset;
    bit<4> res;
    bit<1> cwr;
    bit<1> ece;
    bit<1> urg;
    bit<1> ack;
    bit<1> psh;
    bit<1> rst;
    bit<1> syn;
    bit<1> fin;
    bit<16> window;
    bit<16> checksum;
    bit<16> urgent_ptr;
}

header udp_h {
    bit<16> src_port;
    bit<16> dst_port;
    bit<16> length;
    bit<16> checksum;
}

/* InfiniBand-RoCE Base Transport Header */
header ib_bth_h {
    ib_opcode_t opcode;
    bit<1> se;
    bit<1> migration_req;
    bit<2> pad_count;
    bit<4> transport_version;
    bit<16> partition_key;
    bit<8> reserved;
    bit<24> dst_qp;
    bit<1> ack;
    bit<7> reserved2;
    bit<24> psn;
}

/* InfiniBand-RoCE RDMA Extended Transport Header */
header ib_reth_h {
    bit<64> addr;
    bit<32> remote_key;
    bit<16> dma_len1;
    bit<16> dma_len2;
}

/* InfiniBand-RoCE ACK Extended Transport Header */
header ib_aeth_h {
    bit<1> reserved;
    bit<2> opcode;
    bit<5> error_code;
    bit<24> msn;
}

/* Infiniband-RoCE Paddings */
header ib_padding_1_h {
    bit<8> padding;
}

header ib_padding_2_h {
    bit<16> padding;
}

header ib_padding_3_h {
    bit<24> padding;
}

/* Custom Payload-Splitter Info Header */
@pa_no_overlay("egress", "hdr.payload_splitter.marker")
@pa_no_overlay("egress", "hdr.payload_splitter.payload_address")
@pa_no_overlay("egress", "hdr.payload_splitter.payload_len")
@pa_no_overlay("egress", "hdr.payload_splitter.server_qp_index")
@pa_no_overlay("egress", "hdr.payload_splitter.server_index")
header payload_splitter_h {
    bit<32> marker;
    bit<64> payload_address;
    bit<16> payload_len;
    bit<16> server_qp_index;
    bit<16> server_index;
}

/* Custom Payload-Request Header */
header payload_request_h {
    bit<16> padding;
    bit<16> hdr_idx;
}

/* Bridge Ingress->Egress Headers */
@flexible
header bridge_payload_h {
    bit<16> server_mac_addr_1;
    bit<32> server_mac_addr_2;
    ipv4_addr_t server_ip_addr;
    bit<32> r_key;
}

/* HEADERS */
struct headers_t {
    hdr_chunk_h hdr_chunks;
    hdr_chunk_tcp_h hdr_chunks_tcp;

    ethernet_h ethernet;
    rdma_info_h rdma_info;
    rdma_qp_info_h rdma_qp_info;
    rdma_mem_info_h rdma_mem_info;
    rdma_eth_info_h rdma_eth_info;
    qp_restore_h qp_restore;
    ipv4_h ipv4;
    tcp_h tcp;
    udp_h udp;
    payload_splitter_h payload_splitter;
    bridge_payload_h bridge_payload;
    ib_bth_h ib_bth;
    ib_reth_h ib_reth;
    ib_aeth_h ib_aeth;
    payload_request_h payload_request;
    ib_padding_1_h padding_1;
    ib_padding_2_h padding_2;
    ib_padding_3_h padding_3;
}

/* INGRESS METADATA */
struct ig_metadata_t {
    l4_lookup_t l4_lookup; 
    bit<8> to_split;
    bit<8> is_split;
    MirrorId_t mirror_session;
    pkt_type_t packet_type;
    bit<16> server_mac_addr_1;
    bit<32> server_mac_addr_2;
    bit<64> payload_addr;
    bit<16> payload_len;
    bit<16> hdr_idx;
    bit<16> server_qp_index;
    bit<16> restore_qp_index;
    bit<16> server_index;
}

/* EGRESS METADATA */
struct eg_metadata_t {
    mirror_truncate_h mirror_truncate;
    mirror_qp_restore_h mirror_qp_restore;
}

#endif /* _HEADERS_ */