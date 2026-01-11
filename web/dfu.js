// Implements USB DFU 1.1 Specification
// Based on ST Application Note AN3156

export class DFULoader {
    dfuRequest = {
        DFU_DETACH: 0x00,
        DFU_DNLOAD: 0x01,
        DFU_UPLOAD: 0x02,
        DFU_GETSTATUS: 0x03,
        DFU_CLRSTATUS: 0x04,
        DFU_GETSTATE: 0x05,
        DFU_ABORT: 0x06
    }

    dfuState = {
        STATE_APP_IDLE: 0,
        STATE_APP_DETACH: 1,
        STATE_IDLE: 2,
        STATE_DNLOAD_SYNC: 3,
        STATE_DNBUSY: 4,
        STATE_DNLOAD_IDLE: 5,
        STATE_MANIFEST_SYNC: 6,
        STATE_MANIFEST: 7,
        STATE_MANIFEST_WAIT_RESET: 8,
        STATE_UPLOAD_IDLE: 9,
        STATE_ERROR: 10
    }

    dfuError = {
        OK: 0,
        ERROR_TARGET: 1,
        ERROR_FILE: 2,
        ERROR_WRITE: 3,
        ERROR_ERASE: 4,
        ERROR_CHECK_ERASED: 5,
        ERROR_PROG: 6,
        ERROR_VERIFY: 7,
        ERROR_ADDRESS: 8,
        ERROR_NOTDONE: 9,
        ERROR_FIRMWARE: 10,
        ERROR_VENDOR: 11,
        ERROR_USBR: 12,
        ERROR_POR: 13,
        ERROR_UNKNOWN: 14,
        ERROR_STALLEDPKT: 15
    }

    constructor() {
        this.device = null;
        this.chunkSize = 0x800; // Default transfer size
        this.log = console.log;   // Custom logger
        this.progress = (pct) => { }; // Custom progress callback
    }

    setLogger(logFn) {
        this.log = logFn;
    }

    setProgressCallback(cb) {
        this.progress = cb;
    }

    async connect() {
        this.device = await navigator.usb.requestDevice({
            filters: [
                { vendorId: 0x0483 }, // STMicroelectronics
            ]
        });

        await this.device.open();
        this.log(`Connected to: ${this.device.productName} (Serial: ${this.device.serialNumber})`);

        await this.device.selectConfiguration(1);

        await this.device.claimInterface(0);

        // Get Status to clear any errors
        await this.clearStatus();

        this.log("Device ready.");
    }

    async runUpdateSequence(data, startAddress = 0x08000000) {
        const totalSize = data.byteLength;

        try {
            await this.erase(startAddress, totalSize);
            await this.flash(data, startAddress);
            await this.detach();

            this.disconnect();
            this.log("Update complete.");
        } catch (error) {
            this.disconnect();
            throw error;
        }
    }

    async disconnect() {
        if (this.device != null) {
            if (this.device.opened) {
                // Close the USB device
                await this.device.close();
            }
        }
        this.device = null;
    }

    async waitPollTimeout(interval) {
        if (interval > 0) {
            await new Promise(r => setTimeout(r, interval));
        }
    }

    async pollUntilIdle() {
        let state = await this.getStatus();
        while (state == this.dfuState.STATE_DNBUSY) {
            state = await this.getStatus();
        }
    }

    async getStatus() {
        const result = await this.device.controlTransferIn({
            requestType: 'class',
            recipient: 'interface',
            request: this.dfuRequest.DFU_GETSTATUS,
            value: 0,
            index: 0
        }, 6);

        let error = result.data.getUint8(0);
        let state = result.data.getUint8(4);
        let pollTime = (result.data.getUint8(3) << 16) | (result.data.getUint8(2) << 8) | result.data.getUint8(1);

        await this.waitPollTimeout(pollTime);

        if (error != this.dfuError.OK) {
            throw new Error("DFU Error: " + error + ", State: " + state);
        }

        return state;
    }

    async clearStatus() {
        const result = await this.device.controlTransferOut({
            requestType: 'class',
            recipient: 'interface',
            request: this.dfuRequest.DFU_CLRSTATUS,
            value: 0,
            index: 0
        }, undefined);

        if (result.status !== 'ok') {
            throw new Error("Failed to clear DFU status");
        }
    }

    async download(blockNum, data) {
        // DFU_DNLOAD = 0x01
        return this.device.controlTransferOut({
            requestType: 'class',
            recipient: 'interface',
            request: this.dfuRequest.DFU_DNLOAD,
            value: blockNum,
            index: 0
        }, data);
    }

    async erase(startAddress, length) {
        this.log("Erasing...");
        this.progress(0);

        const endAddress = startAddress + length;
        let currentAddress = startAddress;

        while (currentAddress < endAddress) {
            // Determine sector size for STM32F4
            // Sectors 0-3: 16KB (0x4000)
            // Sector 4:    64KB (0x10000)
            // Sector 5-11: 128KB (0x20000)
            let sectorSize = 0;
            const offset = currentAddress - startAddress;

            if (offset < 0x10000) { // First 64KB (Sectors 0-3)
                sectorSize = 0x4000; // 16KB
            } else if (offset < 0x20000) { // Next 64KB (Sector 4)
                sectorSize = 0x10000; // 64KB
            } else { // Rest (Sector 5+)
                sectorSize = 0x20000; // 128KB
            }

            const cmd = new Uint8Array(5);
            cmd[0] = 0x41;
            cmd[1] = currentAddress & 0xFF;
            cmd[2] = (currentAddress >> 8) & 0xFF;
            cmd[3] = (currentAddress >> 16) & 0xFF;
            cmd[4] = (currentAddress >> 24) & 0xFF;

            await this.download(0, cmd); // wBlockNum = 0 for commands

            // Wait for erase to finish
            await this.pollUntilIdle();

            // Progress Update
            const p = Math.floor((offset / length) * 100);
            this.progress(p);

            currentAddress += sectorSize;
        }

        this.progress(100);
        this.log("Erase complete.");
    }

    async flash(data, startAddress) {
        this.log("Starting Flash...");
        this.progress(0);

        // 1. SET ADDRESS POINTER
        // Command: 0x21, Addr(4)
        const ptrCmd = new Uint8Array(5);
        ptrCmd[0] = 0x21; // Set Address Pointer
        ptrCmd[1] = startAddress & 0xFF;
        ptrCmd[2] = (startAddress >> 8) & 0xFF;
        ptrCmd[3] = (startAddress >> 16) & 0xFF;
        ptrCmd[4] = (startAddress >> 24) & 0xFF;
        await this.download(0, ptrCmd);

        // Issue a get status to apply the operation
        await this.pollUntilIdle();

        // 2. DOWNLOAD BLOCKS
        // wBlockNum starts at 2 for data (0 and 1 are reserved/commands often)
        let blockNum = 2;
        let offset = 0;
        const totalSize = data.byteLength;

        while (offset < totalSize) {
            const end = Math.min(offset + this.chunkSize, totalSize);
            const chunk = new Uint8Array(data.slice(offset, end));

            await this.download(blockNum, chunk);

            // Issue a get status to apply the operation
            await this.pollUntilIdle();

            // Next block, wrap around if needed (though usually not for this size)
            // But standard DFU says wBlockNum wraps 0-65535
            blockNum++;
            offset += this.chunkSize;

            const p = Math.floor((offset / totalSize) * 100);
            this.progress(p);
        }
        this.log("Flashing done.");
        this.progress(100);
    }

    // Exit DFU mode and start application
    async detach() {
        this.log("Starting application...");

        // Next download 0 bytes to the device
        await this.download(0, new Uint8Array(0));

        // Finally read the status to trigger a reset
        await this.getStatus();
    }
}
