#!/bin/bash
PKG_PATH="$GITHUB_WORKSPACE/openwrt/package/"

#修改默认主题
sed -i "s/luci-theme-bootstrap/luci-theme-argon/g" $(find ./feeds/luci/collections/ -type f -name "Makefile")

#修改访问ip和主机名称
LAN_ADDR="192.168.10.1"
HOST_NAME="iStoreOS"
CFG_PATH="$PKG_PATH/base-files/files/bin/config_generate"
CFG2_PATH="$PKG_PATH/base-files/luci2/bin/config_generate"
if [ -f $CFG_PATH ] && [ -f $CFG2_PATH ]; then
    echo " "
	
    sed -i 's/192\.168\.[0-9]*\.[0-9]*/'$LAN_ADDR'/g' $CFG_PATH $CFG2_PATH
 	sed -i 's/LEDE/'$HOST_NAME'/g' $CFG_PATH $CFG2_PATH
	#修改immortalwrt.lan关联IP
	sed -i "s/192\.168\.[0-9]*\.[0-9]*/$LAN_ADDR/g" $(find ./feeds/luci/modules/luci-mod-system/ -type f -name "flash.js")
    cd $PKG_PATH && echo "访问ip修改完成!"
fi


# 修改wifi参数
WRT_SSID_2G="iStoreOS-2.4G"
WRT_SSID_5G="iStoreOS-5G"
WRT_WORD="ai.ni520"
WIFI_UC="$PKG_PATH/kernel/mac80211/files/lib/wifi/mac80211.sh"

if [ -f "$WIFI_UC" ]; then
    echo "--- 正在修改 mac80211.sh 中的 Wi-Fi 参数 ---"

    # 使用sed命令将默认的ssid设置替换为case语句，以区分2.4G和5G
    sed -i "/set wireless.default_radio\${devidx}.ssid=LEDE/c \\
            case \"\${mode_band}\" in\\
            2g) set wireless.default_radio\${devidx}.ssid='$WRT_SSID_2G' ;;\
            5g) set wireless.default_radio\${devidx}.ssid='$WRT_SSID_5G' ;;\
            esac" "$WIFI_UC"

    # 修改WIFI加密：将encryption=none替换为psk2+ccmp
    sed -i "s/encryption=none/encryption='psk2+ccmp'/g" "$WIFI_UC"

    # 修改WIFI地区：将country=US替换为CN
    sed -i "s/country=US/country='CN'/g" "$WIFI_UC"

    # 在 uci batch 中添加 mu_beamformer 和 txpower
    # 在 'set wireless.radio${devidx}.country='CN'' 行之后插入
    sed -i "/country='CN'/a \
            set wireless.radio\${devidx}.mu_beamformer='1'\n\
            set wireless.radio\${devidx}.txpower='20'" "$WIFI_UC"

    # 在 uci batch 中添加 key
    # 在 'set wireless.default_radio${devidx}.encryption='psk2+ccmp'' 行之后插入
    sed -i "/encryption='psk2+ccmp'/a \
            set wireless.default_radio\${devidx}.key='$WRT_WORD'" "$WIFI_UC"

    echo "Wi-Fi 参数修改和添加完成！"
else
    echo "Error: mac80211.sh 文件未找到，路径为：$WIFI_UC"
    exit 1
fi

#配置文件修改
echo "CONFIG_PACKAGE_luci=y" >> ./.config
echo "CONFIG_LUCI_LANG_zh_Hans=y" >> ./.config

# 调整内核参数 /etc/sysctl.conf
mkdir -p files/etc
echo "net.netfilter.nf_conntrack_udp_timeout=10" >> files/etc/sysctl.conf
echo "net.netfilter.nf_conntrack_udp_timeout_stream=60" >> files/etc/sysctl.conf


#高通平台调整
if [[ $TARGET == *"ipq"* ]]; then
	#取消nss相关feed
	echo "CONFIG_FEED_nss_packages=n" >> ./.config
	echo "CONFIG_FEED_sqm_scripts_nss=n" >> ./.config
	#设置NSS版本
	echo "CONFIG_NSS_FIRMWARE_VERSION_11_4=n" >> ./.config
	echo "CONFIG_NSS_FIRMWARE_VERSION_12_2=y" >> ./.config

	echo "nss version has fixed!"	
fi

# 添加内核配置以支持 dae
cat_kernel_config() {
conde_file="$GITHUB_WORKSPACE/openwrt/target/linux/qualcommax/ipq60xx/config-default"
  if [ -f "$conde_file" ]; then
    cat >> "$conde_file" <<EOF
CONFIG_BPF=y
CONFIG_BPF_SYSCALL=y
CONFIG_BPF_JIT=y
CONFIG_CGROUPS=y
CONFIG_KPROBES=y
CONFIG_NET_INGRESS=y
CONFIG_NET_EGRESS=y
CONFIG_NET_SCH_INGRESS=m
CONFIG_NET_CLS_BPF=m
CONFIG_NET_CLS_ACT=y
CONFIG_BPF_STREAM_PARSER=y
CONFIG_DEBUG_INFO=y
# CONFIG_DEBUG_INFO_REDUCED is not set
CONFIG_DEBUG_INFO_BTF=y
CONFIG_KPROBE_EVENTS=y
CONFIG_BPF_EVENTS=y
EOF
    echo "cat_kernel_config to "$conde_file" done"
  fi
}

cat_ebpf_config() {
config_file="$GITHUB_WORKSPACE/openwrt/.config"
  if [ -f "$config_file" ]; then
    cat >> $config_file <<EOF
CONFIG_DEVEL=y
CONFIG_KERNEL_DEBUG_INFO=y
CONFIG_KERNEL_DEBUG_INFO_REDUCED=n
CONFIG_KERNEL_DEBUG_INFO_BTF=y
CONFIG_KERNEL_CGROUPS=y
CONFIG_KERNEL_CGROUP_BPF=y
CONFIG_KERNEL_BPF_EVENTS=y
CONFIG_BPF_TOOLCHAIN_HOST=y
CONFIG_KERNEL_XDP_SOCKETS=y
CONFIG_PACKAGE_kmod-xdp-sockets-diag=y
EOF

    echo "cat_ebpf_config to  $config_file done"
  fi
}

# 修改内核大小
set_kernel_size() {
  image_file="$GITHUB_WORKSPACE/openwrt/target/linux/qualcommax/image/ipq60xx.mk"
  if [ -f "$image_file" ]; then
    sed -i "/^define Device\/jdcloud_re-ss-01/,/^endef/ { /KERNEL_SIZE := 6144k/s//KERNEL_SIZE := 12288k/ }" "$image_file"
    sed -i "/^define Device\/jdcloud_re-cs-02/,/^endef/ { /KERNEL_SIZE := 6144k/s//KERNEL_SIZE := 12288k/ }" $image_file
    sed -i "/^define Device\/jdcloud_re-cs-07/,/^endef/ { /KERNEL_SIZE := 6144k/s//KERNEL_SIZE := 12288k/ }" $image_file
    sed -i "/^define Device\/redmi_ax5-jdcloud/,/^endef/ { /KERNEL_SIZE := 6144k/s//KERNEL_SIZE := 12288k/ }" $image_file
    sed -i "/^define Device\/linksys_mr/,/^endef/ { /KERNEL_SIZE := 8192k/s//KERNEL_SIZE := 12288k/ }" $image_file
    echo "Kernel size updated in $image_file"
  else
    echo "Image file $image_file not found, skipping kernel size update"
  fi
}
#cat_ebpf_config
#cat_kernel_config
#set_kernel_size
