# EMNIST FPGA Cloud Live Classification — Development and Troubleshooting Record

**Project:** ZedBoard Rev E / Zynq-7020, OV7670 camera, Google Cloud Run EMNIST Balanced classifier  
**Development tools:** Vivado 2018.1 and Xilinx SDK 2018.1  
**Purpose:** Record the implementation and functional validation of the **live camera-to-cloud proof of concept**, including troubleshooting from the development conversation.  
**Scope:** This is **not** the controlled classification measurement log, power measurement log, or Cloud Run service repository. These are maintained separately.

## 1. Confirmed outcome

- The live camera-to-cloud classification pipeline was successfully demonstrated.
- A handwritten **F** was correctly classified in the live demonstration, as confirmed by the researcher after building and testing the revised design.
- The researcher has a **video of the successful classification** and a **photograph of the ZedBoard**. Add their actual filenames below after committing them.
- This establishes a working proof of concept for the observed input, **not** a quantitative live-camera accuracy rate or a comprehensive reliability test.

**Evidence files to add (actual filenames not yet provided):**

| Evidence | Repository path to use | Status |
|---|---|---|
| Live classification video | `evidence/live_classification_video.<extension>` | Researcher reports possessing it; not attached here |
| ZedBoard photograph | `evidence/zedboard_photo.<extension>` | Researcher reports possessing it; not attached here |
| Vivado PS/AXI/BRAM block design schematic | `schematics/zedboard_ps_axi_bram_block_design.pdf` | Export from the verified working project |
| Elaborated RTL schematic of the live camera/BRAM/mailbox path | `schematics/live_camera_mailbox_rtl.pdf` | Export from the verified working project, if readable |

Avoid claiming that the schematic files are included until actually exported and committed.

## 2. Architecture reused from MNIST

The EMNIST proof of concept reused the MNIST FPGA cloud-assistance workflow rather than developing a separate transport architecture:

1. OV7670 camera captures the live frame.
2. FPGA selects and preprocesses a **28 × 28** region (784 eight-bit values), stores it in local BRAM, and freezes a completed image on capture.
3. FPGA writes the 784 bytes into the **PL/PS shared BRAM mailbox**, packing four bytes per 32-bit word.
4. ARM application reads the mailbox and sends the image as a raw `application/octet-stream` HTTPS POST to the Cloud Run `/predict` endpoint.
5. Remote EMNIST CNN returns a classification in the **0–46** class range.
6. ARM writes the prediction into the mailbox; FPGA reads the result and presents the six-bit class on LEDs.

Only the **image payload, data path, embedded client, and return result** are discussed in this branch. Cloud service deployment and model hosting belong in the separate Cloud Run branch.

### Relevant PL/PS mailbox values

| Address/offset | Meaning |
|---|---|
| BRAM mapped base `0x40000000` | ARM-accessible shared mailbox |
| `0x000`–`0x30C` | 196 image words (784 bytes) |
| `0x310` | Handshake: 0 = idle, 1 = image ready, 2 = prediction ready |
| `0x314` | Image index; live capture uses 0 |
| `0x318` | Returned predicted class |
| `0x31C` | Expected class; live capture uses `0xFF` (unknown ground truth) |

### Live FPGA indicators in the prepared top module

| LED | Function |
|---|---|
| LED7 | Result-ready indicator |
| LED6 | Inference-busy indicator |
| LED5–LED0 | Six-bit predicted class (0–46) |

The live-camera control is **capture-button driven**, not the continuous 100-image test loop. The existing `sw_view_stored` switch selects the VGA thumbnail view. The capture button freezes a completed ROI; a subsequent button press unfreezes the camera, permitting another capture.

## 3. Vivado project adaptation

### Initial state

The researcher **copied the existing Vivado EMNIST project** to create the live cloud proof of concept. Earlier controlled EMNIST configurations had used a 100-image ROM for repeatable dataset benchmarking and, in the original local inference project, a locally implemented CNN.

### Changes to the live version

- Removed the locally executed EMNIST model hierarchy, identified in discussion as **`emnist_complete_cnn_bram_top`**, from the cloud-only project. The removal was to eliminate a local inference implementation not needed when the CNN executes remotely.
- Removed the controlled test-image ROM component **`blk_mem_gen_1`** and the **`emnist_test_rom_pkg`** expected-label package from the final live version.
- Preserved the OV7670 controller/capture modules, live camera framebuffer (`blk_mem_gen_0`), 28 × 28 processed-image memory (`blk_mem_gen_stored`), VGA, clocking/debounce, and shared mailbox interface.
- Changed the FPGA top module so that the live stored 28 × 28 image supplies the mailbox instead of the 100-image test ROM.
- Preserved byte packing and mailbox status/result offsets established during the MNIST cloud implementation.
- Updated the predicted-class register/output to **six bits** for EMNIST Balanced's 47 classes.
- Changed the live request metadata to image index **0** and expected label **255 (`0xFF`)** so captured images do not get counted as incorrectly classified labeled test images.

**Prepared top-module source** (maintained in the corresponding *Live Classification Code* branch): `top_emnist_live_cloud.vhd`. The exact file committed should be the final version verified on hardware, rather than an untested draft.

### Vivado schematic exports recommended for this data/notebook branch

**Essential:** Export the **implemented project's IP Integrator block diagram** (`design_1`) showing the Zynq processing system, AXI path, BRAM controller, shared BRAM and connection of the PL top-level/mailbox signals. A vector PDF is preferred to a screen capture. Also keep the actual `.bd` source in the code branch.

**Useful second schematic:** In **Open Elaborated Design**, navigate to the camera/preprocessing/stored BRAM and PL mailbox control hierarchy and export a *readable targeted schematic* (rather than the entire flattened design, which is typically illegible). Show the source BRAM read path feeding the mailbox and the prediction/status return. Prefer PDF or SVG where supported by the installed Vivado version, using its schematic print/export capability.

The **full CNN schematic is not needed in the live cloud data branch** because the local CNN was removed. Store the original local model design in the local FPGA code branch. Likewise, utilization reports and benchmark-ROM schematics belong in the measurement branch unless a single architecture comparison is desired for explanatory context.

## 4. Xilinx SDK application adaptation

The reused ARM application already contained an infinite `while (1)` polling loop that serviced Ethernet, lwIP TCP timers, DNS timers and `transfer_data()`. It did **not** require a replacement networking architecture for the live-camera demonstration.

### `main.c`

- Retained the working DHCP/DNS setup, connection startup and main polling loop.
- Disabled the automatic 100-image results dump: `#define AUTO_DUMP_RESULTS 0`.

### `tcp_client.c`

- Reused the working Mbed TLS/lwIP HTTP client and mailbox read/write procedures.
- Kept the 784-byte binary request and existing `/predict` endpoint.
- Confirmed the response parser can accept integer predictions from **0 through 46**.
- Treated **expected label `0xFF`** as unknown ground truth, not an incorrect classification.
- Provided a live-camera status message reporting the returned class and request latency, instead of printing a misleading `WRONG` label for unlabeled captures.
- Retained the shared BRAM result-then-status signaling order so the PL receives the classification.

**Prepared SDK sources** (maintained in the corresponding *Live Classification Code* branch): `main_emnist_live_cloud.c` and `tcp_client_emnist_live_cloud.c`. The researcher subsequently resolved a syntax issue in the actual SDK copy; the committed sources should reflect that corrected working build.

## 5. Troubleshooting record

This section summarizes **problems actually discussed** and their observed resolution or status. It does not reconstruct absent console output or invent additional tests.

### A. Transitioning from controlled ROM images to live camera images

**Issue:** The copied project initially represented controlled 100-image cloud measurements, not an interactive live demonstration. The inference flow used a test ROM and expected labels.

**Change:** Modified the PL top module to read the processed camera image from `blk_mem_gen_stored`, triggered by completing a frozen capture. The PL packed 784 bytes into the mailbox, published status 1, waited for status 2, then latched the returned six-bit prediction and cleared the mailbox.

**Outcome:** The researcher subsequently reported a successful live handwritten **F** classification. No standalone register-level trace of this exact run was supplied.

### B. Removing unnecessary local inference hardware

**Issue:** The cloud-assisted version did not need the local CNN or its parameter storage. The researcher identified the module `emnist_complete_cnn_bram_top` for removal.

**Action:** Removed model-specific hierarchy from the cloud-only Vivado project, retaining camera, FPGA image storage, Zynq PS and mailbox components. Removed the controlled image ROM for the final live version.

**Outcome:** The later successful live classification demonstrated that the local model was not required for the observed cloud path. This statement does **not** mean every deleted file has been individually audited.

### C. SDK `main.c` compiler errors

**Observed SDK Problems-window symptoms:**

- `unknown type name 'ip_addr_t'`
- `storage size of 'server_netif' isn't known`
- `PLATFORM_EMAC_BASEADDR` undeclared
- `dereferencing pointer to incomplete type 'struct netif'`
- `expected '=', ',', ';', 'asm' or '__attribute__' before '.' token`
- `expected expression before ')' token`
- `make: *** [src/main.o] Error 1`

**Initial discussion:** These appeared consistent with a broken C translation unit or missing BSP/lwIP declarations. Checking the BSP was proposed as a diagnostic, but **was not established as the cause**.

**Confirmed cause and resolution:** The researcher reported: **“it was a comment that got cut in two.”** After correcting the malformed comment, the application compiled and **accurately predicted F**. Therefore, the earlier missing-type and unexpected-token errors should be recorded as cascading compile errors from malformed source, **not** as a confirmed missing BSP or lwIP failure.

### D. Demonstrating correct camera-to-cloud behavior

**Observation:** After fixing the source comment, the researcher reported that the live EMNIST system **correctly predicted F**.

**Evidence:** The researcher has a video of the successful classification and a photograph of the board. Insert the video and photo at their true GitHub paths and describe what is directly visible in each. Do not invent UART latency or additional character trials.

**Interpretation:** This was a successful end-to-end functional demonstration: acquisition and preprocessing on FPGA, mailbox exchange with ARM, HTTPS communication, cloud classification and FPGA presentation of the result. A single example is not a numerical classification-accuracy study.

## 6. Evidence index for the GitHub branch

Fill in the actual filenames after upload:

| Item | GitHub relative path | Description |
|---|---|---|
| Working demonstration | `evidence/REPLACE_WITH_VIDEO_FILENAME` | Video showing live handwritten F classification |
| Hardware photograph | `evidence/REPLACE_WITH_PHOTO_FILENAME` | Photograph of ZedBoard/camera/display setup |
| Vivado IP block schematic | `schematics/REPLACE_WITH_BLOCK_DESIGN_FILENAME` | Zynq PS / AXI / BRAM mailbox connectivity |
| Live PL data-path schematic | `schematics/REPLACE_WITH_RTL_SCHEMATIC_FILENAME` | Camera capture, stored BRAM, mailbox logic |
| Live source files | Link to separate `EMNIST-FPGA-Cloud-Live-Classification-Code` branch | Final hardware/software implementation |
| Cloud service source | Link to separate Cloud Run branch | Model serving and deployment details |

## 7. Reproducibility and limitations

- Development: Vivado 2018.1 and Xilinx SDK 2018.1 on ZedBoard Rev E.
- Dataset/model: EMNIST Balanced, 47 classes; remote CNN handles classification.
- Camera: OV7670; FPGA generates 28 × 28 × 8-bit input.
- Shared memory: Zynq PL/PS dual-port BRAM mailbox; ARM-accessible base `0x40000000`.
- Networking: Ethernet, DHCP, DNS, TCP, HTTPS/TLS to the Cloud Run inference endpoint.
- Development security limitation: the embedded TLS configuration disabled server certificate verification and used deterministic, non-cryptographic development entropy. A successful TLS connection therefore did not establish authenticated remote identity. These limitations are documented here as observed implementation properties, **not** as recommended production settings.
- The photograph and video are the retained functional evidence; no independent live-run serial log is supplied in this record.
- Do not infer live-camera statistical accuracy from the one successful F prediction.
- Formal labeled-image accuracy, latency, power, throughput and FPGA utilization measurements are documented in the dedicated **Classification Measurement Notebook and Data** branch.

---

*Prepared from the development conversation and the available EMNIST live top-module/SDK source files. This record distinguishes the researcher's confirmed observed outcome from proposed intermediate implementation changes and does not claim to reproduce absent evidence.*
