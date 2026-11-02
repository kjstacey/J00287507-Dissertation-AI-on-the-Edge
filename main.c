#include <stdio.h>

#include "xparameters.h"
#include "xil_printf.h"
#include "xil_io.h"

#include "lwip/init.h"
#include "lwip/tcp.h"
#include "lwip/dhcp.h"
#include "lwip/dns.h"
#include "lwip/ip_addr.h"

#include "netif/xadapter.h"

#include "platform.h"
#include "platform_config.h"

#include "results_dump.h"


/* ============================================================
 * Application functions from tcp_client.c
 * ============================================================ */

extern void print_app_header(void);
extern int start_application(void);
extern int transfer_data(void);


/* ============================================================
 * lwIP timer flags
 *
 * These are supplied by the Xilinx platform/lwIP support.
 * ============================================================ */

extern volatile int TcpFastTmrFlag;
extern volatile int TcpSlowTmrFlag;


/* ============================================================
 * Ethernet interface
 * ============================================================ */

struct netif server_netif;
struct netif *echo_netif;


/* ============================================================
 * Mailbox
 * ============================================================ */

#define MAILBOX_BASE_ADDR                0x40000000U
#define MAILBOX_TEST_COMPLETE_OFFSET     0x340U


/* ============================================================
 * Result dump control
 *
 * 1 = automatically print stored BRAM results after test
 * 0 = leave results in BRAM without printing
 *
 * For this verification run: 1
 * Final measurement build:   0
 * ============================================================ */

#define AUTO_DUMP_RESULTS                1


/* ============================================================
 * Network configuration
 * ============================================================ */

#define DHCP_TIMEOUT_ITERATIONS          24


/* ============================================================
 * Print IPv4 address
 * ============================================================ */

static void print_ip(char *msg,
                     ip_addr_t *ip)
{
    xil_printf(
        "%s%d.%d.%d.%d\r\n",
        msg,
        ip4_addr1(ip),
        ip4_addr2(ip),
        ip4_addr3(ip),
        ip4_addr4(ip)
    );
}


/* ============================================================
 * Configure network
 * ============================================================ */

static int setup_network(void)
{
    struct netif *netif;
    unsigned char mac_address[] =
    {
        0x00,
        0x0A,
        0x35,
        0x00,
        0x01,
        0x02
    };

    ip_addr_t ipaddr;
    ip_addr_t netmask;
    ip_addr_t gw;

    int dhcp_timeout;


    echo_netif =
        &server_netif;

    netif =
        echo_netif;


    /*
     * Start with 0.0.0.0.
     * DHCP will populate these.
     */
    IP4_ADDR(
        &ipaddr,
        0,
        0,
        0,
        0
    );

    IP4_ADDR(
        &netmask,
        0,
        0,
        0,
        0
    );

    IP4_ADDR(
        &gw,
        0,
        0,
        0,
        0
    );


    lwip_init();


    if (!xemac_add(
            netif,
            &ipaddr,
            &netmask,
            &gw,
            mac_address,
            PLATFORM_EMAC_BASEADDR))
    {
        xil_printf(
            "ERROR: xemac_add failed.\r\n"
        );

        return -1;
    }


    netif_set_default(
        netif
    );


    platform_enable_interrupts();


    netif_set_up(
        netif
    );


    xil_printf(
        "Starting DHCP...\r\n"
    );


    dhcp_start(
        netif
    );


    dhcp_timeout =
        DHCP_TIMEOUT_ITERATIONS;


    /*
     * Wait for DHCP address.
     */
    while ((netif->ip_addr.addr == 0U) &&
           (dhcp_timeout > 0))
    {
        xemacif_input(
            netif
        );


        if (TcpFastTmrFlag)
        {
            tcp_fasttmr();

            TcpFastTmrFlag = 0;
        }


        if (TcpSlowTmrFlag)
        {
            tcp_slowtmr();

            TcpSlowTmrFlag = 0;

            dhcp_fine_tmr();

            dhcp_timeout--;
        }
    }


    if (netif->ip_addr.addr == 0U)
    {
        xil_printf(
            "\r\nERROR: DHCP failed.\r\n"
        );

        return -1;
    }


    xil_printf(
        "\r\nDHCP successful.\r\n"
    );


    print_ip(
        "Board IP: ",
        &netif->ip_addr
    );

    print_ip(
        "Netmask : ",
        &netif->netmask
    );

    print_ip(
        "Gateway : ",
        &netif->gw
    );


    return 0;
}


/* ============================================================
 * Configure DNS
 * ============================================================ */

static void setup_dns(void)
{
    ip_addr_t dns_server;

    /*
     * Manually initialize DNS because this project uses
     * the application copy of dns.c with LWIP_DNS=1.
     */
    dns_init();


    IP4_ADDR(
        &dns_server,
        1,
        1,
        1,
        1
    );


    dns_setserver(
        0,
        &dns_server
    );


    xil_printf("\r\n");

    print_ip(
        "DNS server: ",
        (ip_addr_t *)dns_getserver(0)
    );

    xil_printf("\r\n");
}


/* ============================================================
 * main
 * ============================================================ */

int main(void)
{
    int dns_timer_divider = 0;

#if AUTO_DUMP_RESULTS
    int results_dumped = 0;
#endif


    init_platform();


    xil_printf("\r\n\r\n");
    xil_printf(
        "----- ZedBoard DNS Test -----\r\n"
    );
    xil_printf("\r\n");


    /*
     * Ethernet / DHCP
     */
    if (setup_network() != 0)
    {
        xil_printf(
            "\r\nNetwork setup failed.\r\n"
        );

        cleanup_platform();

        return -1;
    }


    /*
     * DNS
     */
    setup_dns();


    /*
     * Cloud application
     */
    print_app_header();


    if (start_application() != 0)
    {
        xil_printf(
            "\r\nApplication startup failed.\r\n"
        );

        cleanup_platform();

        return -1;
    }


    /*
     * ========================================================
     * Main polling loop
     * ========================================================
     */
    while (1)
    {
        /*
         * Move Ethernet frames from MAC into lwIP.
         */
        xemacif_input(
            &server_netif
        );


        /*
         * lwIP fast TCP timer.
         */
        if (TcpFastTmrFlag)
        {
            tcp_fasttmr();

            TcpFastTmrFlag = 0;
        }


        /*
         * lwIP slow TCP timer.
         *
         * Also drive DNS approximately once per second.
         *
         * TcpSlowTmrFlag occurs every ~500 ms, so calling
         * dns_tmr() every second occurrence gives ~1 second.
         */
        if (TcpSlowTmrFlag)
        {
            tcp_slowtmr();

            TcpSlowTmrFlag = 0;


            dns_timer_divider++;

            if (dns_timer_divider >= 2)
            {
                dns_tmr();

                dns_timer_divider = 0;
            }
        }


        /*
         * Advance TLS / HTTPS / mailbox state machine.
         */
        transfer_data();


#if AUTO_DUMP_RESULTS

        /*
         * ----------------------------------------------------
         * Post-run result dump
         *
         * This does NOT participate in the measurement.
         *
         * TEST_COMPLETE is written only after:
         *   - image 99 response is complete
         *   - result is written to BRAM
         *   - STATUS=2 is written
         *   - summary data is stored
         *
         * Therefore the UART output below begins only after
         * the measured run has finished.
         * ----------------------------------------------------
         */
        if (!results_dumped)
        {
            u32 test_complete;

            test_complete =
                Xil_In32(
                    MAILBOX_BASE_ADDR +
                    MAILBOX_TEST_COMPLETE_OFFSET
                );


            if (test_complete == 1U)
            {
                dump_cloud_results();

                results_dumped = 1;
            }
        }

#endif
    }


    /*
     * Normally unreachable.
     */
    cleanup_platform();

    return 0;
}
