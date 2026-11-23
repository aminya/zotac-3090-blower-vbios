# RTX 3090 blower: Resizable BAR research

This note records why the project uses a pre-driver PCI resize and what was observed. For setup instructions, see the [README](../README.md#resizable-bar).

## Result

On one Zotac RTX 3090 blower (`10de:2204/19da:1625`, VBIOS `94.02.42.00.02`), an experimental GRUB entry ran [geforce-bar1-resize](https://github.com/noon-at-cgn/geforce-bar1-resize) before the NVIDIA driver:

- Linux allocated a **32 GiB BAR1** and `resource1_resize` reported `000000000000ffc0`.
- NVIDIA driver `620.73.04` bound the card; LACT reported ReBAR enabled and a 32 GiB CPU-accessible window.
- The VBIOS override module parameters were present. No firmware was flashed.
- Full CPU access to VRAM, workload stability and repeat boots were not verified. The optional `RMForceStaticBar1=0` setting was not used.

The aperture is a PCI address window, not extra VRAM. The test entry uses a separate initramfs and does not save itself as the GRUB default; the existing loader-managed entry remains the fallback.

## Why a PCI resize?

- The original card exposed a 256 MiB BAR1. Zotac support identified it as an OEM card and did not identify a compatible system-integrator update.
- The card passed the resize tool’s six PCI-structure checks. The successful boot used its volatile `0x610` route with `VAL=9`, then resized BAR1 to 32 GiB.
- `gpu_unlock` performs a reset before NVIDIA loads. The experimental initramfs service runs the resize after loading `gpu_unlock` and before NVIDIA module loading and udev.
- The ordinary resize service expects NVIDIA to load after the initramfs; this system loads it inside the initramfs. The combined image is separate from the loader-managed image and is not validated by the loader’s integrity checks.
- A reset can clear the PCI override. Failure recovery, update handling and other hardware need further testing.

The NVIDIA VBIOS override passes a candidate image to the driver. The [Linux GA102 VBIOS documentation](https://github.com/torvalds/linux/blob/master/Documentation/gpu/nova/core/vbios.rst) describes initialization from the physical ROM before the driver loads. That timing may explain why a later driver override did not change the initial PCI capability; it does not identify the relevant ROM field.

## Trinity comparisons

Two same-model before/after comparisons showed a change at full-ROM offset `0x84ccf` from `02` to `09`. Both updated images are reported as supporting ReBAR. This is evidence of an association, not proof that the byte alone enables ReBAR or that it is valid on the blower.

| Pair | Before | After | Other differences |
| --- | --- | --- | --- |
| Trinity OC, VBIOS `94.02.42.80.9F` | [2021-01-06](https://www.techpowerup.com/vgabios/229495/zotac-rtx3090-24576-210106), SHA-1 `c27bd9062c85cb409a04c62f7b8257f9018944d1` | Image extracted from Zotac’s updater, SHA-256 `2f6d04e6e26ceecdd8106d7a5163bb3eb201f5059348f979ce0240d2cbf94eee` | 2,088 bytes in IFR; four other bytes in the PCI image chain, including date and checksum changes. |
| Trinity, VBIOS `94.02.42.80.1F` | [2020-12-10](https://www.techpowerup.com/vgabios/232560/zotac-rtx3090-24576-201210), SHA-1 `35e5fd4f849bfc6e10411813c4e13baec3931b41` | [2021-03-05](https://www.techpowerup.com/vgabios/233619/zotac-rtx3090-24576-210305-2), SHA-1 `a64adb941aa241263b2d43563f45657d09195c3b` | 2,160 bytes in IFR and 284 other bytes in the PCI image chain. |

The local before-image hashes match the cited third-party listings. The Trinity updater’s complete 999,424-byte image includes a 37,376-byte IFR prefix; comparisons must account for that prefix. The other differences have not been decoded. Do not load or flash a Trinity ROM onto the blower.

## Blower ROM candidate

A candidate derived from the fan profile changed `0x84ccf` from `02` to `09` and adjusted the FwSec checksum at `0x8f3ff` from `de` to `d7`. These were the only two changes relative to that fan profile. The candidate ROM’s SHA-256 is `4992a443dc59ee97b0fa3a8e3500ee2442dbb9dc01b57e7cd4abc8fe487d9da5`.

- Vix Editor reported the recognized ROM checksums valid; cryptographic signatures were not verified.
- Its experimental relocated loader payload has SHA-256 `a4d5009e983ddc8076584331af912bc185201bfcce58ceed077e7c37358300df`. A separate verify returned `INTEGRITY_NOT_VERIFIED`; the export manifest limits verification to normalization from the source.
- A boot using the candidate through the VBIOS loader still advertised a maximum 256 MiB BAR before the separate PCI resize was added. Loader status showed matching parameters but `applied: unknown`.
- The candidate was not flashed. Its effect, firmware signature implications and suitability for other boards are unknown. The successful ReBAR result does not prove the ROM edit enabled ReBAR.
