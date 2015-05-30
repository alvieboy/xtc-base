
void spi_select(volatile unsigned int *base, unsigned int val)
{
    *(base+2) = val;
}

unsigned int spi_transfer8(volatile unsigned int *base, unsigned int val)
{
    *(base+1) = val;
    return *(base+1);
}

unsigned int spi_recv8(volatile unsigned int *base)
{
    return *(base+1);
}

void spi_send8(volatile unsigned int *base, unsigned int val)
{
    *(base+1) = val;
}

unsigned int spi_transfer16(volatile unsigned int *base, unsigned int val)
{
    *(base+(4+1)) = val;
    return *(base+(4+1));
}

unsigned int spi_transfer24(volatile unsigned int *base, unsigned int val)
{
    *(base+(8+1)) = val;
    return *(base+(8+1));
}

unsigned int spi_transfer32(volatile unsigned int *base, unsigned int val)
{
    *(base+(12+1)) = val;
    return *(base+(12+1));
}
