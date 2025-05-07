#include "jtag.h"
#include "internal.h"
#include <assert.h>
#include <errno.h>

#include <log.h>

LOG_MODULE(jtag);

#define SPI_TIMEOUT 1000

enum jtag_tap_state state;

static void set_spi_mode();
static void set_gpio_mode();
static void tms_seq(uint32_t tms, uint8_t len);
static int tdi_tdo_seq(const uint8_t *tdi, uint8_t *tdo, uint32_t len, bool tms, bool hold_tms);

void jtag_resume()
{
    GPIO_InitTypeDef gpio = {
        .Pin = GPIO_SPI2_CS_PIN,
        .Mode = GPIO_MODE_OUTPUT_PP,
        .Pull = GPIO_NOPULL,
        .Speed = GPIO_SPEED_FREQ_HIGH,
    };
    struct peripherals *p = get_peripherals();

    __HAL_SPI_ENABLE(&p->hspi2);

    set_gpio_mode();

    HAL_GPIO_WritePin(GPIO_SPI2_CS_PORT, GPIO_SPI2_CS_PIN, GPIO_PIN_SET);
    HAL_GPIO_Init(GPIO_SPI2_CS_PORT, &gpio);
}

void jtag_suspend()
{
    GPIO_InitTypeDef gpio = {
        .Mode = GPIO_MODE_ANALOG,
        .Pull = GPIO_NOPULL
    };
    struct peripherals *p = get_peripherals();

    __HAL_SPI_DISABLE(&p->hspi2);

    gpio.Pin = GPIO_SPI2_CS_PIN;
    HAL_GPIO_Init(GPIO_SPI2_CS_PORT, &gpio);
    gpio.Pin = GPIO_SPI2_CLK_PIN;
    HAL_GPIO_Init(GPIO_SPI2_CLK_PORT, &gpio);
    gpio.Pin = GPIO_SPI2_MISO_PIN;
    HAL_GPIO_Init(GPIO_SPI2_MISO_PORT, &gpio);
}

void jtag_reset()
{
    tms_seq(0xFF, 6);
    state = JTAG_TEST_LOGIC_RESET;
}

void jtag_select_state(enum jtag_tap_state next_state)
{
    bool tms = 0;
    uint32_t tms_states = 0;
    uint8_t cnt = 0;
    while (next_state != state) {
        switch (state) {
        case JTAG_TEST_LOGIC_RESET:
            if (next_state == JTAG_TEST_LOGIC_RESET) {
                tms = 1;
            } else {
                tms = 0;
                state = JTAG_RUN_TEST_IDLE;
            }
            break;
        case JTAG_RUN_TEST_IDLE:
            if (next_state == JTAG_RUN_TEST_IDLE) {
                tms = 0;
            } else {
                tms = 1;
                state = JTAG_SELECT_DR_SCAN;
            }
            break;
        case JTAG_SELECT_DR_SCAN:
            switch (next_state) {
            case JTAG_CAPTURE_DR:
            case JTAG_SHIFT_DR:
            case JTAG_EXIT1_DR:
            case JTAG_PAUSE_DR:
            case JTAG_EXIT2_DR:
            case JTAG_UPDATE_DR:
                tms = 0;
                state = JTAG_CAPTURE_DR;
                break;
            default:
                tms = 1;
                state = JTAG_SELECT_IR_SCAN;
            }
            break;
        case JTAG_SELECT_IR_SCAN:
            switch (next_state) {
            case JTAG_CAPTURE_IR:
            case JTAG_SHIFT_IR:
            case JTAG_EXIT1_IR:
            case JTAG_PAUSE_IR:
            case JTAG_EXIT2_IR:
            case JTAG_UPDATE_IR:
                tms = 0;
                state = JTAG_CAPTURE_IR;
                break;
            default:
                tms = 1;
                state = JTAG_TEST_LOGIC_RESET;
            }
            break;
        case JTAG_CAPTURE_DR:
            if (next_state == JTAG_SHIFT_DR) {
                tms = 0;
                state = JTAG_SHIFT_DR;
            } else {
                tms = 1;
                state = JTAG_EXIT1_DR;
            }
            break;
        case JTAG_SHIFT_DR:
            if (next_state == JTAG_SHIFT_DR) {
                tms = 0;
            } else {
                tms = 1;
                state = JTAG_EXIT1_DR;
            }
            break;
        case JTAG_EXIT1_DR:
            switch (next_state) {
            case JTAG_PAUSE_DR:
            case JTAG_EXIT2_DR:
            case JTAG_SHIFT_DR:
            case JTAG_EXIT1_DR:
                tms = 0;
                state = JTAG_PAUSE_DR;
                break;
            default:
                tms = 1;
                state = JTAG_UPDATE_DR;
            }
            break;
        case JTAG_PAUSE_DR:
            if (next_state == JTAG_PAUSE_DR) {
                tms = 0;
            } else {
                tms = 1;
                state = JTAG_EXIT2_DR;
            }
            break;
        case JTAG_EXIT2_DR:
            switch (next_state) {
            case JTAG_SHIFT_DR:
            case JTAG_EXIT1_DR:
            case JTAG_PAUSE_DR:
                tms = 0;
                state = JTAG_SHIFT_DR;
                break;
            default:
                tms = 1;
                state = JTAG_UPDATE_DR;
            }
            break;
        case JTAG_UPDATE_DR:
        case JTAG_UPDATE_IR:
            if (next_state == JTAG_RUN_TEST_IDLE) {
                tms = 0;
                state = JTAG_RUN_TEST_IDLE;
            } else {
                tms = 1;
                state = JTAG_SELECT_DR_SCAN;
            }
            break;
            /* IR column */
        case JTAG_CAPTURE_IR:
            if (next_state == JTAG_SHIFT_IR) {
                tms = 0;
                state = JTAG_SHIFT_IR;
            } else {
                tms = 1;
                state = JTAG_EXIT1_IR;
            }
            break;
        case JTAG_SHIFT_IR:
            if (next_state == JTAG_SHIFT_IR) {
                tms = 0;
            } else {
                tms = 1;
                state = JTAG_EXIT1_IR;
            }
            break;
        case JTAG_EXIT1_IR:
            switch (next_state) {
            case JTAG_PAUSE_IR:
            case JTAG_EXIT2_IR:
            case JTAG_SHIFT_IR:
            case JTAG_EXIT1_IR:
                tms = 0;
                state = JTAG_PAUSE_IR;
                break;
            default:
                tms = 1;
                state = JTAG_UPDATE_IR;
            }
            break;
        case JTAG_PAUSE_IR:
            if (next_state == JTAG_PAUSE_IR) {
                tms = 0;
            } else {
                tms = 1;
                state = JTAG_EXIT2_IR;
            }
            break;
        case JTAG_EXIT2_IR:
            switch (next_state) {
            case JTAG_SHIFT_IR:
            case JTAG_EXIT1_IR:
            case JTAG_PAUSE_IR:
                tms = 0;
                state = JTAG_SHIFT_IR;
                break;
            default:
                tms = 1;
                state = JTAG_UPDATE_IR;
            }
            break;
        }
        tms_states <<= 1u;
        tms_states |= tms;
        cnt++;
        assert(cnt <= 32);
    }
    if (cnt > 0) {
        tms_seq(tms_states, cnt);
    }
}

int jtag_shift_ir(const uint8_t *tdi, uint32_t len, enum jtag_tap_state end_state)
{
    int rc;

    if (state != JTAG_SHIFT_IR) {
        jtag_select_state(JTAG_SHIFT_IR);
    }

    if ((rc = tdi_tdo_seq(tdi, NULL, len, false, end_state != JTAG_SHIFT_IR)) != 0) {
        return rc;
    }

    if (end_state != JTAG_SHIFT_IR) {
        state = JTAG_EXIT1_IR;
        jtag_select_state(end_state);
    }
    return 0;
}

int jtag_shift_dr(const uint8_t *tdi, uint8_t *tdo, uint32_t len, enum jtag_tap_state end_state)
{
    int rc;

    if (state != JTAG_SHIFT_DR) {
        jtag_select_state(JTAG_SHIFT_DR);
    }

    if ((rc = tdi_tdo_seq(tdi, tdo, len, false, end_state != JTAG_SHIFT_DR)) != 0) {
        return rc;
    }

    if (end_state != JTAG_SHIFT_DR) {
        state = JTAG_EXIT1_DR;
        jtag_select_state(end_state);
    }
    return 0;
}

int jtag_toggle_clk(uint32_t len)
{
    return tdi_tdo_seq(NULL, NULL, len, true, false);
}

static void set_spi_mode()
{
    GPIO_InitTypeDef gpio = {
        .Mode = GPIO_MODE_AF_PP,
        .Pull = GPIO_NOPULL,
        .Speed = GPIO_SPEED_FREQ_HIGH,
        .Alternate = GPIO_AF5_SPI2,
    };
    gpio.Pin = GPIO_SPI2_CLK_PIN;
    HAL_GPIO_Init(GPIO_SPI2_CLK_PORT, &gpio);
    gpio.Pin = GPIO_SPI2_MISO_PIN;
    HAL_GPIO_Init(GPIO_SPI2_MISO_PORT, &gpio);
    gpio.Pin = GPIO_SPI2_MOSI_PIN;
    HAL_GPIO_Init(GPIO_SPI2_MOSI_PORT, &gpio);
}

static void set_gpio_mode()
{
    GPIO_InitTypeDef gpio = {
        .Mode = GPIO_MODE_OUTPUT_PP,
        .Pull = GPIO_NOPULL,
        .Speed = GPIO_SPEED_FREQ_HIGH,
    };

    gpio.Pin = GPIO_SPI2_CLK_PIN;
    HAL_GPIO_Init(GPIO_SPI2_CLK_PORT, &gpio);
    gpio.Pin = GPIO_SPI2_MOSI_PIN;
    HAL_GPIO_Init(GPIO_SPI2_MOSI_PORT, &gpio);

    gpio.Mode = GPIO_MODE_INPUT;
    gpio.Pin = GPIO_SPI2_MISO_PIN;
    HAL_GPIO_Init(GPIO_SPI2_MISO_PORT, &gpio);
}

static void tms_seq(uint32_t tms, uint8_t len)
{
    assert(len > 0 && len <= 32);

    uint32_t mask = 1u << (len - 1);
    uint32_t next_tms = tms & mask ? GPIO_SPI2_CS_PIN : GPIO_SPI2_CS_PIN << 16u;
    for (uint8_t i = 0; i < len; i++) {
        GPIO_SPI2_CS_PORT->BSRR = next_tms;

        GPIO_SPI2_CLK_PORT->BSRR = GPIO_SPI2_CLK_PIN;
        mask >>= 1u;
        next_tms = tms & mask ? GPIO_SPI2_CS_PIN : GPIO_SPI2_CS_PIN << 16u;
        GPIO_SPI2_CLK_PORT->BSRR = GPIO_SPI2_CLK_PIN << 16u;
    }
}

static void single_tdi_tdo_seq(uint8_t tdi, uint8_t *tdo, uint8_t len, bool hold_tms)
{
    assert(len > 0 && len <= 8);

    uint8_t mask = 1u;
    uint32_t next_tdi = tdi & mask ? GPIO_SPI2_MOSI_PIN : GPIO_SPI2_MOSI_PIN << 16u;
    for (uint8_t i = 0; i < len; i++) {
        if (hold_tms && i == len - 1) {
            GPIO_SPI2_CS_PORT->BSRR = GPIO_SPI2_CS_PIN;
        }
        GPIO_SPI2_MOSI_PORT->BSRR = next_tdi;

        GPIO_SPI2_CLK_PORT->BSRR = GPIO_SPI2_CLK_PIN;
        if (tdo != NULL && (GPIO_SPI2_MISO_PORT->IDR & GPIO_SPI2_MISO_PIN)) {
            *tdo |= mask;
        }
        mask <<= 1u;
        next_tdi = tdi & mask ? GPIO_SPI2_MOSI_PIN : GPIO_SPI2_MOSI_PIN << 16u;
        GPIO_SPI2_CLK_PORT->BSRR = GPIO_SPI2_CLK_PIN << 16u;
    }
}

static int tdi_tdo_seq(const uint8_t *tdi, uint8_t *tdo, uint32_t len, bool tms, bool hold_tms)
{
    assert(len > 0);

    struct peripherals *p = get_peripherals();
    SPI_TypeDef *spi = p->hspi2.Instance;
    uint32_t byte_len = len / 8;
    uint8_t bits_remain = len & 7u;
    uint32_t start = HAL_GetTick();
    const uint8_t *tx = tdi;
    uint8_t *rx = tdo;

    if (len % 8 == 0 && hold_tms) {
        byte_len--;
        bits_remain = 8;
    }

    GPIO_SPI2_CS_PORT->BSRR = tms ? GPIO_SPI2_CS_PIN : GPIO_SPI2_CS_PIN << 16u;

    if (byte_len > 0) {
        set_spi_mode();
        uint32_t tx_cnt = byte_len, rx_cnt = byte_len;
        bool is_tx = true;

        while (tx_cnt > 0 || rx_cnt > 0) {
            if (is_tx && (tx_cnt > 0) && (spi->SR & SPI_SR_TXE)) {
                spi->DR = (tx == NULL) ? 0 : *tx++;
                tx_cnt--;
                is_tx = false;
            }
            if ((rx_cnt > 0) && (spi->SR & SPI_SR_RXNE)) {
                if (rx == NULL) {
                    spi->DR;
                } else {
                    *rx = spi->DR;
                    rx++;
                }
                rx_cnt--;
                is_tx = true;
            }
            if (HAL_GetTick() - start > SPI_TIMEOUT) {
                return -EIO;
            }
        }
        set_gpio_mode();
    }

    if (bits_remain > 0) {
        single_tdi_tdo_seq(tx == NULL ? 0 : *tx, rx, bits_remain, hold_tms);
    }
    return 0;
}
