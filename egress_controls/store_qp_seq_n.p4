#ifndef _STORE_QP_SEQ_N_
#define _STORE_QP_SEQ_N_

#include "../include/registers.p4"

control StoreQPSeqNum(inout headers_t hdr) {
    RegisterAction<bit<32>, _, bit<32>>(seq_n) seq_n_write = {
        void apply(inout bit<32> value, out bit<32> read_value) {
            value = 0;
        }
    };

    apply {
        if (hdr.rdma_qp_info.isValid()) {
            seq_n_write.execute(hdr.rdma_qp_info.index);
        }
    }
}

#endif /* _STORE_QP_SEQ_N_ */