#ifndef _PACKET_RECONSTRUCT_
#define _PACKET_RECONSTRUCT_

#include "../include/registers.p4"

#define HDR_READ(i) \
    RegisterAction<bit<32>, _, bit<32>>(hdr_block_##i) read_hdr_block_##i = { \
        void apply(inout bit<32> value, out bit<32> read_value) { \
            read_value = value; \
        } \
    }; \
    action read_block_##i() { \
        hdr.hdr_chunks.blk_##i = read_hdr_block_##i.execute(idx); \
    }

#define HDR_READ_16(i) \
    RegisterAction<bit<16>, _, bit<16>>(hdr_block_##i) read_hdr_block_##i = { \
        void apply(inout bit<16> value, out bit<16> read_value) { \
            read_value = value; \
        } \
    }; \
    action read_block_##i() { \
        hdr.hdr_chunks.blk_##i = read_hdr_block_##i.execute(idx); \
    }

#define HDR_READ_TCP(i) \
    RegisterAction<bit<32>, _, bit<32>>(hdr_block_##i) read_hdr_block_##i = { \
        void apply(inout bit<32> value, out bit<32> read_value) { \
            read_value = value; \
        } \
    }; \
    action read_block_##i() { \
        hdr.hdr_chunks_tcp.blk_##i = read_hdr_block_##i.execute(idx); \
    }

#define HDR_READ_TCP_16(i) \
    RegisterAction<bit<16>, _, bit<16>>(hdr_block_##i) read_hdr_block_##i = { \
        void apply(inout bit<16> value, out bit<16> read_value) { \
            read_value = value; \
        } \
    }; \
    action read_block_##i() { \
        hdr.hdr_chunks_tcp.blk_##i = read_hdr_block_##i.execute(idx); \
    }


#define HDR_READ_EXEC(i) \
    read_block_##i();

control PacketReconstruct(inout headers_t hdr,
                          inout ig_metadata_t meta,
                          in ingress_intrinsic_metadata_t ig_intr_md,
                          inout ingress_intrinsic_metadata_for_tm_t ig_tm_md) {
    bit<16> idx = hdr.payload_request.hdr_idx;

    HDR_READ(0)
    HDR_READ(1)
    HDR_READ(2)
    HDR_READ(3)
    HDR_READ(4)
    HDR_READ(5)
    HDR_READ(6)
    HDR_READ(7)
    HDR_READ(8)
    HDR_READ(9)
    HDR_READ_16(10)
    HDR_READ_TCP_16(11)
    HDR_READ_TCP(12)
    HDR_READ_TCP(13)
    HDR_READ_TCP_16(14)

    apply {
        /* Invalidate all the RDMA Read Response headers */
        hdr.ethernet.setInvalid();
        hdr.ipv4.setInvalid();
        hdr.udp.setInvalid();
        hdr.ib_bth.setInvalid();
        hdr.ib_aeth.setInvalid();
        hdr.payload_request.setInvalid();
        /* Invalidate possible padding */
        hdr.padding_1.setInvalid();
        hdr.padding_2.setInvalid();
        hdr.padding_3.setInvalid();

        /* Set the chunks header valid and read values from registers */
        hdr.hdr_chunks.setValid();

        HDR_READ_EXEC(0)
        HDR_READ_EXEC(1)
        HDR_READ_EXEC(2)
        HDR_READ_EXEC(3)
        HDR_READ_EXEC(4)
        HDR_READ_EXEC(5)
        HDR_READ_EXEC(6)
        HDR_READ_EXEC(7)
        HDR_READ_EXEC(8)
        HDR_READ_EXEC(9)
        HDR_READ_EXEC(10)

        /* fix IP and UDP/TCP length to fit the original size of the packet */
        hdr.hdr_chunks.blk_4[31:16] = hdr.ipv4.total_len - hdr.ib_bth.minSizeInBytes() - hdr.ib_aeth.minSizeInBytes() -
                hdr.payload_request.minSizeInBytes() - 4;
        hdr.hdr_chunks.blk_4[31:16] = hdr.hdr_chunks.blk_4[31:16] - hdr.payload_request.padding;

        if (hdr.hdr_chunks.blk_5[7:0] == ipv4_protocol_t.UDP) {
            hdr.hdr_chunks.blk_9[15:0] = hdr.hdr_chunks.blk_4[31:16] - hdr.ipv4.minSizeInBytes();
        } else if (hdr.hdr_chunks.blk_5[7:0] == ipv4_protocol_t.TCP) {
            /* Set additional chunks header valid and read values from registers */
            hdr.hdr_chunks_tcp.setValid();

            HDR_READ_EXEC(11)
            HDR_READ_EXEC(12)
            HDR_READ_EXEC(13)
            HDR_READ_EXEC(14)

            hdr.hdr_chunks.blk_4[31:16] = hdr.hdr_chunks.blk_4[31:16] - hdr.udp.minSizeInBytes() + hdr.tcp.minSizeInBytes();
        }

        /* Forward this to a fake client */
        if (ig_intr_md.ingress_port == SERVER_1_PORT) {
            ig_tm_md.ucast_egress_port = OUTPUT_1_PORT;
        } else if (ig_intr_md.ingress_port == SERVER_2_PORT) {
            ig_tm_md.ucast_egress_port = OUTPUT_2_PORT;
        } else if (ig_intr_md.ingress_port == SERVER_3_PORT) {
            ig_tm_md.ucast_egress_port = OUTPUT_3_PORT;
        } else if (ig_intr_md.ingress_port == SERVER_4_PORT) {
            ig_tm_md.ucast_egress_port = OUTPUT_4_PORT;
        }

        /* Do not process this packet on the egress */
        ig_tm_md.bypass_egress = 0x1;
    }
}

#endif /* _PACKET_RECONSTRUCT_ */