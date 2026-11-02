#include <stdio.h>
#include <string.h>
#include <stdlib.h>

#include "xil_printf.h"
#include "xil_io.h"
#include "xil_types.h"
#include "xtime_l.h"

#include "lwip/err.h"
#include "lwip/dns.h"
#include "lwip/ip_addr.h"
#include "lwip/tcp.h"
#include "lwip/pbuf.h"

#include "mbedtls/ssl.h"
#include "mbedtls/entropy.h"
#include "mbedtls/ctr_drbg.h"
#include "mbedtls/error.h"
#include "mbedtls/memory_buffer_alloc.h"


/* ============================================================
 * Development output
 *
 * 1 = print per-image/status information over UART
 * 0 = quiet measurement build
 *
 * FINAL MEASUREMENT BUILD: set to 0
 * ============================================================ */

#define DEBUG_DUMP_RESULTS               0


/* ============================================================
 * Cloud Run
 * ============================================================ */

#define CLOUD_HOST \
    "mnist-cloud-inference-221036165238.us-east1.run.app"

#define CLOUD_PORT                       443


/* ============================================================
 * Mailbox BRAM map
 * ============================================================ */

#define MAILBOX_BASE_ADDR                0x40000000U

#define MAILBOX_IMAGE_OFFSET             0x000U

#define MAILBOX_STATUS_OFFSET            0x310U
#define MAILBOX_INDEX_OFFSET             0x314U
#define MAILBOX_RESULT_OFFSET            0x318U
#define MAILBOX_EXPECTED_OFFSET          0x31CU

#define MAILBOX_TOTAL_COUNT_OFFSET       0x320U
#define MAILBOX_CORRECT_COUNT_OFFSET     0x324U
#define MAILBOX_ERROR_COUNT_OFFSET       0x328U

#define MAILBOX_LATENCY_MIN_US_OFFSET    0x32CU
#define MAILBOX_LATENCY_MAX_US_OFFSET    0x330U

#define MAILBOX_LATENCY_SUM_LOW_OFFSET   0x334U
#define MAILBOX_LATENCY_SUM_HIGH_OFFSET  0x338U

#define MAILBOX_TOTAL_RUN_US_OFFSET      0x33CU
#define MAILBOX_TEST_COMPLETE_OFFSET     0x340U


/* ------------------------------------------------------------
 * Per-image records
 *
 * 0x400 + image_index * 0x10
 *
 * +0x0 = image index
 *
 * +0x4 =
 *      bits  7:0   expected
 *      bits 15:8   predicted
 *      bits 23:16  correct flag
 *      bits 31:24  error flag
 *
 * +0x8 = latency in microseconds
 *
 * +0xC = raw latency timer ticks, low 32 bits
 * ------------------------------------------------------------ */

#define MAILBOX_RECORD_BASE_OFFSET       0x400U
#define MAILBOX_RECORD_STRIDE            0x10U

#define RECORD_INDEX_OFFSET              0x00U
#define RECORD_RESULT_OFFSET             0x04U
#define RECORD_LATENCY_US_OFFSET         0x08U
#define RECORD_LATENCY_TICKS_OFFSET      0x0CU


/* ============================================================
 * Mailbox handshake values
 * ============================================================ */

#define MAILBOX_STATUS_IDLE              0U
#define MAILBOX_STATUS_IMAGE_READY       1U
#define MAILBOX_STATUS_RESULT_READY      2U


/* ============================================================
 * Experiment
 * ============================================================ */

#define MNIST_IMAGE_SIZE                 784U
#define TEST_IMAGE_COUNT                 100U


/* ============================================================
 * Buffers
 * ============================================================ */

#define TLS_RX_BUFFER_SIZE               32768U
#define MBEDTLS_MEMORY_POOL_SIZE         (128U * 1024U)

#define HTTP_RESPONSE_SIZE               4096U


/* ============================================================
 * Network state
 * ============================================================ */

static volatile int dns_complete = 0;
static volatile int dns_success  = 0;

static ip_addr_t cloud_ip;

static struct tcp_pcb *cloud_pcb = NULL;


/* ============================================================
 * TLS state
 * ============================================================ */

static mbedtls_ssl_context ssl;
static mbedtls_ssl_config conf;
static mbedtls_entropy_context entropy;
static mbedtls_ctr_drbg_context ctr_drbg;

static volatile int tls_initialized = 0;
static volatile int tls_connected   = 0;
static volatile int tls_failed      = 0;

static unsigned char
    mbedtls_memory_pool[MBEDTLS_MEMORY_POOL_SIZE];


/* ============================================================
 * TLS receive ring
 * ============================================================ */

static unsigned char tls_rx_buffer[TLS_RX_BUFFER_SIZE];

static size_t tls_rx_head  = 0;
static size_t tls_rx_tail  = 0;
static size_t tls_rx_count = 0;

static volatile int tcp_eof = 0;


/* ============================================================
 * HTTPS state
 * ============================================================ */

typedef enum
{
    HTTPS_IDLE = 0,

    HTTPS_SEND_HEADER,
    HTTPS_SEND_IMAGE,
    HTTPS_READ_RESPONSE,

    HTTPS_FAILED

} https_state_t;

static https_state_t https_state = HTTPS_IDLE;


/* ============================================================
 * Request / response buffers
 * ============================================================ */

static unsigned char test_image[MNIST_IMAGE_SIZE];

static char http_header[512];

static size_t http_header_length = 0;
static size_t http_header_sent   = 0;

static size_t image_sent = 0;

static char http_response[HTTP_RESPONSE_SIZE];

static size_t http_response_length = 0;


/* ============================================================
 * Current image
 * ============================================================ */

static u32 current_image_index = 0;
static u32 current_expected    = 0;


/* ============================================================
 * Measurement state
 * ============================================================ */

static u32 total_count   = 0;
static u32 correct_count = 0;
static u32 error_count   = 0;

static u32 latency_min_us = 0;
static u32 latency_max_us = 0;

static u64 latency_sum_us = 0;


/*
 * Per-request timer.
 */
static XTime request_start_ticks = 0;
static XTime request_end_ticks   = 0;

static int request_timer_active = 0;


/*
 * Whole 100-image run timer.
 *
 * Starts immediately before image 0 begins its HTTPS request.
 * Stops after the prediction for image 99 has been written back
 * and STATUS=2 has been issued.
 */
static XTime run_start_ticks = 0;
static XTime run_end_ticks   = 0;

static int run_timer_active = 0;


/* ============================================================
 * Timing conversion
 * ============================================================ */

static u32 ticks_to_us(XTime ticks)
{
    u64 value;

    value =
        ((u64)ticks * 1000000ULL) /
        (u64)COUNTS_PER_SECOND;

    if (value > 0xFFFFFFFFULL)
    {
        return 0xFFFFFFFFU;
    }

    return (u32)value;
}


/* ============================================================
 * Mailbox measurement helpers
 * ============================================================ */

static void measurement_reset(void)
{
    total_count   = 0;
    correct_count = 0;
    error_count   = 0;

    latency_min_us = 0;
    latency_max_us = 0;
    latency_sum_us = 0;

    request_timer_active = 0;
    run_timer_active     = 0;

    Xil_Out32(
        MAILBOX_BASE_ADDR +
        MAILBOX_TOTAL_COUNT_OFFSET,
        0U
    );

    Xil_Out32(
        MAILBOX_BASE_ADDR +
        MAILBOX_CORRECT_COUNT_OFFSET,
        0U
    );

    Xil_Out32(
        MAILBOX_BASE_ADDR +
        MAILBOX_ERROR_COUNT_OFFSET,
        0U
    );

    Xil_Out32(
        MAILBOX_BASE_ADDR +
        MAILBOX_LATENCY_MIN_US_OFFSET,
        0U
    );

    Xil_Out32(
        MAILBOX_BASE_ADDR +
        MAILBOX_LATENCY_MAX_US_OFFSET,
        0U
    );

    Xil_Out32(
        MAILBOX_BASE_ADDR +
        MAILBOX_LATENCY_SUM_LOW_OFFSET,
        0U
    );

    Xil_Out32(
        MAILBOX_BASE_ADDR +
        MAILBOX_LATENCY_SUM_HIGH_OFFSET,
        0U
    );

    Xil_Out32(
        MAILBOX_BASE_ADDR +
        MAILBOX_TOTAL_RUN_US_OFFSET,
        0U
    );

    Xil_Out32(
        MAILBOX_BASE_ADDR +
        MAILBOX_TEST_COMPLETE_OFFSET,
        0U
    );
}


/* ------------------------------------------------------------
 * Update summary values in BRAM.
 * ------------------------------------------------------------ */

static void write_summary(void)
{
    Xil_Out32(
        MAILBOX_BASE_ADDR +
        MAILBOX_TOTAL_COUNT_OFFSET,
        total_count
    );

    Xil_Out32(
        MAILBOX_BASE_ADDR +
        MAILBOX_CORRECT_COUNT_OFFSET,
        correct_count
    );

    Xil_Out32(
        MAILBOX_BASE_ADDR +
        MAILBOX_ERROR_COUNT_OFFSET,
        error_count
    );

    Xil_Out32(
        MAILBOX_BASE_ADDR +
        MAILBOX_LATENCY_MIN_US_OFFSET,
        latency_min_us
    );

    Xil_Out32(
        MAILBOX_BASE_ADDR +
        MAILBOX_LATENCY_MAX_US_OFFSET,
        latency_max_us
    );

    Xil_Out32(
        MAILBOX_BASE_ADDR +
        MAILBOX_LATENCY_SUM_LOW_OFFSET,
        (u32)(latency_sum_us & 0xFFFFFFFFULL)
    );

    Xil_Out32(
        MAILBOX_BASE_ADDR +
        MAILBOX_LATENCY_SUM_HIGH_OFFSET,
        (u32)(latency_sum_us >> 32)
    );
}


/* ------------------------------------------------------------
 * Store one 16-byte per-image result record.
 * ------------------------------------------------------------ */

static void write_image_record(
    u32 image_index,
    u32 expected,
    u32 predicted,
    u32 correct,
    u32 error,
    u32 latency_us,
    XTime latency_ticks)
{
    u32 base;
    u32 packed_result;

    base =
        MAILBOX_BASE_ADDR +
        MAILBOX_RECORD_BASE_OFFSET +
        (image_index * MAILBOX_RECORD_STRIDE);

    packed_result =
        ((expected  & 0xFFU)      ) |
        ((predicted & 0xFFU) <<  8) |
        ((correct   & 0xFFU) << 16) |
        ((error     & 0xFFU) << 24);

    Xil_Out32(
        base + RECORD_INDEX_OFFSET,
        image_index
    );

    Xil_Out32(
        base + RECORD_RESULT_OFFSET,
        packed_result
    );

    Xil_Out32(
        base + RECORD_LATENCY_US_OFFSET,
        latency_us
    );

    /*
     * Cloud latency is far below the point where the low
     * 32 timer bits would overflow, so one word is sufficient
     * for the raw per-image record.
     */
    Xil_Out32(
        base + RECORD_LATENCY_TICKS_OFFSET,
        (u32)((u64)latency_ticks & 0xFFFFFFFFULL)
    );
}


/* ============================================================
 * DEVELOPMENT-ONLY entropy
 *
 * NOT cryptographically secure.
 * ============================================================ */

static int test_entropy_source(void *data,
                               unsigned char *output,
                               size_t len,
                               size_t *olen)
{
    size_t i;

    (void)data;

    for (i = 0; i < len; i++)
    {
        output[i] =
            (unsigned char)
            (0xA5 ^ (unsigned char)i);
    }

    *olen = len;

    return 0;
}


/* ============================================================
 * TLS RX ring helpers
 * ============================================================ */

static size_t tls_rx_free_space(void)
{
    return TLS_RX_BUFFER_SIZE -
           tls_rx_count;
}


static int tls_rx_put(const unsigned char *data,
                      size_t len)
{
    size_t i;

    if (len > tls_rx_free_space())
    {
        return -1;
    }

    for (i = 0; i < len; i++)
    {
        tls_rx_buffer[tls_rx_head] =
            data[i];

        tls_rx_head++;

        if (tls_rx_head >= TLS_RX_BUFFER_SIZE)
        {
            tls_rx_head = 0;
        }
    }

    tls_rx_count += len;

    return 0;
}


static size_t tls_rx_get(unsigned char *data,
                         size_t len)
{
    size_t i;
    size_t amount;

    amount = len;

    if (amount > tls_rx_count)
    {
        amount = tls_rx_count;
    }

    for (i = 0; i < amount; i++)
    {
        data[i] =
            tls_rx_buffer[tls_rx_tail];

        tls_rx_tail++;

        if (tls_rx_tail >= TLS_RX_BUFFER_SIZE)
        {
            tls_rx_tail = 0;
        }
    }

    tls_rx_count -= amount;

    return amount;
}


/* ============================================================
 * Mbed TLS BIO callbacks
 * ============================================================ */

static int tls_send(void *ctx,
                    const unsigned char *buf,
                    size_t len)
{
    struct tcp_pcb *pcb;

    u16_t available;
    u16_t amount;

    err_t err;

    pcb =
        (struct tcp_pcb *)ctx;

    if (pcb == NULL)
    {
        return
            MBEDTLS_ERR_SSL_INTERNAL_ERROR;
    }

    available =
        tcp_sndbuf(pcb);

    if (available == 0)
    {
        return
            MBEDTLS_ERR_SSL_WANT_WRITE;
    }

    amount =
        (u16_t)len;

    if (amount > available)
    {
        amount = available;
    }

    err =
        tcp_write(
            pcb,
            buf,
            amount,
            TCP_WRITE_FLAG_COPY
        );

    if (err == ERR_MEM)
    {
        return
            MBEDTLS_ERR_SSL_WANT_WRITE;
    }

    if (err != ERR_OK)
    {
        return
            MBEDTLS_ERR_SSL_INTERNAL_ERROR;
    }

    err =
        tcp_output(pcb);

    if (err != ERR_OK)
    {
        return
            MBEDTLS_ERR_SSL_WANT_WRITE;
    }

    return (int)amount;
}


static int tls_recv(void *ctx,
                    unsigned char *buf,
                    size_t len)
{
    size_t amount;

    (void)ctx;

    if (tls_rx_count == 0)
    {
        if (tcp_eof)
        {
            return 0;
        }

        return
            MBEDTLS_ERR_SSL_WANT_READ;
    }

    amount =
        tls_rx_get(buf, len);

    return (int)amount;
}


/* ============================================================
 * Load current mailbox image
 * ============================================================ */

static int load_image_from_mailbox(void)
{
    unsigned int word_index;
    unsigned int pixel_index;

    u32 word;
    u32 status;

    status =
        Xil_In32(
            MAILBOX_BASE_ADDR +
            MAILBOX_STATUS_OFFSET
        );

    if (status !=
        MAILBOX_STATUS_IMAGE_READY)
    {
        return 0;
    }

    current_image_index =
        Xil_In32(
            MAILBOX_BASE_ADDR +
            MAILBOX_INDEX_OFFSET
        );

    current_expected =
        Xil_In32(
            MAILBOX_BASE_ADDR +
            MAILBOX_EXPECTED_OFFSET
        );

    pixel_index = 0;

    for (word_index = 0;
         word_index < 196U;
         word_index++)
    {
        word =
            Xil_In32(
                MAILBOX_BASE_ADDR +
                MAILBOX_IMAGE_OFFSET +
                (word_index * 4U)
            );

        test_image[pixel_index++] =
            (unsigned char)
            (word & 0xFFU);

        test_image[pixel_index++] =
            (unsigned char)
            ((word >> 8) & 0xFFU);

        test_image[pixel_index++] =
            (unsigned char)
            ((word >> 16) & 0xFFU);

        test_image[pixel_index++] =
            (unsigned char)
            ((word >> 24) & 0xFFU);
    }

#if DEBUG_DUMP_RESULTS
    xil_printf(
        "\r\nImage %lu ready "
        "(expected %lu)\r\n",
        (unsigned long)current_image_index,
        (unsigned long)current_expected
    );
#endif

    return 1;
}


/* ============================================================
 * TLS initialization
 * ============================================================ */

static int tls_initialize(void)
{
    int ret;

    const char *pers =
        "zedboard_cloud_tls";

    mbedtls_memory_buffer_alloc_init(
        mbedtls_memory_pool,
        sizeof(mbedtls_memory_pool)
    );

    mbedtls_ssl_init(&ssl);
    mbedtls_ssl_config_init(&conf);
    mbedtls_entropy_init(&entropy);
    mbedtls_ctr_drbg_init(&ctr_drbg);

    xil_printf(
        "\r\nInitializing Mbed TLS...\r\n"
    );

    ret =
        mbedtls_entropy_add_source(
            &entropy,
            test_entropy_source,
            NULL,
            32,
            MBEDTLS_ENTROPY_SOURCE_STRONG
        );

    if (ret != 0)
    {
        xil_printf(
            "ERROR: entropy source "
            "-0x%04x\r\n",
            (unsigned int)(-ret)
        );

        return ret;
    }

    ret =
        mbedtls_ctr_drbg_seed(
            &ctr_drbg,
            mbedtls_entropy_func,
            &entropy,
            (const unsigned char *)pers,
            strlen(pers)
        );

    if (ret != 0)
    {
        xil_printf(
            "ERROR: CTR_DRBG seed "
            "-0x%04x\r\n",
            (unsigned int)(-ret)
        );

        return ret;
    }

    ret =
        mbedtls_ssl_config_defaults(
            &conf,
            MBEDTLS_SSL_IS_CLIENT,
            MBEDTLS_SSL_TRANSPORT_STREAM,
            MBEDTLS_SSL_PRESET_DEFAULT
        );

    if (ret != 0)
    {
        xil_printf(
            "ERROR: SSL defaults "
            "-0x%04x\r\n",
            (unsigned int)(-ret)
        );

        return ret;
    }

    /*
     * DEVELOPMENT ONLY.
     *
     * This must become VERIFY_REQUIRED before
     * the final secured implementation.
     */
    mbedtls_ssl_conf_authmode(
        &conf,
        MBEDTLS_SSL_VERIFY_NONE
    );

    mbedtls_ssl_conf_rng(
        &conf,
        mbedtls_ctr_drbg_random,
        &ctr_drbg
    );

    ret =
        mbedtls_ssl_setup(
            &ssl,
            &conf
        );

    if (ret != 0)
    {
        xil_printf(
            "ERROR: SSL setup "
            "-0x%04x\r\n",
            (unsigned int)(-ret)
        );

        return ret;
    }

    ret =
        mbedtls_ssl_set_hostname(
            &ssl,
            CLOUD_HOST
        );

    if (ret != 0)
    {
        xil_printf(
            "ERROR: hostname "
            "-0x%04x\r\n",
            (unsigned int)(-ret)
        );

        return ret;
    }

    tls_initialized = 1;

    xil_printf(
        "Mbed TLS initialized.\r\n"
    );

    return 0;
}


/* ============================================================
 * Prepare one HTTPS request
 * ============================================================ */

static void https_prepare_request(void)
{
    int len;

    if (!load_image_from_mailbox())
    {
        return;
    }

    len =
        snprintf(
            http_header,
            sizeof(http_header),

            "POST /predict HTTP/1.1\r\n"
            "Host: %s\r\n"
            "Content-Type: application/octet-stream\r\n"
            "Content-Length: 784\r\n"
            "Connection: keep-alive\r\n"
            "\r\n",

            CLOUD_HOST
        );

    if ((len <= 0) ||
        (len >=
         (int)sizeof(http_header)))
    {
        xil_printf(
            "ERROR: HTTP header creation failed.\r\n"
        );

        error_count++;

        write_summary();

        https_state =
            HTTPS_FAILED;

        return;
    }

    http_header_length =
        (size_t)len;

    http_header_sent = 0;
    image_sent       = 0;

    http_response_length = 0;

    memset(
        http_response,
        0,
        sizeof(http_response)
    );

    request_timer_active = 0;

    https_state =
        HTTPS_SEND_HEADER;

#if DEBUG_DUMP_RESULTS
    xil_printf(
        "Sending image %lu...\r\n",
        (unsigned long)current_image_index
    );
#endif
}


/* ============================================================
 * Is one complete HTTP response available?
 * ============================================================ */

static int http_response_complete(void)
{
    char *header_end;
    char *content_length_text;

    long content_length;

    size_t header_size;
    size_t body_size;

    if (http_response_length == 0)
    {
        return 0;
    }

    http_response[
        http_response_length
    ] = '\0';

    header_end =
        strstr(
            http_response,
            "\r\n\r\n"
        );

    if (header_end == NULL)
    {
        return 0;
    }

    content_length_text =
        strstr(
            http_response,
            "Content-Length:"
        );

    if (content_length_text == NULL)
    {
        content_length_text =
            strstr(
                http_response,
                "content-length:"
            );
    }

    if (content_length_text == NULL)
    {
        return 0;
    }

    content_length_text =
        strchr(
            content_length_text,
            ':'
        );

    if (content_length_text == NULL)
    {
        return 0;
    }

    content_length_text++;

    while ((*content_length_text == ' ') ||
           (*content_length_text == '\t'))
    {
        content_length_text++;
    }

    content_length =
        strtol(
            content_length_text,
            NULL,
            10
        );

    if (content_length < 0)
    {
        return 0;
    }

    header_size =
        (size_t)
        ((header_end + 4) -
         http_response);

    body_size =
        http_response_length -
        header_size;

    if (body_size >=
        (size_t)content_length)
    {
        return 1;
    }

    return 0;
}


/* ============================================================
 * Finish one Cloud Run response
 * ============================================================ */

static void https_finish_response(void)
{
    char *prediction_text;

    int prediction;

    u32 correct;
    u32 latency_us;

    XTime latency_ticks;

    u32 record_error = 0;


    /*
     * Stop per-image latency as soon as the complete HTTP
     * response has arrived.
     */
    XTime_GetTime(
        &request_end_ticks
    );

    if (request_timer_active)
    {
        latency_ticks =
            request_end_ticks -
            request_start_ticks;
    }
    else
    {
        latency_ticks = 0;
    }

    request_timer_active = 0;

    latency_us =
        ticks_to_us(
            latency_ticks
        );


    if (http_response_length >=
        sizeof(http_response))
    {
        http_response[
            sizeof(http_response) - 1
        ] = '\0';
    }
    else
    {
        http_response[
            http_response_length
        ] = '\0';
    }


    /*
     * Require successful HTTP response.
     */
    if (strstr(
            http_response,
            "HTTP/1.1 200") == NULL)
    {
        xil_printf(
            "\r\nERROR: image %lu "
            "did not receive HTTP 200.\r\n",
            (unsigned long)current_image_index
        );

        error_count++;
        record_error = 1;

        write_image_record(
            current_image_index,
            current_expected,
            0xFFU,
            0U,
            record_error,
            latency_us,
            latency_ticks
        );

        write_summary();

        https_state =
            HTTPS_FAILED;

        return;
    }


    prediction_text =
        strstr(
            http_response,
            "\"prediction\":"
        );

    if (prediction_text == NULL)
    {
        xil_printf(
            "\r\nERROR: image %lu "
            "has no prediction field.\r\n",
            (unsigned long)current_image_index
        );

        error_count++;
        record_error = 1;

        write_image_record(
            current_image_index,
            current_expected,
            0xFFU,
            0U,
            record_error,
            latency_us,
            latency_ticks
        );

        write_summary();

        https_state =
            HTTPS_FAILED;

        return;
    }


    prediction_text +=
        strlen("\"prediction\":");


    if ((*prediction_text < '0') ||
        (*prediction_text > '9'))
    {
        xil_printf(
            "\r\nERROR: invalid prediction.\r\n"
        );

        error_count++;
        record_error = 1;

        write_image_record(
            current_image_index,
            current_expected,
            0xFFU,
            0U,
            record_error,
            latency_us,
            latency_ticks
        );

        write_summary();

        https_state =
            HTTPS_FAILED;

        return;
    }


    prediction =
        *prediction_text - '0';


    if ((u32)prediction ==
        current_expected)
    {
        correct = 1U;
        correct_count++;
    }
    else
    {
        correct = 0U;
    }

    total_count++;


    /*
     * Update latency summary.
     */
    if (total_count == 1U)
    {
        latency_min_us =
            latency_us;

        latency_max_us =
            latency_us;
    }
    else
    {
        if (latency_us <
            latency_min_us)
        {
            latency_min_us =
                latency_us;
        }

        if (latency_us >
            latency_max_us)
        {
            latency_max_us =
                latency_us;
        }
    }

    latency_sum_us +=
        (u64)latency_us;


    /*
     * Store per-image record.
     */
    write_image_record(
        current_image_index,
        current_expected,
        (u32)prediction,
        correct,
        0U,
        latency_us,
        latency_ticks
    );


    /*
     * Keep running summary available in BRAM.
     */
    write_summary();


#if DEBUG_DUMP_RESULTS

    xil_printf(
        "Image %lu: expected=%lu "
        "predicted=%d latency=%lu us",
        (unsigned long)current_image_index,
        (unsigned long)current_expected,
        prediction,
        (unsigned long)latency_us
    );

    if (correct)
    {
        xil_printf(
            " CORRECT\r\n"
        );
    }
    else
    {
        xil_printf(
            " WRONG\r\n"
        );
    }

#endif


    /*
     * Return result to PL.
     *
     * RESULT must be written first.
     * STATUS=2 tells PL the result is valid.
     */
    Xil_Out32(
        MAILBOX_BASE_ADDR +
        MAILBOX_RESULT_OFFSET,
        (u32)prediction
    );

    Xil_Out32(
        MAILBOX_BASE_ADDR +
        MAILBOX_STATUS_OFFSET,
        MAILBOX_STATUS_RESULT_READY
    );


    /*
     * Final image:
     *
     * Total-run timing is defined from immediately before
     * the first HTTPS request begins through the final
     * RESULT/STATUS acknowledgement.
     */
    if (current_image_index ==
        (TEST_IMAGE_COUNT - 1U))
    {
        u32 total_run_us;

        XTime_GetTime(
            &run_end_ticks
        );

        run_timer_active = 0;

        total_run_us =
            ticks_to_us(
                run_end_ticks -
                run_start_ticks
            );

        Xil_Out32(
            MAILBOX_BASE_ADDR +
            MAILBOX_TOTAL_RUN_US_OFFSET,
            total_run_us
        );

        /*
         * Write summaries one final time.
         */
        write_summary();

        /*
         * TEST_COMPLETE is written last.
         *
         * When this becomes 1, all result and timing fields
         * are already valid in BRAM.
         */
        Xil_Out32(
            MAILBOX_BASE_ADDR +
            MAILBOX_TEST_COMPLETE_OFFSET,
            1U
        );

#if DEBUG_DUMP_RESULTS

        xil_printf("\r\n");
        xil_printf(
            "========================================\r\n"
        );

        xil_printf(
            "100-IMAGE CLOUD TEST COMPLETE\r\n"
        );

        xil_printf(
            "Total   : %lu\r\n",
            (unsigned long)total_count
        );

        xil_printf(
            "Correct : %lu\r\n",
            (unsigned long)correct_count
        );

        xil_printf(
            "Errors  : %lu\r\n",
            (unsigned long)error_count
        );

        xil_printf(
            "Min us  : %lu\r\n",
            (unsigned long)latency_min_us
        );

        xil_printf(
            "Max us  : %lu\r\n",
            (unsigned long)latency_max_us
        );

        xil_printf(
            "Run us  : %lu\r\n",
            (unsigned long)total_run_us
        );

        xil_printf(
            "========================================\r\n"
        );

#endif
    }


    /*
     * Wait for PL to clear STATUS and publish the
     * next image.
     */
    https_state =
        HTTPS_IDLE;
}


/* ============================================================
 * HTTPS state machine
 * ============================================================ */

static void https_process(void)
{
    int ret;

    unsigned char read_buffer[512];

    size_t remaining;


    /* --------------------------------------------------------
     * Send request header
     * -------------------------------------------------------- */

    if (https_state ==
        HTTPS_SEND_HEADER)
    {
        /*
         * Start latency immediately before the very first
         * TLS write belonging to this request.
         */
        if (!request_timer_active)
        {
            XTime_GetTime(
                &request_start_ticks
            );

            request_timer_active = 1;


            /*
             * First image also starts whole-run timing.
             */
            if (!run_timer_active &&
                current_image_index == 0U)
            {
                run_start_ticks =
                    request_start_ticks;

                run_timer_active = 1;
            }
        }


        remaining =
            http_header_length -
            http_header_sent;

        ret =
            mbedtls_ssl_write(
                &ssl,
                (const unsigned char *)
                &http_header[
                    http_header_sent
                ],
                remaining
            );


        if (ret > 0)
        {
            http_header_sent +=
                (size_t)ret;

            if (http_header_sent >=
                http_header_length)
            {
                https_state =
                    HTTPS_SEND_IMAGE;
            }

            return;
        }


        if ((ret ==
             MBEDTLS_ERR_SSL_WANT_READ) ||
            (ret ==
             MBEDTLS_ERR_SSL_WANT_WRITE))
        {
            return;
        }


        xil_printf(
            "ERROR: header TLS write "
            "-0x%04x\r\n",
            (unsigned int)(-ret)
        );

        error_count++;

        write_summary();

        https_state =
            HTTPS_FAILED;

        return;
    }


    /* --------------------------------------------------------
     * Send image body
     * -------------------------------------------------------- */

    if (https_state ==
        HTTPS_SEND_IMAGE)
    {
        remaining =
            MNIST_IMAGE_SIZE -
            image_sent;

        ret =
            mbedtls_ssl_write(
                &ssl,
                &test_image[image_sent],
                remaining
            );


        if (ret > 0)
        {
            image_sent +=
                (size_t)ret;

            if (image_sent >=
                MNIST_IMAGE_SIZE)
            {
                https_state =
                    HTTPS_READ_RESPONSE;
            }

            return;
        }


        if ((ret ==
             MBEDTLS_ERR_SSL_WANT_READ) ||
            (ret ==
             MBEDTLS_ERR_SSL_WANT_WRITE))
        {
            return;
        }


        xil_printf(
            "ERROR: image TLS write "
            "-0x%04x\r\n",
            (unsigned int)(-ret)
        );

        error_count++;

        write_summary();

        https_state =
            HTTPS_FAILED;

        return;
    }


    /* --------------------------------------------------------
     * Read Cloud Run response
     * -------------------------------------------------------- */

    if (https_state ==
        HTTPS_READ_RESPONSE)
    {
        ret =
            mbedtls_ssl_read(
                &ssl,
                read_buffer,
                sizeof(read_buffer)
            );


        if (ret > 0)
        {
            if ((http_response_length +
                 (size_t)ret) >=
                sizeof(http_response))
            {
                xil_printf(
                    "ERROR: HTTP response overflow.\r\n"
                );

                error_count++;

                write_summary();

                https_state =
                    HTTPS_FAILED;

                return;
            }


            memcpy(
                &http_response[
                    http_response_length
                ],
                read_buffer,
                (size_t)ret
            );

            http_response_length +=
                (size_t)ret;

            http_response[
                http_response_length
            ] = '\0';


            /*
             * Persistent HTTP connection:
             * Content-Length identifies the end of this
             * response. Do not wait for TCP close.
             */
            if (http_response_complete())
            {
                https_finish_response();
            }

            return;
        }


        if ((ret ==
             MBEDTLS_ERR_SSL_WANT_READ) ||
            (ret ==
             MBEDTLS_ERR_SSL_WANT_WRITE))
        {
            return;
        }


        if ((ret == 0) ||
            (ret ==
             MBEDTLS_ERR_SSL_PEER_CLOSE_NOTIFY))
        {
            xil_printf(
                "\r\nERROR: TLS connection closed "
                "during image %lu.\r\n",
                (unsigned long)current_image_index
            );

            error_count++;

            write_summary();

            https_state =
                HTTPS_FAILED;

            return;
        }


        xil_printf(
            "ERROR: TLS read "
            "-0x%04x\r\n",
            (unsigned int)(-ret)
        );

        error_count++;

        write_summary();

        https_state =
            HTTPS_FAILED;
    }
}


/* ============================================================
 * TLS handshake
 * ============================================================ */

static void tls_continue_handshake(void)
{
    int ret;

    char error_buf[128];

    if (!tls_initialized ||
        tls_connected ||
        tls_failed)
    {
        return;
    }


    ret =
        mbedtls_ssl_handshake(
            &ssl
        );


    if (ret == 0)
    {
        tls_connected = 1;

        xil_printf("\r\n");
        xil_printf(
            "========================================\r\n"
        );
        xil_printf(
            "TLS HANDSHAKE SUCCESS\r\n"
        );
        xil_printf(
            "TLS   : %s\r\n",
            mbedtls_ssl_get_version(&ssl)
        );
        xil_printf(
            "Cipher: %s\r\n",
            mbedtls_ssl_get_ciphersuite(&ssl)
        );
        xil_printf(
            "========================================\r\n"
        );

        return;
    }


    if ((ret ==
         MBEDTLS_ERR_SSL_WANT_READ) ||
        (ret ==
         MBEDTLS_ERR_SSL_WANT_WRITE))
    {
        return;
    }


    mbedtls_strerror(
        ret,
        error_buf,
        sizeof(error_buf)
    );


    xil_printf(
        "\r\nTLS HANDSHAKE FAILED "
        "-0x%04x\r\n",
        (unsigned int)(-ret)
    );

    xil_printf(
        "%s\r\n",
        error_buf
    );

    tls_failed = 1;
}


/* ============================================================
 * lwIP receive callback
 * ============================================================ */

static err_t tcp_receive(void *arg,
                         struct tcp_pcb *tpcb,
                         struct pbuf *p,
                         err_t err)
{
    struct pbuf *q;

    (void)arg;


    if (err != ERR_OK)
    {
        if (p != NULL)
        {
            pbuf_free(p);
        }

        return err;
    }


    if (p == NULL)
    {
        tcp_eof = 1;

        xil_printf(
            "\r\nTCP connection closed by remote host.\r\n"
        );

        return ERR_OK;
    }


    if (p->tot_len >
        tls_rx_free_space())
    {
        xil_printf(
            "\r\nERROR: TLS RX buffer overflow.\r\n"
        );

        pbuf_free(p);

        tcp_abort(tpcb);

        cloud_pcb = NULL;
        tls_failed = 1;

        error_count++;

        write_summary();

        return ERR_ABRT;
    }


    for (q = p;
         q != NULL;
         q = q->next)
    {
        if (tls_rx_put(
                (const unsigned char *)
                q->payload,
                q->len) != 0)
        {
            pbuf_free(p);

            tcp_abort(tpcb);

            cloud_pcb = NULL;
            tls_failed = 1;

            error_count++;

            write_summary();

            return ERR_ABRT;
        }
    }


    tcp_recved(
        tpcb,
        p->tot_len
    );

    pbuf_free(p);


    if (!tls_connected)
    {
        tls_continue_handshake();
    }
    else
    {
        https_process();
    }


    return ERR_OK;
}


/* ============================================================
 * TCP error callback
 * ============================================================ */

static void tcp_error(void *arg,
                      err_t err)
{
    (void)arg;

    xil_printf(
        "\r\nTCP ERROR: %d\r\n",
        (int)err
    );

    cloud_pcb = NULL;

    if (run_timer_active)
    {
        error_count++;

        write_summary();
    }
}


/* ============================================================
 * TCP connected callback
 * ============================================================ */

static err_t tcp_connected(void *arg,
                           struct tcp_pcb *tpcb,
                           err_t err)
{
    int ret;

    (void)arg;


    if (err != ERR_OK)
    {
        xil_printf(
            "\r\nTCP connect callback "
            "error: %d\r\n",
            (int)err
        );

        return err;
    }


    xil_printf("\r\n");
    xil_printf(
        "========================================\r\n"
    );
    xil_printf(
        "TCP CONNECTION SUCCESS\r\n"
    );
    xil_printf(
        "Host: %s\r\n",
        CLOUD_HOST
    );
    xil_printf(
        "IP  : %s\r\n",
        ipaddr_ntoa(&cloud_ip)
    );
    xil_printf(
        "Port: %d\r\n",
        CLOUD_PORT
    );
    xil_printf(
        "========================================\r\n"
    );


    cloud_pcb =
        tpcb;


    tcp_recv(
        tpcb,
        tcp_receive
    );


    ret =
        tls_initialize();


    if (ret != 0)
    {
        xil_printf(
            "TLS initialization failed.\r\n"
        );

        tls_failed = 1;

        return ERR_OK;
    }


    mbedtls_ssl_set_bio(
        &ssl,
        tpcb,
        tls_send,
        tls_recv,
        NULL
    );


    xil_printf(
        "\r\nStarting TLS handshake...\r\n"
    );


    tls_continue_handshake();


    return ERR_OK;
}


/* ============================================================
 * Open TCP connection
 * ============================================================ */

static void connect_to_cloud(void)
{
    err_t err;


    xil_printf(
        "\r\nOpening TCP connection to "
        "resolved Cloud Run address...\r\n"
    );


    cloud_pcb =
        tcp_new();


    if (cloud_pcb == NULL)
    {
        xil_printf(
            "ERROR: tcp_new() failed.\r\n"
        );

        return;
    }


    tcp_arg(
        cloud_pcb,
        NULL
    );


    tcp_err(
        cloud_pcb,
        tcp_error
    );


    err =
        tcp_connect(
            cloud_pcb,
            &cloud_ip,
            CLOUD_PORT,
            tcp_connected
        );


    if (err != ERR_OK)
    {
        xil_printf(
            "ERROR: tcp_connect() returned %d\r\n",
            (int)err
        );

        tcp_abort(
            cloud_pcb
        );

        cloud_pcb = NULL;

        return;
    }


    xil_printf(
        "TCP SYN initiated; "
        "waiting for connection callback...\r\n"
    );
}


/* ============================================================
 * DNS callback
 * ============================================================ */

static void dns_found(const char *name,
                      const ip_addr_t *ipaddr,
                      void *callback_arg)
{
    (void)callback_arg;


    if (ipaddr != NULL)
    {
        cloud_ip =
            *ipaddr;


        xil_printf("\r\n");
        xil_printf(
            "========================================\r\n"
        );
        xil_printf(
            "DNS SUCCESS\r\n"
        );
        xil_printf(
            "Host: %s\r\n",
            name
        );
        xil_printf(
            "IP  : %s\r\n",
            ipaddr_ntoa(ipaddr)
        );
        xil_printf(
            "========================================\r\n"
        );


        dns_success  = 1;
        dns_complete = 1;


        connect_to_cloud();
    }
    else
    {
        xil_printf(
            "\r\nDNS FAILED\r\n"
        );

        dns_success  = 0;
        dns_complete = 1;
    }
}


/* ============================================================
 * Public interface
 * ============================================================ */

void print_app_header(void)
{
    xil_printf("\r\n");

    xil_printf(
        "Cloud Run 100-Image Measurement Test\r\n"
    );

    xil_printf(
        "Hostname:\r\n%s\r\n",
        CLOUD_HOST
    );

    xil_printf(
        "Port: %d\r\n",
        CLOUD_PORT
    );

    xil_printf("\r\n");

    xil_printf(
        "*** DEVELOPMENT TLS SECURITY ***\r\n"
    );

    xil_printf(
        "Certificate verification and secure "
        "entropy are not enabled yet.\r\n"
    );

    xil_printf("\r\n");
}


/* ============================================================
 * Start application
 * ============================================================ */

int start_application(void)
{
    err_t err;

    ip_addr_t resolved_ip;


    dns_complete = 0;
    dns_success  = 0;

    tls_initialized = 0;
    tls_connected   = 0;
    tls_failed      = 0;

    tcp_eof = 0;

    tls_rx_head  = 0;
    tls_rx_tail  = 0;
    tls_rx_count = 0;

    https_state =
        HTTPS_IDLE;


    /*
     * Clear previous experiment summary.
     *
     * Do NOT touch STATUS here because STATUS participates
     * in the PL/PS handshake.
     */
    measurement_reset();


    xil_printf(
        "Resolving Cloud Run hostname...\r\n"
    );


    err =
        dns_gethostbyname(
            CLOUD_HOST,
            &resolved_ip,
            dns_found,
            NULL
        );


    if (err == ERR_OK)
    {
        cloud_ip =
            resolved_ip;

        dns_complete = 1;
        dns_success  = 1;


        xil_printf(
            "\r\nDNS SUCCESS (cached)\r\n"
        );

        xil_printf(
            "IP: %s\r\n",
            ipaddr_ntoa(&cloud_ip)
        );


        connect_to_cloud();


        return 0;
    }


    if (err == ERR_INPROGRESS)
    {
        xil_printf(
            "DNS query sent; "
            "waiting for response...\r\n"
        );

        return 0;
    }


    xil_printf(
        "dns_gethostbyname failed: %d\r\n",
        (int)err
    );


    dns_complete = 1;
    dns_success  = 0;


    return -1;
}


/* ============================================================
 * Main polling
 * ============================================================ */

int transfer_data(void)
{
    static u32 last_status =
        0xFFFFFFFFU;

    u32 status;


    if ((cloud_pcb != NULL) &&
        tls_initialized &&
        !tls_failed)
    {
        /*
         * TLS handshake still underway.
         */
        if (!tls_connected)
        {
            tls_continue_handshake();
        }


        /*
         * TLS established, waiting for next PL image.
         */
        else if (https_state ==
                 HTTPS_IDLE)
        {
            status =
                Xil_In32(
                    MAILBOX_BASE_ADDR +
                    MAILBOX_STATUS_OFFSET
                );


#if DEBUG_DUMP_RESULTS

            if (status != last_status)
            {
                xil_printf(
                    "Mailbox STATUS = %lu\r\n",
                    (unsigned long)status
                );
            }

#endif

            last_status =
                status;


            /*
             * PL has published a fresh image.
             */
            if (status ==
                MAILBOX_STATUS_IMAGE_READY)
            {
                https_prepare_request();
            }
        }


        /*
         * HTTPS request/response in progress.
         */
        else if (https_state !=
                 HTTPS_FAILED)
        {
            https_process();
        }
    }


    /*
     * A persistent connection should remain alive for
     * the entire batch. If it dies before image 99 has
     * completed, treat that as an experimental error.
     */
    if (tcp_eof &&
        !tls_failed &&
        total_count < TEST_IMAGE_COUNT)
    {
        xil_printf(
            "\r\nERROR: remote connection closed "
            "after %lu completed images.\r\n",
            (unsigned long)total_count
        );

        error_count++;

        write_summary();

        tls_failed = 1;
    }


    return 0;
}


/* ============================================================
 * Status helpers
 * ============================================================ */

int cloud_dns_complete(void)
{
    return dns_complete;
}


int cloud_dns_success(void)
{
    return dns_success;
}


const ip_addr_t *cloud_get_ip(void)
{
    if (!dns_success)
    {
        return NULL;
    }

    return &cloud_ip;
}
