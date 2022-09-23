#ifndef _PAYLOAD_SPLIT_
#define _PAYLOAD_SPLIT_

#include "../include/types.p4"
#include "../include/configuration.p4"
#include "../include/registers.p4"

control PayloadSplit(inout headers_t hdr, inout ig_metadata_t meta,
                     inout ingress_intrinsic_metadata_for_deparser_t ig_dprsr_md,
                     inout ingress_intrinsic_metadata_for_tm_t ig_tm_md,
                     in bit<16> current_server_idx,
                     in bit<16> server_mac_addr_1,
                     in bit<32> server_mac_addr_2,
                     in ipv4_addr_t server_ip_addr,
                     in bit<32> rdma_remote_key,
                     in bit<24> destination_qp,
                     in bit<16> server_qp_index) {
    bit<16> payload_len;

    action tcp_packet() {
        payload_len = payload_len - hdr.tcp.minSizeInBytes() + hdr.payload_request.minSizeInBytes();
    }
    action udp_packet() {
        payload_len = payload_len - hdr.udp.minSizeInBytes() + hdr.payload_request.minSizeInBytes();
    }

    /* Remote Address Read Actions */
    RegisterAction<bit<32>, _, bit<32>>(remote_address_1) remote_address_1_read = {
        void apply(inout bit<32> value, out bit<32> read_value) {
            read_value = value;
        }
    };
    RegisterAction<bit<32>, _, bit<32>>(remote_address_2) remote_address_2_read = {
        void apply(inout bit<32> value, out bit<32> read_value) {
            read_value = value;
        }
    };
    bit<32> addr_1 = remote_address_1_read.execute(current_server_idx);
    bit<32> addr_2 = remote_address_2_read.execute(current_server_idx);
    bit<64> base_addr = addr_1 ++ addr_2;

    /* Memory Offset Read/Update Action */
    bit<64> final_offset;
    bit<32> mem_offset;
    bit<32> additional_offset;
    RegisterAction<bit<32>, _, bit<32>>(memory_offset) memory_offset_update = {
        void apply(inout bit<32> value, out bit<32> read_value) {
            if ((value + ((bit<32>) payload_len)) >= MAX_BUFFER_SIZE) {
                read_value = 0;
            } else {
                read_value = value;
            }
            if ((value + ((bit<32>) payload_len)) >= MAX_BUFFER_SIZE) {
                value = (bit<32>) payload_len;
            } else {
                value = value + ((bit<32>) payload_len);
            }
        }
    };
    RegisterAction<bit<32>, _, bit<32>>(add_memory_offset) add_memory_offset_update = {
        void apply(inout bit<32> value, out bit<32> read_value) {
            if (value > mem_offset) {
                read_value = 0;
            } else {
                read_value = value;
            }
            if (value > mem_offset) {
                value = additional_offset;
            } else {
                value = value + additional_offset;
            }
        }
    };

    /* Header Index Read/Increase Action */
    bit<16> current_hdr_index;
    RegisterAction<bit<16>, _, bit<16>>(hdr_index) hdr_index_inc = {
        void apply(inout bit<16> value, out bit<16> read_value) {
            read_value = value;

            if (value == (HEADER_REGISTER_SIZE - 1)) {
                value = 0x0;
            } else {
                value = value + 1;
            }
        }
    };

    /* RDMA WRITE Action */
    action send_rdma_write() {
        /* Chosen RDMA Server MAC Address */
        hdr.ethernet.dst_addr_1 = server_mac_addr_1;
        hdr.ethernet.dst_addr_2 = server_mac_addr_2;
        /* Fake MAC Address as source */
        hdr.ethernet.src_addr = 0x000000000001;

        /* Static RDMA Client IP Address where the connection is opened */
        hdr.ipv4.src_addr = RDMA_IP;
        /* Chosen RDMA Server IP Address */
        hdr.ipv4.dst_addr = server_ip_addr;
        hdr.ipv4.ttl = 64;
        hdr.ipv4.flags = 0x2;
        hdr.ipv4.protocol = ipv4_protocol_t.UDP;
        /* Set base IPv4 len, will be updated with payload and padding in Egress */
        hdr.ipv4.total_len = hdr.ipv4.minSizeInBytes() + hdr.udp.minSizeInBytes() + hdr.ib_bth.minSizeInBytes() + hdr.ib_reth.minSizeInBytes() + 4;

        /* Invalidate TCP header, it'll be replaced with UDP/IB */
        hdr.tcp.setInvalid();

        hdr.udp.setValid();
        hdr.udp.src_port = 0;
        hdr.udp.dst_port = UDP_PORT_ROCEV2;
        hdr.udp.checksum = 0;

        /* Set base UDP len, will be updated with payload and padding in Egress */
        hdr.udp.length = hdr.udp.minSizeInBytes() + hdr.ib_bth.minSizeInBytes() + hdr.ib_reth.minSizeInBytes() + 4;

        hdr.ib_bth.setValid();
        hdr.ib_bth.opcode = ib_opcode_t.RDMA_WRITE;
        hdr.ib_bth.se = 0;
        hdr.ib_bth.migration_req = 1;
        hdr.ib_bth.pad_count = 0;
        hdr.ib_bth.transport_version = 0;
        hdr.ib_bth.partition_key = 0xffff;
        hdr.ib_bth.reserved = 0;
        hdr.ib_bth.ack = 1;
        hdr.ib_bth.reserved2 = 0;
        hdr.ib_bth.dst_qp = destination_qp;
        /* Store the QP Index where we will read the real seq_n in the Egress */
        hdr.ib_bth.psn = (bit<24>) server_qp_index;

        hdr.ib_reth.setValid();
        hdr.ib_reth.addr = base_addr + final_offset;
        hdr.ib_reth.remote_key = rdma_remote_key;
        hdr.ib_reth.dma_len1 = 0;
        hdr.ib_reth.dma_len2 = payload_len + hdr.payload_request.padding;

        hdr.payload_request.setValid();
        hdr.payload_request.hdr_idx = current_hdr_index;
    }

    /* Packet Cloning action */
    action mirror() {
        meta.payload_addr = hdr.ib_reth.addr;
        meta.hdr_idx = hdr.payload_request.hdr_idx;
        meta.payload_len = hdr.ib_reth.dma_len2;
        meta.server_qp_index = server_qp_index;
        meta.server_index = current_server_idx;

        ig_dprsr_md.mirror_type = TRUNCATE_MIRROR_TYPE;
        meta.mirror_session = TRUNCATE_MIRROR_SESSION;
        meta.packet_type = PKT_TYPE_MIRROR_TRUNCATE;
    }

    /* Splitter action */
    action payload_splitter() {
        send_rdma_write();

        /* Mirror the packet to the Egress Pipeline, this will be truncated to the headers */
        mirror();
    }

    /* Infiniband padding actions */
    action padding_1() {
        hdr.padding_1.setValid();
        additional_offset = additional_offset + 1;
        hdr.payload_request.padding = 1;
    }

    action padding_2() {
        hdr.padding_2.setValid();
        additional_offset = additional_offset + 2;
        hdr.payload_request.padding = 2;
    }

    action padding_3() {
        hdr.padding_3.setValid();
        additional_offset = additional_offset + 3;
        hdr.payload_request.padding = 3;
    }

    bit<16> bytes_to_pad;
    @ternary(1)
    table compute_padding {
        key = {
            bytes_to_pad: exact;
        }
        actions = {
            padding_1;
            padding_2;
            padding_3;
        }
        size = 3;
        const entries = {
            3: padding_1();
            2: padding_2();
            1: padding_3();
        }
    }

    apply {
        /* Compute payload len. Should be done in another action to avoid multiple-stages */
        if (hdr.tcp.isValid()) {
            payload_len = hdr.ipv4.total_len - hdr.ipv4.minSizeInBytes();
            tcp_packet();
        } else if (hdr.udp.isValid()) {
            payload_len = hdr.ipv4.total_len - hdr.ipv4.minSizeInBytes();
            udp_packet();
        }

        /* Read Last Memory Offset from the register and the additional padding */
        mem_offset = memory_offset_update.execute(current_server_idx);

        bytes_to_pad = payload_len & 0x03;
        compute_padding.apply();

        bit<32> add_mem_offset = add_memory_offset_update.execute(current_server_idx);
        final_offset = 32w0x0 ++ (mem_offset + add_mem_offset);

        current_hdr_index = hdr_index_inc.execute(0);

        payload_splitter();
    }
}

#endif /* _PAYLOAD_SPLIT_ */