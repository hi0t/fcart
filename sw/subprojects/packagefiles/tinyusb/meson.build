project('tinyusb', 'c', version: '0.20.0')

tinyusb_src = files(
    'src/class/cdc/cdc_device.c',
    'src/class/msc/msc_device.c',
    'src/common/tusb_fifo.c',
    'src/device/usbd.c',
    'src/device/usbd_control.c',
    'src/portable/synopsys/dwc2/dcd_dwc2.c',
    'src/portable/synopsys/dwc2/dwc2_common.c',
    'src/tusb.c',
)

tinyusb_inc = include_directories('src')

tinyusb_dep = declare_dependency(
    sources: tinyusb_src,
    include_directories: tinyusb_inc,
)

meson.override_dependency('tinyusb', tinyusb_dep)
