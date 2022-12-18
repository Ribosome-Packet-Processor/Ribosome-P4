#ifndef _CONFIGURATION_
#define _CONFIGURATION_

/* Servers Configurations */
#define MAX_QP_NUM 64
#define NUMBER_OF_SERVERS 4
#define TOTAL_QP MAX_QP_NUM * NUMBER_OF_SERVERS

/* Headers Configurations */
#define HEADER_REGISTER_SIZE 2000
#define PKT_MIN_LENGTH 71

/* Port Numbers */
#define SERVER_1_PORT 0
#define SERVER_2_PORT 20
#define SERVER_3_PORT 16
#define SERVER_4_PORT 32

#define NF_PORT 36

#define OUTPUT_1_PORT 48
#define OUTPUT_2_PORT 52
#define OUTPUT_3_PORT 44
#define OUTPUT_4_PORT 40

#endif /* _CONFIGURATION_ */