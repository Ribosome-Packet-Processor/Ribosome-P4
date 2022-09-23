EXTRA_PORT = 4
SERVER_PORTS = [0, 20, 16, 32]
NF_PORT = 36
OUTPUT_PORTS = [48, 52, 44, 40]


def increase_pool_size():
    print("Enlarging Queue Buffer Size")
    tm.set_app_pool_size(4, 20000000 // 80)


def set_ports():
    for p in SERVER_PORTS + [EXTRA_PORT] + [NF_PORT] + OUTPUT_PORTS:
        print("Setting Port %d" % p)
        pal.port_add(p, pal.port_speed_t.BF_SPEED_100G, pal.fec_type_t.BF_FEC_TYP_REED_SOLOMON)
        pal.port_an_set(p, 1)
        pal.port_enable(p)


def set_mirroring():
    PKT_MIN_LENGTH = 71
    HEADER_MIRROR_SESSION = 100
    QP_REFRESH_MIRROR_SESSION = 200

    print("Setting up Header Truncate Group %d -- Egress Port %d -- Truncate at %d bytes" %
          (HEADER_MIRROR_SESSION, NF_PORT, PKT_MIN_LENGTH))

    mirror.session_create(
        mirror.MirrorSessionInfo_t(
            mir_type=mirror.MirrorType_e.PD_MIRROR_TYPE_NORM,
            direction=mirror.Direction_e.PD_DIR_BOTH,
            mir_id=HEADER_MIRROR_SESSION,
            egr_port=NF_PORT,
            egr_port_v=True,
            max_pkt_len=PKT_MIN_LENGTH
        )
    )

    for session, port in enumerate(SERVER_PORTS):
        print("Setting up QP Refresh Group %d -- Egress Port %d -- Truncate at %d bytes" %
              (QP_REFRESH_MIRROR_SESSION + session, port, PKT_MIN_LENGTH))
        mirror.session_create(
            mirror.MirrorSessionInfo_t(
                mir_type=mirror.MirrorType_e.PD_MIRROR_TYPE_NORM,
                direction=mirror.Direction_e.PD_DIR_BOTH,
                mir_id=QP_REFRESH_MIRROR_SESSION + session,
                egr_port=port,
                egr_port_v=True,
                max_pkt_len=PKT_MIN_LENGTH
            )
        )


increase_pool_size()
set_ports()
set_mirroring()

conn_mgr.complete_operations()
