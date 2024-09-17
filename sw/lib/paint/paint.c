#include "paint.h"
#include <string.h>

struct paint_nametable {
    uint8_t t[1024];
};

void paint_pallete(uint8_t background, uint8_t highlight, uint8_t foreground)
{
    uint8_t tx[16] = { background, highlight, foreground, foreground };
    // send tx
}

void paint_start(struct paint_nametable *nm)
{
    memset(nm, 0, sizeof(*nm));
}

void paint_text(struct paint_nametable *nm, uint16_t r, uint8_t c, const char *str, bool highlight)
{
    assert(r < 30);
    assert(c < 32);

    for (uint16_t i = 0; str[i] != 0 && (c + i) < 32; i++) {
        nm->t[r * 30 + c + i] = str[i] - 0x20 + highlight ? 60 : 0;
    }
}

void paint_end(struct paint_nametable *nm)
{
    // send nm->t
}
