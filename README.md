# Open source flash cartridge for Fami

**⚠️ This project is currently in active development stage**

## Hardware Features

- **8MB SDRAM** - Single SDRAM module for loading both PRG and CHR data with fast access and execution
- **MachXO2 FPGA** - Main logic implemented in Lattice MachXO2 FPGA
- **ARM processor** - Dedicated ARM processor handles ROM loading from SD card and system management
- **Simple PCB design** - Circuit design optimized for hand assembly and DIY builds
- **USB programming port** - USB interface for firmware updates and development

## Current Status

- [x] **Game loading from flash storage** - Successfully implemented ROM loading and execution from SD card
- [x] **Mappers supported** - Implementation of popular cartridge mappers:
  - **NROM** (Mapper 0)
  - **MMC1** (Mapper 1)
  - **UxROM** (Mapper 2)
  - **CNROM** (Mapper 3)

## Planned Features

- [ ] **Extended mapper support** - Adding support for a larger number of mappers to increase game compatibility
- [ ] **FDS support** - Support for loading FDS disk images
- [ ] **Save states** - Save and load game progress at any point during gameplay

## PCB Image
![PCB Image](pcb.jpg)
