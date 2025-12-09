#!/bin/bash

# --- Kode Gaya ANSI ---
COMMENT='\e[38;5;103m'
RED='\e[1;31m'
GREEN='\e[1;32m'
YELLOW='\e[1;33m'
BLUE='\e[1;34m'
ORANGE='\e[38;5;208m'
BOLD='\e[1m'
NC='\e[0m' 

# --- Fungsi UI (Label Berwarna, Isi Bold Default) ---
print_comment() {
	echo ""
	echo -e "${COMMENT}${BOLD}# Letak posisi script harus berada di luar project.${NC}"
	echo -e "${COMMENT}${BOLD}# .                : position work directory${NC}"
	echo -e "${COMMENT}${BOLD}# ├── script.sh    : posisi script ini${NC}"
	echo -e "${COMMENT}${BOLD}# ├── project_1    : target project${NC}"
	echo -e "${COMMENT}${BOLD}# ├── project_2    : target project${NC}"
	echo -e "${COMMENT}${BOLD}# └── project_3    : target project${NC}"
	echo ""
}
print_header() {
	echo -e "\n${YELLOW}${BOLD}================= $1 =================${NC}"
}

print_success() {
	echo -e "\n${GREEN}${BOLD}🟩 SUCCESS:${NC} ${BOLD}$1${NC}"
}

print_error() {
	echo -e "\n${RED}${BOLD}🟥 ERROR:${NC} ${BOLD}$1${NC}"
}

print_info() {
	echo -e "${BLUE}${BOLD}🟪 INFO:${NC} ${BOLD}$1${NC}"
}
print_prompt() {
	echo -ne "${ORANGE}${BOLD}🟧 PROMPT:${NC} ${BOLD}$1${NC}"
}

# --- Persiapan Lingkungan ---
ORIGINAL_DIR=$(pwd)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

print_header "GITHUB AUTOMATION"
print_comment

# PENGECEKAN INTERNET
if ! ping -c 1 -W 2 8.8.8.8 &> /dev/null; then
	print_error "Koneksi internet tidak terhubung."
	print_info "Harap sambungkan perangkat ke internet untuk sinkronisasi GitHub."
	exit 1
fi

# PENGECEKAN INSTALASI (gh terpasang?)
if ! command -v gh &> /dev/null; then
	print_error "Membutuhkan paket GitHub CLI (gh)."
	print_info "Silakan install melalui https://cli.github.com/ atau paket manager system."
	echo ""
	print_info "Debian : sudo apt install gh"
	print_info "Fedora : sudo yum install gh"
	print_info "Arch   : sudo pacman -S github-cli"
	print_info "Termux : pkg install gh\n"
	print_prompt "Command paket manager: "
	read PKG

	print_header "Installing paket..."
	if ! [[ $($PKG) ]]; then
		print_error "Install paket github CLI (gh) gagal!"
		exit 1
	else
		print_success "github CLI (gh) berhasil di install."
	fi
fi

# PENGECEKAN LOGIN (Sesi aktif?)
if ! gh auth status &> /dev/null; then
	print_info "Sesi gh auth login atau sudah kadaluwarsa."
	print_prompt "Setup gh auth login login..."
	gh auth login
fi

# Memindai daftar project
print_info "Memindai daftar project yang tersedia..."
PROJECT_LIST=$(ls -d */ 2>/dev/null | cut -f1 -d'/' || echo "")

# Validasi: Jika variabel kosong (tidak ada folder)
if [[ -z "$PROJECT_LIST" ]]; then
	print_error "Tidak ada folder project ditemukan."
	print_info "Pastikan skrip ini berada di luar folder project Anda."
	exit 1
fi

# Jika ada folder, tampilkan daftarnya
echo -e "${GREEN}${BOLD}$PROJECT_LIST${NC}"
echo ""

print_prompt "Masukkan nama folder project: "
read PROJECT_NAME

PROJECT_PATH="${SCRIPT_DIR}/${PROJECT_NAME}"
if [[ -z "$PROJECT_NAME" || ! -d "$PROJECT_PATH" ]]; then
	print_error "Project '$PROJECT_NAME' tidak ditemukan."; exit 1
fi

cd "$PROJECT_PATH"

HAS_REMOTE=$(git remote get-url origin 2>/dev/null || echo "none")

if [[ "$HAS_REMOTE" == "none" ]]; then
	# BLOK CREATE REPO GITHUB
	print_header "SETUP REPO BARU"
	[[ ! -d ".git" ]] && git init 2>/dev/null && git branch -M main

	print_prompt " Pesan commit awal: "
	read COMMIT
	git add -A && git commit -m "${COMMIT:-chore: initial commit}" --allow-empty

	echo -e "\t${BOLD}[1] Public\n\t[2] Private${NC}"
	print_prompt "Visibility repo (default 2): "
	read CHOICE
	if [[ "$CHOICE" == "1" ]]; then
		VISIBILITY="--public"
	else
		VISIBILITY="--private"
	fi

	print_info "Membuat repositori github untuk $PROJECT_NAME..."
	if gh repo create "$PROJECT_NAME" $VISIBILITY --source=. --remote=origin --push; then
		print_success "Repositori berhasil dibuat!"
		gh browse
	fi
else
	# BLOK PUSH
	print_header "PUSH PROJECT"
	print_info "Target: $HAS_REMOTE"
	echo ""

	print_prompt "Masukkan pesan commit: "
	read COMMIT

	git add -A
	git branch -M "main"
	if git commit -m "${COMMIT:-chore: production update $(date +'%Y-%m-%d')}"; then
		echo ""
		print_info "Mengirim data ke GitHub..." 
		if git push origin "$(git branch --show-current)"; then
			print_success "Project berhasil dipush."
			gh browse
		fi
	else
		print_info "Tidak ada perubahan yang ditemukan."
	fi
fi

echo ""
cd "$ORIGINAL_DIR"

