#ifndef _STORE_HEADER_
#define _STORE_HEADER_

#include "../include/registers.p4"

#define HDR_STORE(i) \
    RegisterAction<bit<32>, _, bit<32>>(hdr_block_##i) store_hdr_block_##i = { \
        void apply(inout bit<32> value, out bit<32> read_value) { \
            value = hdr.hdr_chunks.blk_##i; \
        } \
    }; \
    action store_block_##i() { \
        store_hdr_block_##i.execute(idx); \
    }

#define HDR_STORE_16(i) \
    RegisterAction<bit<16>, _, bit<16>>(hdr_block_##i) store_hdr_block_##i = { \
        void apply(inout bit<16> value, out bit<16> read_value) { \
            value = hdr.hdr_chunks.blk_##i; \
        } \
    }; \
    action store_block_##i() { \
        store_hdr_block_##i.execute(idx); \
    }

#define HDR_STORE_TCP(i) \
    RegisterAction<bit<32>, _, bit<32>>(hdr_block_##i) store_hdr_block_##i = { \
        void apply(inout bit<32> value, out bit<32> read_value) { \
            value = hdr.hdr_chunks_tcp.blk_##i; \
        } \
    }; \
    action store_block_##i() { \
        store_hdr_block_##i.execute(idx); \
    }

#define HDR_STORE_TCP_16(i) \
    RegisterAction<bit<16>, _, bit<16>>(hdr_block_##i) store_hdr_block_##i = { \
        void apply(inout bit<16> value, out bit<16> read_value) { \
            value = hdr.hdr_chunks_tcp.blk_##i; \
        } \
    }; \
    action store_block_##i() { \
        store_hdr_block_##i.execute(idx); \
    }

#define HDR_STORE_EXEC(i) \
    store_block_##i();

control StoreHeader(inout headers_t hdr, inout ig_metadata_t meta) {
    bit<16> idx = hdr.payload_request.hdr_idx;

    HDR_STORE(0)
    HDR_STORE(1)
    HDR_STORE(2)
    HDR_STORE(3)
    HDR_STORE(4)
    HDR_STORE(5)
    HDR_STORE(6)
    HDR_STORE(7)
    HDR_STORE(8)
    HDR_STORE(9)
    HDR_STORE_16(10)
    HDR_STORE_TCP_16(11)
    HDR_STORE_TCP(12)
    HDR_STORE_TCP(13)
    HDR_STORE_TCP_16(14)

    apply {
        HDR_STORE_EXEC(0)
        HDR_STORE_EXEC(1)
        HDR_STORE_EXEC(2)
        HDR_STORE_EXEC(3)
        HDR_STORE_EXEC(4)
        HDR_STORE_EXEC(5)
        HDR_STORE_EXEC(6)
        HDR_STORE_EXEC(7)
        HDR_STORE_EXEC(8)
        HDR_STORE_EXEC(9)
        HDR_STORE_EXEC(10)
        HDR_STORE_EXEC(11)
        HDR_STORE_EXEC(12)
        HDR_STORE_EXEC(13)
        HDR_STORE_EXEC(14)

        hdr.hdr_chunks.setInvalid();
        hdr.hdr_chunks_tcp.setInvalid();
        hdr.payload_request.setInvalid();
    }
}

#endif /* _STORE_HEADER_ */