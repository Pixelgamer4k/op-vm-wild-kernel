#!/usr/bin/env bash
set -euo pipefail
COMMON="${1:?common kernel dir}"
PORT_ROOT="$(cd "$(dirname "$0")" && pwd)"

echo "Applying Gunyah AVF port into $COMMON"
mkdir -p "$COMMON/drivers/virt/gunyah"
mkdir -p "$COMMON/include/linux/gunyah"
mkdir -p "$COMMON/include/uapi/linux"
mkdir -p "$COMMON/arch/arm64/include/asm"

cp -a "$PORT_ROOT/drivers/virt/gunyah/." "$COMMON/drivers/virt/gunyah/"
cp -a "$PORT_ROOT/include/linux/gunyah/." "$COMMON/include/linux/gunyah/"
cp "$PORT_ROOT/include/linux/"*.h "$COMMON/include/linux/"
cp "$PORT_ROOT/include/uapi/linux/"*.h "$COMMON/include/uapi/linux/"
cp "$PORT_ROOT/arch/arm64/include/asm/gunyah.h" "$COMMON/arch/arm64/include/asm/"

# Vendor headers needed by legacy qgunyah loader; GKI common lacks them.
# secure_buffer.h provides hyp_assign_* stubs unless CONFIG_QCOM_SECURE_BUFFER=y.
if [[ -d "$PORT_ROOT/include/soc/qcom" ]]; then
  mkdir -p "$COMMON/include/soc/qcom"
  cp -a "$PORT_ROOT/include/soc/qcom/." "$COMMON/include/soc/qcom/"
fi

# Ensure virt/Makefile builds gunyah
if [[ -f "$COMMON/drivers/virt/Makefile" ]]; then
  if ! grep -q 'gunyah' "$COMMON/drivers/virt/Makefile"; then
    echo 'obj-y += gunyah/' >> "$COMMON/drivers/virt/Makefile"
  fi
fi
if [[ -f "$COMMON/drivers/virt/Kconfig" ]]; then
  if ! grep -q 'virt/gunyah/Kconfig' "$COMMON/drivers/virt/Kconfig"; then
    echo 'source "drivers/virt/gunyah/Kconfig"' >> "$COMMON/drivers/virt/Kconfig"
  fi
fi

# Append config to gki_defconfig
DEFCONFIG="$COMMON/arch/arm64/configs/gki_defconfig"
if [[ -f "$DEFCONFIG" ]]; then
  echo "" >> "$DEFCONFIG"
  echo "# --- op-vm Gunyah AVF port ---" >> "$DEFCONFIG"
  # Convert CONFIG_FOO=y lines; gki_defconfig uses KEY=value
  grep '^CONFIG_' "$PORT_ROOT/gunyah_avf.config" >> "$DEFCONFIG" || true
  # Dependencies often needed (VIRT_DRIVERS gates drivers/virt/ entirely)
  for cfg in CONFIG_VIRT_DRIVERS=y CONFIG_MAILBOX=y CONFIG_AUXILIARY_BUS=y CONFIG_QCOM_SCM=y CONFIG_QCOM_MDT_LOADER=y; do
    key=${cfg%%=*}
    sed -i "/^# ${key} is not set$/d; /^${key}=/d" "$DEFCONFIG"
    echo "$cfg" >> "$DEFCONFIG"
  done
fi

# Hard fail if the virt gate is missing — otherwise Gunyah configs are inert.
if [[ -f "$DEFCONFIG" ]] && ! grep -q '^CONFIG_VIRT_DRIVERS=y$' "$DEFCONFIG"; then
  echo "ERROR: CONFIG_VIRT_DRIVERS=y missing from $DEFCONFIG after Gunyah apply" >&2
  exit 1
fi

echo "Gunyah port applied."
