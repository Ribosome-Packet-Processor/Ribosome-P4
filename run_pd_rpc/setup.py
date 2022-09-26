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

increase_pool_size()
set_ports()

conn_mgr.complete_operations()
