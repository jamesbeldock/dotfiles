#!/usr/bin/env bats

setup() {
    load test_helper
}

# Helper to load config output into a bash array
load_packages() {
    eval "$(python3 "${PROJECT_ROOT}/tools/load_config.py" "$@")"
}

# --- Linux IoT ---

@test "linux iot includes gnu_core_utils packages" {
    load_packages --set iot --platform linux
    assert_array_contains PACKAGES_TO_INSTALL "coreutils"
    assert_array_contains PACKAGES_TO_INSTALL "stow"
    assert_array_contains PACKAGES_TO_INSTALL "bash"
    assert_array_contains PACKAGES_TO_INSTALL "wget"
}

@test "linux iot includes basic_tools packages" {
    load_packages --set iot --platform linux
    assert_array_contains PACKAGES_TO_INSTALL "grep"
    assert_array_contains PACKAGES_TO_INSTALL "vim"
    assert_array_contains PACKAGES_TO_INSTALL "openssh"
}

@test "linux iot includes james_tools packages" {
    load_packages --set iot --platform linux
    assert_array_contains PACKAGES_TO_INSTALL "bat"
    assert_array_contains PACKAGES_TO_INSTALL "neovim"
    assert_array_contains PACKAGES_TO_INSTALL "zsh"
    assert_array_contains PACKAGES_TO_INSTALL "fzf"
    assert_array_contains PACKAGES_TO_INSTALL "tmux"
}

@test "linux iot does NOT include network_security_tools" {
    load_packages --set iot --platform linux
    assert_array_not_contains PACKAGES_TO_INSTALL "nmap"
    assert_array_not_contains PACKAGES_TO_INSTALL "sqlmap"
}

# --- Linux LXC ---

@test "linux lxc includes gnu_core_utils packages" {
    load_packages --set lxc --platform linux
    assert_array_contains PACKAGES_TO_INSTALL "coreutils"
    assert_array_contains PACKAGES_TO_INSTALL "stow"
}

@test "linux lxc includes basic_tools packages" {
    load_packages --set lxc --platform linux
    assert_array_contains PACKAGES_TO_INSTALL "grep"
    assert_array_contains PACKAGES_TO_INSTALL "vim"
}

@test "linux lxc includes lxc_tools packages" {
    load_packages --set lxc --platform linux
    assert_array_contains PACKAGES_TO_INSTALL "git"
    assert_array_contains PACKAGES_TO_INSTALL "neovim"
    assert_array_contains PACKAGES_TO_INSTALL "fastfetch"
    assert_array_contains PACKAGES_TO_INSTALL "tmux"
}

@test "linux lxc does NOT include james_tools-only items" {
    load_packages --set lxc --platform linux
    assert_array_not_contains PACKAGES_TO_INSTALL "broot"
    assert_array_not_contains PACKAGES_TO_INSTALL "yazi"
    assert_array_not_contains PACKAGES_TO_INSTALL "thefuck"
}

# --- Linux Server ---

@test "linux server includes all expected groups" {
    load_packages --set server --platform linux
    # gnu_core_utils
    assert_array_contains PACKAGES_TO_INSTALL "coreutils"
    # basic_tools
    assert_array_contains PACKAGES_TO_INSTALL "grep"
    # james_tools
    assert_array_contains PACKAGES_TO_INSTALL "bat"
    # network_security_tools
    assert_array_contains PACKAGES_TO_INSTALL "nmap"
    # general_utilities
    assert_array_contains PACKAGES_TO_INSTALL "tree"
}

@test "linux server does NOT include nerd_fonts" {
    load_packages --set server --platform linux
    assert_array_not_contains PACKAGES_TO_INSTALL "font-jetbrains-mono-nerd-font"
}

# --- Linux Workstation ---

@test "linux workstation includes everything including nerd_fonts" {
    load_packages --set workstation --platform linux
    assert_array_contains PACKAGES_TO_INSTALL "coreutils"
    assert_array_contains PACKAGES_TO_INSTALL "grep"
    assert_array_contains PACKAGES_TO_INSTALL "bat"
    assert_array_contains PACKAGES_TO_INSTALL "nmap"
    assert_array_contains PACKAGES_TO_INSTALL "tree"
    assert_array_contains PACKAGES_TO_INSTALL "font-jetbrains-mono-nerd-font"
    assert_array_contains PACKAGES_TO_INSTALL "font-fira-code-nerd-font"
}

@test "linux workstation is superset of server" {
    load_packages --set server --platform linux
    local server_packages=("${PACKAGES_TO_INSTALL[@]}")

    load_packages --set workstation --platform linux
    for pkg in "${server_packages[@]}"; do
        assert_array_contains PACKAGES_TO_INSTALL "$pkg"
    done
}

# --- macOS Server ---

@test "macos server formulae include expected groups" {
    load_packages --set server --platform macos --type formulae
    # gnu_core_utils
    assert_array_contains FORMULAE_TO_INSTALL "coreutils"
    # basic_tools
    assert_array_contains FORMULAE_TO_INSTALL "grep"
    # james_tools (includes starship on macOS)
    assert_array_contains FORMULAE_TO_INSTALL "bat"
    assert_array_contains FORMULAE_TO_INSTALL "starship"
    # network_security_tools
    assert_array_contains FORMULAE_TO_INSTALL "nmap"
    # general_utilities
    assert_array_contains FORMULAE_TO_INSTALL "git"
}

@test "macos server casks are empty" {
    load_packages --set server --platform macos --type casks
    assert_array_length CASKS_TO_INSTALL 0
}

# --- macOS Workstation ---

@test "macos workstation formulae match server" {
    load_packages --set server --platform macos --type formulae
    local server_formulae=("${FORMULAE_TO_INSTALL[@]}")

    load_packages --set workstation --platform macos --type formulae
    for pkg in "${server_formulae[@]}"; do
        assert_array_contains FORMULAE_TO_INSTALL "$pkg"
    done
}

@test "macos workstation casks include nerd_fonts and cask_apps" {
    load_packages --set workstation --platform macos --type casks
    assert_array_contains CASKS_TO_INSTALL "font-jetbrains-mono-nerd-font"
    assert_array_contains CASKS_TO_INSTALL "font-fira-code-nerd-font"
    assert_array_contains CASKS_TO_INSTALL "iterm2"
    assert_array_contains CASKS_TO_INSTALL "wezterm"
    assert_array_contains CASKS_TO_INSTALL "docker"
    assert_array_contains CASKS_TO_INSTALL "1password"
}

@test "macos workstation cask count is 14 (2 fonts + 12 apps)" {
    load_packages --set workstation --platform macos --type casks
    assert_array_length CASKS_TO_INSTALL 14
}

# --- Stow packages ---

@test "stow workstation has 11 packages" {
    load_packages --set workstation --type stow
    assert_array_contains PACKAGE "basic"
    assert_array_contains PACKAGE "config resources"
    assert_array_contains PACKAGE "iterm2"
    assert_array_contains PACKAGE "oh-my-zsh"
    assert_array_contains PACKAGE "wezterm"
    assert_array_length PACKAGE 11
}

@test "stow server has 8 packages" {
    load_packages --set server --type stow
    assert_array_contains PACKAGE "basic"
    assert_array_contains PACKAGE "git"
    assert_array_contains PACKAGE "starship"
    assert_array_length PACKAGE 8
}

@test "stow server does NOT contain workstation-only items" {
    load_packages --set server --type stow
    assert_array_not_contains PACKAGE "iterm2"
    assert_array_not_contains PACKAGE "wezterm"
    assert_array_not_contains PACKAGE "oh-my-zsh"
}

@test "stow iot has 6 packages" {
    load_packages --set iot --type stow
    assert_array_contains PACKAGE "basic"
    assert_array_contains PACKAGE "nvim"
    assert_array_contains PACKAGE "tmux"
    assert_array_length PACKAGE 6
}

@test "stow iot does NOT contain server/workstation items" {
    load_packages --set iot --type stow
    assert_array_not_contains PACKAGE "git"
    assert_array_not_contains PACKAGE "starship"
    assert_array_not_contains PACKAGE "iterm2"
}

@test "stow lxc matches iot" {
    load_packages --set iot --type stow
    local iot_packages=("${PACKAGE[@]}")

    load_packages --set lxc --type stow
    local lxc_packages=("${PACKAGE[@]}")

    assert_equal "${#iot_packages[@]}" "${#lxc_packages[@]}"
    for i in "${!iot_packages[@]}"; do
        assert_equal "${iot_packages[$i]}" "${lxc_packages[$i]}"
    done
}
