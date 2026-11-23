# Zotac RTX 3090 blower VBIOS fan profile

Give the Zotac RTX 3090 blower a quieter idle while keeping its automatic fan
curve. This profile lowers the stored minimum and first curve point on both fan
channels from 3,000 RPM / 60% to 1,000 RPM / 10%, and moves the first curve
temperature from 55°C to 45°C so the fan begins ramping earlier. Higher curve
points and extra curves remain unchanged.

On the card used for this project, LACT reported around **500 RPM at idle** and
an earlier ramp under load after the 45°C change. Actual fan speed and cooling
depend on the card and environment; check fan startup and temperatures on your
own system.

## Observed load run

In this approximately two-minute LACT capture, the blower ramped from about
500 RPM to 2,052 RPM while power draw reached 349.6 W. The recorded peaks were
63°C GPU, 74°C hotspot and 67°C VRAM. LACT reported the software power cap in
the displayed throttling status. This is one short run on one card; it does
not establish startup reliability or sustained performance in every workload.

![LACT history showing fan speed, temperatures, clocks and power under load](docs/images/lact-fan-profile.png)

The scripts back up the card's VBIOS, create the profile with the VBIOS Vix
Editor CLI, and prepare an **in-memory override** with the Linux VBIOS Vix
Loader. Keep the original ROM and normal boot entry for recovery. Do not flash
the edited copy.

## Back up the original

The Zotac card was identified at PCI address `0000:07:00.0`, NVFlash index 0.
Indices can change, so check the adapter listing before selecting the card.
`src/extract.bash` uses NVFlash's read-only `--save` command. NVFlash required
`iomem=relaxed` on this system and requires the NVIDIA modules to be unloaded
for the save. `src/extract-tty3.bash` provides the console workflow; save work
before stopping the graphical session. Preserve the NVFlash ROM separately.

## Create the fan profile

```bash
bash ./src/edit.bash ORIGINAL.rom EDITED.rom
```

Arguments are optional: the defaults are `zotac-3090-blower-nvflash.rom` and
`zotac-3090-blower-nvflash-1000rpm-10pct-45deg.rom`. Choose a new output name
if a previous copy exists. The script calls the editor's `edit` command and
exports `EDITED-loader.bin` using its `ampere-relocated-v1` representation.
It sets the same values for fan channels 1 and 2:

| Field | Value |
| --- | --- |
| Minimum speed | 1,000 RPM |
| Minimum level | 10% |
| Curve point 1 temperature | 45°C |
| Curve point 1 speed | 1,000 RPM |
| Curve point 1 level | 10% |

The temperature is supplied in °C; the editor stores it as 1,440 units of
1/32°C. Other fan curve points and extra curves are left as in the input ROM.

## Load and check

```bash
bash ./src/load.bash ./EDITED-loader.bin
```

The loader builds an NVIDIA open kernel module and a separate GRUB entry for
the 3090. The project used driver 620.73.04; the loader's support depends on
the driver and kernel. The script sets retention to two override generations.
Reboot after successful setup, then inspect the running configuration:

```bash
sudo nvbios system status
journalctl -k -b | rg -i 'vbios.override|vbios_override'
```

Matching module parameters and a staged payload do not by themselves prove
the fan settings took effect. Observe the physical blower and LACT's RPM,
GPU, hotspot and VRAM temperatures. On this card the 1,000 RPM / 10% settings
reported about 500 RPM at idle; lowering point 1 to 45°C produced an earlier
ramp in a short workload. Confirm startup from a cold boot and monitor sustained
workloads. Use the normal boot entry if the fan stalls or cooling is inadequate.

The loader checks hashes of its managed GRUB entries. Do not rename or delete
them directly; retention can remove old generations after a matching boot and
subsequent reconciliation.
