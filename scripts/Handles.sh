#!/bin/bash

PKG_PATH="$GITHUB_WORKSPACE/openwrt/package/"

#修改访问ip
LAN_ADDR="192.168.10.1"
CFG_PATH="$PKG_PATH/base-files/files/bin/config_generate"
if [ -f $CFG_PATH ]; then
    echo " "
	
    sed -i 's/192\.168\.[0-9]*\.[0-9]*/'$LAN_ADDR'/g' $CFG_PATH

    cd $PKG_PATH && echo "lan ip has been updated!"
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

#移除Shadowsocks组件
PW_FILE=$(find ./ -maxdepth 3 -type f -wholename "*/luci-app-passwall/Makefile")
if [ -f "$PW_FILE" ]; then
	sed -i '/config PACKAGE_$(PKG_NAME)_INCLUDE_Shadowsocks_Libev/,/x86_64/d' $PW_FILE
	sed -i '/config PACKAGE_$(PKG_NAME)_INCLUDE_ShadowsocksR/,/default n/d' $PW_FILE
	sed -i '/Shadowsocks_NONE/d; /Shadowsocks_Libev/d; /ShadowsocksR/d' $PW_FILE

	cd $PKG_PATH && echo "passwall has been fixed!"
fi

SP_FILE=$(find ./ -maxdepth 3 -type f -wholename "*/luci-app-ssr-plus/Makefile")
if [ -f "$SP_FILE" ]; then
	sed -i '/default PACKAGE_$(PKG_NAME)_INCLUDE_Shadowsocks_Libev/,/libev/d' $SP_FILE
	sed -i '/config PACKAGE_$(PKG_NAME)_INCLUDE_ShadowsocksR/,/x86_64/d' $SP_FILE
	sed -i '/Shadowsocks_NONE/d; /Shadowsocks_Libev/d; /ShadowsocksR/d' $SP_FILE

	cd $PKG_PATH && echo "ssr-plus has been fixed!"
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
DM_FILE="./luci-app-diskman/applications/luci-app-diskman/Makefile"
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
change_opkg_distfeeds() {
    local lean_def_dir="$GITHUB_WORKSPACE/openwrt/package/lean/default-settings"
    local zzz_default_settings="$lean_def_dir/files/zzz-default-settings"

    # 检查是否存在 lean_def_dir 和 zzz_default_settings
    if [ -d "$lean_def_dir" ] && [ -f "$zzz_default_settings" ]; then

        # 删除指定行
        sed -i "/sed -i '\/openwrt_luci\/ { s\/snapshots\/releases\\\\\/18.06.9\/g; }' \/etc\/opkg\/distfeeds.conf/d" "$zzz_default_settings"
        # 替换指定行
        sed -i "s#sed -i 's#downloads.openwrt.org#mirrors.tencent.com/lede#g' /etc/opkg/distfeeds.conf#sed -i 's#downloads.openwrt.org#downloads.immortalwrt.org#g' /etc/opkg/distfeeds.conf#" "$zzz_default_settings"
    fi
}

# 移除 uhttpd 依赖
# 当启用luci-app-quickfile插件时，表示启动nginx，所以移除luci对uhttp(luci-light)的依赖
remove_uhttpd_dependency() {
    local config_path="$GITHUB_WORKSPACE/openwrt/.config"
    local luci_makefile_path="$GITHUB_WORKSPACE/openwrt/feeds/luci/collections/luci/Makefile"

    if grep -q "CONFIG_PACKAGE_luci-app-quickfile=y" "$config_path"; then
        if [ -f "$luci_makefile_path" ]; then
            sed -i '/luci-light/d' "$luci_makefile_path"
            echo "Removed uhttpd (luci-light) dependency as luci-app-quickfile (nginx) is enabled."
        fi
    fi
}

#修改CPU 性能优化调节名称显示
change_cpufreq_config() {
    local path="$GITHUB_WORKSPACE/openwrt/feeds/luci/applications/luci-app-cpufreq"
    local po_file="$path/po/zh_Hans/cpufreq.po"

    if [ -d "$path" ] && [ -f "$po_file" ]; then
        sed -i 's/msgstr "CPU 性能优化调节"/msgstr "性能调节"/g' "$po_file"
        echo "Modification completed for $po_file"
    else
        echo "Error: Directory or PO file not found at $path"
        return 1
    fi
}

#修改Argon 主题设置名称显示
change_argon_config() {
    local path="./package/luci-app-argon-config"
    local po_file="$path/po/zh_Hans/argon-config.po"

    if [ -d "$path" ] && [ -f "$po_file" ]; then
        sed -i 's/msgstr "Argon 主题设置"/msgstr "主题设置"/g' "$po_file"
        echo "Modification completed for $po_file"
    else
        echo "Error: Directory or PO file not found at $path"
        return 1
    fi
}

#添加quickfile文件管理
add_quickfile() {
    local repo_url="https://github.com/sbwml/luci-app-quickfile.git"
    local target_dir="$GITHUB_WORKSPACE/openwrt/package/emortal/quickfile"
    if [ -d "$target_dir" ]; then
        rm -rf "$target_dir"
    fi
    git clone --depth 1 "$repo_url" "$target_dir"

    local makefile_path="$target_dir/quickfile/Makefile"
    if [ -f "$makefile_path" ]; then
        sed -i '/\t\$(INSTALL_BIN) \$(PKG_BUILD_DIR)\/quickfile-\$(ARCH_PACKAGES)/c\
\tif [ "\$(ARCH_PACKAGES)" = "x86_64" ]; then \\\
\t\t\$(INSTALL_BIN) \$(PKG_BUILD_DIR)\/quickfile-x86_64 \$(1)\/usr\/bin\/quickfile; \\\
\telse \\\
\t\t\$(INSTALL_BIN) \$(PKG_BUILD_DIR)\/quickfile-aarch64_generic \$(1)\/usr\/bin\/quickfile; \\\
\tfi' "$makefile_path"
    fi
}

#修改argon背景图片
change_argon_background() {
    local theme_path="$GITHUB_WORKSPACE/openwrt/feeds/luci/themes/luci-theme-argon/htdocs/luci-static/argon/background"
    local source_path="$GITHUB_WORKSPACE/images"
    local source_file="$source_path/bg1.jpg"
    local target_file="$theme_path/bg1.jpg"

    if [ -f "$source_file" ]; then
        cp -f "$source_file" "$target_file"
        echo "背景图片更新成功：$target_file"
    else
        echo "错误：未找到源图片文件：$source_file"
        return 1
    fi
}

change_opkg_distfeeds
remove_uhttpd_dependency
change_cpufreq_config
change_argon_config
change_argon_background
add_quickfile
