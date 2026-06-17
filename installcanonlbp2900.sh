#!/bin/bash
set -e

PRINTER_NAME="Canon_LBP2900"
AUTO_PRINT=true

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=========================================="
echo " Canon LBP2900 FULL INSTALLER"
echo " Ubuntu 22.04 / 24.04 / 26.04"
echo "=========================================="

#--------------------------------------------------
# 1. Dependencies
#--------------------------------------------------

echo "[1/10] Installing dependencies..."

sudo apt update

sudo apt install -y \
cups \
cups-client \
cups-bsd \
libcups2-dev \
libcupsimage2-dev \
build-essential \
git \
autoconf \
automake \
libtool \
pkg-config \
make

#--------------------------------------------------
# 2. Start CUPS
#--------------------------------------------------

echo "[2/10] Starting CUPS..."

sudo systemctl enable cups
sudo systemctl restart cups

#--------------------------------------------------
# 3. Source
#--------------------------------------------------

echo "[3/10] Checking source..."

cd "$SCRIPT_DIR"

if [ ! -d Canon-LBP2900B ]; then

    echo "Source not found."
    echo "Downloading..."

    git clone https://github.com/gauravyad69/Canon-LBP2900B.git

else

    echo "Source already exists."
    echo "Using existing source."

fi

cd Canon-LBP2900B

echo "Source path:"
pwd

#--------------------------------------------------
# 4. Build + Install Driver
#--------------------------------------------------

if [ -f /usr/lib/cups/filter/rastertocapt ]; then

    echo "[4/10] Driver already installed."
    echo "Skipping build."

else

    echo "[4/10] Building driver..."

    if command -v libtoolize >/dev/null 2>&1; then
        libtoolize --force --copy || true
    fi

    aclocal || true
    autoconf || true
    autoheader || true
    automake --add-missing --foreign || true

    if [ -f configure ]; then
        chmod +x configure
        ./configure || true
    fi

    make clean 2>/dev/null || true
    make

    if ! find . -name rastertocapt | grep -q rastertocapt; then
        echo ""
        echo "ERROR: Build failed."
        echo "rastertocapt was not generated."
        exit 1
    fi

    echo "[5/10] Installing driver..."

    sudo make install

fi

#--------------------------------------------------
# 5. Install Filter
#--------------------------------------------------

echo "[5/10] Installing CUPS filter..."

sudo mkdir -p /usr/lib/cups/filter

FILTER=""

[ -f /usr/local/bin/rastertocapt ] && FILTER=/usr/local/bin/rastertocapt
[ -f ./rastertocapt ] && FILTER=./rastertocapt
[ -f src/rastertocapt ] && FILTER=src/rastertocapt

if [ -z "$FILTER" ]; then
    FILTER=$(find . -name rastertocapt | head -n 1)
fi

if [ -z "$FILTER" ]; then
    echo "ERROR: rastertocapt not found"
    exit 1
fi

echo "Using filter:"
echo "$FILTER"

sudo cp "$FILTER" /usr/lib/cups/filter/rastertocapt
sudo chmod 755 /usr/lib/cups/filter/rastertocapt

#--------------------------------------------------
# 6. Install PPD
#--------------------------------------------------

echo "[6/10] Installing PPD..."

PPD_FILE=""

[ -f Canon-LBP-2900.ppd ] && PPD_FILE=Canon-LBP-2900.ppd
[ -f "$SCRIPT_DIR/Canon-LBP-2900.ppd" ] && PPD_FILE="$SCRIPT_DIR/Canon-LBP-2900.ppd"

if [ -z "$PPD_FILE" ]; then
    PPD_FILE=$(find . -iname "*.ppd" | head -n 1)
fi

if [ -z "$PPD_FILE" ]; then
    echo "ERROR: No PPD file found"
    exit 1
fi

echo "Using PPD:"
echo "$PPD_FILE"

sudo cp "$PPD_FILE" /usr/share/cups/model/Canon-LBP-2900.ppd

#--------------------------------------------------
# 7. Detect Printer
#--------------------------------------------------

echo "[7/10] Detecting printer..."

DEVICE=$(lpinfo -v | awk '/usb/ {print $2; exit}')

if [ -z "$DEVICE" ]; then

    echo ""
    echo "ERROR: USB printer not detected."
    echo ""
    echo "Check:"
    echo "  - Printer is powered ON"
    echo "  - USB cable connected"
    echo "  - Run: lpinfo -v"
    exit 1

fi

echo "Found device:"
echo "$DEVICE"

#--------------------------------------------------
# 8. Create Printer
#--------------------------------------------------

echo "[8/10] Creating printer..."

sudo lpadmin -x "$PRINTER_NAME" 2>/dev/null || true

sudo lpadmin \
-p "$PRINTER_NAME" \
-E \
-v "$DEVICE" \
-P /usr/share/cups/model/Canon-LBP-2900.ppd

sudo lpadmin -d "$PRINTER_NAME"

sudo lpadmin \
-p "$PRINTER_NAME" \
-o printer-error-policy=abort-job

#--------------------------------------------------
# 9. Restart CUPS
#--------------------------------------------------

echo "[9/10] Restarting CUPS..."

sudo systemctl restart cups

echo "Waiting for CUPS..."

sleep 5

echo ""
echo "Printer status:"
lpstat -p "$PRINTER_NAME" || true

#--------------------------------------------------
# 10. Test Print
#--------------------------------------------------

echo ""
echo "=========================================="
echo " INSTALL COMPLETE"
echo "=========================================="
echo "Printer : $PRINTER_NAME"
echo "Device  : $DEVICE"
echo "Source  : $SCRIPT_DIR/Canon-LBP2900B"
echo "=========================================="

if [ "$AUTO_PRINT" = true ]; then

    echo ""
    echo "[10/10] TEST PRINT"

    if [ -f /usr/share/cups/data/testprint ]; then

        echo "Sending test page..."

        lp -d "$PRINTER_NAME" /usr/share/cups/data/testprint

        echo "Test page sent."

    else

        echo "CUPS test page not found."

    fi

else

    echo ""
    echo "Manual test:"
    echo "lp -d $PRINTER_NAME /usr/share/cups/data/testprint"

fi

echo ""
echo "Finished successfully."
