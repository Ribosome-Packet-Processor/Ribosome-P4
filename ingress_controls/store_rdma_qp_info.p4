#ifndef _STORE_RDMA_QP_INFO_
#define _STORE_RDMA_QP_INFO_

#include "../include/registers.p4"

control StoreRDMAQPInfo(inout headers_t hdr) {
    RegisterAction<bit<32>, _, bit<32>>(qp) qp_write = {
        void apply(inout bit<32> value, out bit<32> read_value) {
            value = hdr.rdma_qp_info.dst_qp;
        }
    };

    RegisterAction<bit<16>, _, bit<16>>(enabled_qp) enabled_qp_write = {
        void apply(inout bit<16> value, out bit<16> read_value) {
            value = hdr.rdma_qp_info.enable_timer;
        }
    };

    RegisterAction<bit<1>, _, bit<1>>(restore_qp) restore_qp_write = {
        void apply(inout bit<1> value, out bit<1> read_value) {
            value = 0;
        }
    };

    apply {
        if (hdr.rdma_qp_info.isValid()) {
            qp_write.execute(hdr.rdma_qp_info.index);

            enabled_qp_write.execute(hdr.rdma_qp_info.index);
            restore_qp_write.execute(hdr.rdma_qp_info.index);
        }
    }
}

#endif /* _STORE_RDMA_QP_INFO_ */