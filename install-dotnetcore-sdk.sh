#!/bin/bash -e
###############################################################################
#  File:  install-dotnetcore-sdk.sh
#  Desc:  Install .NET Core SDK
###############################################################################

# Source the helpers for use with the script
source $HELPER_SCRIPTS/etc-environment.sh
source $HELPER_SCRIPTS/install.sh
source $HELPER_SCRIPTS/os.sh

# Install dependencies - https://learn.microsoft.com/en-us/dotnet/core/install/linux-ubuntu-decision#dependencies

latest_dotnet_packages=$(get_toolset_value '.dotnet.aptPackages[]')
dotnet_versions=$(get_toolset_value '.dotnet.versions[]')
dotnet_tools=$(get_toolset_value '.dotnet.tools[].name')

apt-get update

if is_ubuntu24; then
    dotnet_deps=(
        ca-certificates
        libc6
        libgcc-s1
        libgssapi-krb5-2
        libicu74
        liblttng-ust1
        libssl3
        libstdc++6
        zlib1g
    )
elif is_ubuntu22; then
    dotnet_deps=(
        ca-certificates
        libc6
        libgcc-s1
        libgssapi-krb5-2
        libicu70
        liblttng-ust1
        libssl3
        libstdc++6
        zlib1g
    )
fi

for dep in "${dotnet_deps[@]}"; do
    echo "Installing .NET dependency: $dep"
    apt-get install -y "$dep"
done

# Use manual method of installing dotnet so we can install multiple versions. https://learn.microsoft.com/en-us/dotnet/core/install/linux-scripted-manual#scripted-install
apt-get install -y wget
wget https://dot.net/v1/dotnet-install.sh -O dotnet-install.sh
chmod +x ./dotnet-install.sh

# Set installDir based on Ubuntu version
if is_ubuntu24; then
    installDir="/usr/lib/dotnet"
    ./dotnet-install.sh --channel 8.0 --version latest --install-dir "$installDir"
else
    installDir="/usr/share/dotnet"
    ./dotnet-install.sh --channel 9.0 --version latest --install-dir "$installDir"
    ./dotnet-install.sh --channel 8.0 --version latest --install-dir "$installDir"
fi

# Export variables to PATH for current session

export DOTNET_ROOT="$installDir"
export PATH="$installDir:$HOME/.dotnet/tools:$PATH"

# Set DOTNET_ROOT and add to PATH using etc environment helpers from MS for normal usage

set_etc_environment_variable DOTNET_ROOT "$installDir"
prepend_etc_environment_path "$installDir"

# Symlink dotnet to /usr/local/bin for easier access
ln -s "$installDir/dotnet" /usr/local/bin/dotnet

# Set DOTNET_ROOT via /etc/profile.d for all users
if is_ubuntu24; then
    profile_dotnet_root="/usr/lib/dotnet"
else
    profile_dotnet_root="/usr/share/dotnet"
fi
cat <<EOF > /etc/profile.d/dotnet.sh
export DOTNET_ROOT=${profile_dotnet_root}
export PATH=\${DOTNET_ROOT}:$HOME/.dotnet/tools:\$PATH
EOF
chmod +x /etc/profile.d/dotnet.sh

# List SDKs to verify installation
echo "Listing installed .NET SDKs:"

dotnet --list-sdks

# NuGetFallbackFolder at /usr/share/dotnet/sdk/NuGetFallbackFolder is warmed up by smoke test
# Additional FTE will just copy to ~/.dotnet/NuGet which provides no benefit on a fungible machine
set_etc_environment_variable DOTNET_SKIP_FIRST_TIME_EXPERIENCE 1
set_etc_environment_variable DOTNET_NOLOGO 1
set_etc_environment_variable DOTNET_MULTILEVEL_LOOKUP 0
prepend_etc_environment_path "$HOME/.dotnet/tools"

# Install .Net tools
for dotnet_tool in ${dotnet_tools[@]}; do
    echo "Installing dotnet tool $dotnet_tool"
    dotnet tool install $dotnet_tool --tool-path '/etc/skel/.dotnet/tools'
done

invoke_tests "DotnetSDK"
