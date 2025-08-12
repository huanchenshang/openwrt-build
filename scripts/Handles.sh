#!/bin/bash

PKG_PATH="$GITHUB_WORKSPACE/openwrt/package/"

#修改访问ip和主机名称
LAN_ADDR="192.168.10.1"
HOST_NAME="iStoreOS"
CFG_PATH="$PKG_PATH/base-files/files/bin/config_generate"
CFG2_PATH="$PKG_PATH/base-files/luci2/bin/config_generate"
if [ -f $CFG_PATH ] && [ -f $CFG2_PATH ]; then
    echo " "
	
    sed -i 's/192\.168\.[0-9]*\.[0-9]*/'$LAN_ADDR'/g' $CFG_PATH $CFG2_PATH
 	sed -i 's/LEDE/'$HOST_NAME'/g' $CFG_PATH $CFG2_PATH

    cd $PKG_PATH && echo "lan ip has been updated!"
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

#预置HomeProxy数据
if [ -d *"homeproxy"* ]; then
	HP_RULE="surge"
	HP_PATH="homeproxy/root/etc/homeproxy"

	rm -rf ./$HP_PATH/resources/*

	git clone -q --depth=1 --single-branch --branch "release" "https://github.com/Loyalsoldier/surge-rules.git" ./$HP_RULE/
	cd ./$HP_RULE/ && RES_VER=$(git log -1 --pretty=format:'%s' | grep -o "[0-9]*")

	echo $RES_VER | tee china_ip4.ver china_ip6.ver china_list.ver gfw_list.ver
	awk -F, '/^IP-CIDR,/{print $2 > "china_ip4.txt"} /^IP-CIDR6,/{print $2 > "china_ip6.txt"}' cncidr.txt
	sed 's/^\.//g' direct.txt > china_list.txt ; sed 's/^\.//g' gfw.txt > gfw_list.txt
	mv -f ./{china_*,gfw_list}.{ver,txt} ../$HP_PATH/resources/

	cd .. && rm -rf ./$HP_RULE/

	cd $PKG_PATH && echo "homeproxy date has been updated!"
fi

#修复TailScale配置文件冲突
TS_FILE=$(find ../feeds/packages/ -maxdepth 3 -type f -wholename "*/tailscale/Makefile")
if [ -f "$TS_FILE" ]; then
    echo " "
	
	sed -i '/\/files/d' $TS_FILE

	cd $PKG_PATH && echo "tailscale has been fixed!"
fi

#修复Rust编译失败
RUST_FILE=$(find ../feeds/packages/ -maxdepth 3 -type f -wholename "*/rust/Makefile")
if [ -f "$RUST_FILE" ]; then
	echo " "

	sed -i 's/ci-llvm=true/ci-llvm=false/g' $RUST_FILE

	cd $PKG_PATH && echo "rust has been fixed!"
fi

#修复DiskMan编译失败
DM_FILE="../package/luci-app-diskman/applications/luci-app-diskman/Makefile"
if [ -f "$DM_FILE" ]; then
	echo " "
 
	sed -i 's/fs-ntfs/fs-ntfs3/g' $DM_FILE
	sed -i '/ntfs-3g-utils /d' $DM_FILE

	cd $PKG_PATH && echo "diskman has been fixed!"
fi

# 自定义v2ray-geodata下载
V2RAY_FILE="../feeds/packages/net/v2ray-geodata"
MF_FILE="$GITHUB_WORKSPACE/package/v2ray-geodata/Makefile"
SH_FILE="$GITHUB_WORKSPACE/package/v2ray-geodata/init.sh"
UP_FILE="$GITHUB_WORKSPACE/package/v2ray-geodata/v2ray-geodata-updater"
if [ -d "$V2RAY_FILE" ]; then
	echo " "

	cp -f "$MF_FILE" "$V2RAY_FILE/Makefile"
	cp -f "$SH_FILE" "$V2RAY_FILE/init.sh"
	cp -f "$UP_FILE" "$V2RAY_FILE/v2ray-geodata-updater"

	cd $PKG_PATH && echo "v2ray-geodata has been fixed!"
fi

#设置nginx默认配置和修复quickstart温度显示
wget "https://gist.githubusercontent.com/huanchenshang/df9dc4e13c6b2cd74e05227051dca0a9/raw/nginx.default.config" -O ../feeds/packages/net/nginx-util/files/nginx.config
wget "https://gist.githubusercontent.com/puteulanus/1c180fae6bccd25e57eb6d30b7aa28aa/raw/istore_backend.lua" -O ../package/luci-app-quickstart/luasrc/controller/istore_backend.lua

# 修改软件源为immortalwrt
lean_def_dir="$GITHUB_WORKSPACE/openwrt/package/lean/default-settings"
zzz_default_settings="$lean_def_dir/files/zzz-default-settings"

# 检查是否存在 lean_def_dir 和 zzz_default_settings
if [ -d "$lean_def_dir" ] && [ -f "$zzz_default_settings" ]; then

    # 删除指定行
    sed -i "/sed -i '\/openwrt_luci\/ { s\/snapshots\/releases\\\\\/18.06.9\/g; }' \/etc\/opkg\/distfeeds.conf/d" "$zzz_default_settings"
    sed -i "/sed -i 's#downloads.openwrt.org#mirrors.tencent.com/lede#g' /etc/opkg/distfeeds.conf/d" "$zzz_default_settings"

    # 使用 cat 命令将新的软件源配置追加到文件末尾
    cat << 'NEW_END' >> "$zzz_default_settings"

cat << EOF > /etc/opkg/distfeeds.conf
src/gz openwrt_base https://downloads.immortalwrt.org/releases/24.10-SNAPSHOT/packages/aarch64_cortex-a53/base/
src/gz openwrt_luci https://downloads.immortalwrt.org/releases/24.10-SNAPSHOT/packages/aarch64_cortex-a53/luci/
src/gz openwrt_packages https://downloads.immortalwrt.org/releases/24.10-SNAPSHOT/packages/aarch64_cortex-a53/packages/
src/gz openwrt_routing https://downloads.immortalwrt.org/releases/24.10-SNAPSHOT/packages/aarch64_cortex-a53/routing/
src/gz openwrt_telephony https://downloads.immortalwrt.org/releases/24.10-SNAPSHOT/packages/aarch64_cortex-a53/telephony/
EOF
NEW_END
fi

# 移除 uhttpd 依赖
# 当启用luci-app-quickfile插件时，表示启动nginx，所以移除luci对uhttp(luci-light)的依赖
config_path="$GITHUB_WORKSPACE/openwrt/.config"
luci_makefile_path="$GITHUB_WORKSPACE/openwrt/feeds/luci/collections/luci/Makefile"

if grep -q "CONFIG_PACKAGE_luci-app-quickfile=y" "$config_path"; then
    if [ -f "$luci_makefile_path" ]; then
        sed -i '/luci-light/d' "$luci_makefile_path"
        echo "Removed uhttpd (luci-light) dependency as luci-app-quickfile (nginx) is enabled."
    fi
fi

#修改CPU 性能优化调节名称显示
path="$GITHUB_WORKSPACE/openwrt/feeds/luci/applications/luci-app-cpufreq"
po_file="$path/po/zh_Hans/cpufreq.po"

if [ -d "$path" ] && [ -f "$po_file" ]; then
    sed -i 's/msgstr "CPU 性能优化调节"/msgstr "性能调节"/g' "$po_file"
    echo "Modification completed for $po_file"
else
    echo "Error: Directory or PO file not found at $path"
    return 1
fi

#添加quickfile文件管理
repo_url="https://github.com/sbwml/luci-app-quickfile.git"
target_dir="$GITHUB_WORKSPACE/openwrt/package/lean/quickfile"
if [ -d "$target_dir" ]; then
    rm -rf "$target_dir"
fi
git clone --depth 1 "$repo_url" "$target_dir"

makefile_path="$target_dir/quickfile/Makefile"
if [ -f "$makefile_path" ]; then
    sed -i '/\t\$(INSTALL_BIN) \$(PKG_BUILD_DIR)\/quickfile-\$(ARCH_PACKAGES)/c\
\tif [ "\$(ARCH_PACKAGES)" = "x86_64" ]; then \\\
\t\t\$(INSTALL_BIN) \$(PKG_BUILD_DIR)\/quickfile-x86_64 \$(1)\/usr\/bin\/quickfile; \\\
\telse \\\
\t\t\$(INSTALL_BIN) \$(PKG_BUILD_DIR)\/quickfile-aarch64_generic \$(1)\/usr\/bin\/quickfile; \\\
\tfi' "$makefile_path"
fi

#修改argon背景图片
theme_path="$GITHUB_WORKSPACE/openwrt/feeds/luci/themes/luci-theme-argon/htdocs/luci-static/argon/background"
source_path="$GITHUB_WORKSPACE/images"
source_file="$source_path/bg1.jpg"
target_file="$theme_path/bg1.jpg"

if [ -f "$source_file" ]; then
    cp -f "$source_file" "$target_file"
    echo "背景图片更新成功：$target_file"
else
    echo "错误：未找到源图片文件：$source_file"
    return 1
fi

#修改quickfile菜单位置
quickfile_path="$GITHUB_WORKSPACE/openwrt/package/emortal/quickfile/luci-app-quickfile/root/usr/share/luci/menu.d/luci-app-quickfile.json"

if [ -d "$(dirname "$quickfile_path")" ] && [ -f "$quickfile_path" ]; then
    sed -i 's/system/nas/g' "$quickfile_path"
    echo "quickfile位置更改完成"
else
    echo "quickfile文件或目录不存在，跳过更改。"
	return 1
fi


#turboacc设置名称显示
tb_path="$GITHUB_WORKSPACE/openwrt/feeds/luci/applications/luci-app-turboacc"
po_file="$tb_path/po/zh_Hans/turboacc.po"

if [ -d "$tb_path" ] && [ -f "$po_file" ]; then
    sed -i 's/msgstr "Turbo ACC 网络加速"/msgstr "网络加速"/g' "$po_file"
    echo "turboacc名称更改完成"
else
    echo "turboacc文件或目录不存在，跳过更改"
    return 1
fi

