#ifndef _STORE_RDMA_MEM_INFO_
#define _STORE_RDMA_MEM_INFO_

#include "../include/registers.p4"

control StoreRDMAMemInfo(inout headers_t hdr) {
    RegisterAction<bit<32>, _, bit<32>>(remote_address_1) remote_address_1_write = {
        void apply(inout bit<32> value, out bit<32> read_value) {
            value = hdr.rdma_mem_info.remote_address1;
        }
    };
    RegisterAction<bit<32>, _, bit<32>>(remote_address_2) remote_address_2_write = {
        void apply(inout bit<32> value, out bit<32> read_value) {
            value = hdr.rdma_mem_info.remote_address2;
        }
    };
    RegisterAction<bit<32>, _, bit<32>>(remote_key) remote_key_write = {
        void apply(inout bit<32> value, out bit<32> read_value) {
            value = hdr.rdma_mem_info.remote_key;
        }
    };

    RegisterAction<bit<32>, _, bit<32>>(memory_offset) memory_offset_write = {
        void apply(inout bit<32> value, out bit<32> read_value) {
            value = 0;
        }
    };
    RegisterAction<bit<32>, _, bit<32>>(add_memory_offset) add_memory_offset_write = {
        void apply(inout bit<32> value, out bit<32> read_value) {
            value = 0;
        }
    };

    apply {
        if (hdr.rdma_mem_info.isValid()) {
            remote_address_1_write.execute(hdr.rdma_mem_info.server_id);
            remote_address_2_write.execute(hdr.rdma_mem_info.server_id);
            remote_key_write.execute(hdr.rdma_mem_info.server_id);

            /* Reset offset registers */
            memory_offset_write.execute(hdr.rdma_mem_info.server_id);
            add_memory_offset_write.execute(hdr.rdma_mem_info.server_id);
        }
    }
}

#endif /* _STORE_RDMA_MEM_INFO_ */