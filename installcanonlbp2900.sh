#!/bin/bash
set -e

PRINTER_NAME="Canon_LBP2900"
PPD_NAME="Canon-LBP-2900.ppd"
AUTO_PRINT=true   # đổi false nếu không muốn in test tự động

echo "=============================="
echo " Canon LBP2900 FULL INSTALL "
echo " Ubuntu 26.04 compatible "
echo "=============================="

# 1. Dependencies
echo "[1/10] Installing dependencies..."
sudo apt update
sudo apt install -y cups libcups2-dev libcupsimage2-dev \
build-essential git autoconf automake

# 2. Start CUPS
echo "[2/10] Enabling CUPS..."
sudo systemctl enable cups
sudo systemctl restart cups

# 3. Clean old source
echo "[3/10] Cleaning old source..."
cd ~
rm -rf Canon-LBP2900B

# 4. Clone driver
echo "[4/10] Cloning driver..."
git clone https://github.com/gauravyad69/Canon-LBP2900B.git
cd Canon-LBP2900B

# 5. Build
echo "[5/10] Building driver..."
aclocal
autoconf
automake --add-missing
./configure || true
make

# 6. Install driver
echo "[6/10] Installing driver..."
sudo make install

# 7. Fix CUPS filter path (CRITICAL)
echo "[7/10] Fixing CUPS filter..."
sudo mkdir -p /usr/lib/cups/filter
sudo cp /usr/local/bin/rastertocapt /usr/lib/cups/filter/
sudo chmod 755 /usr/lib/cups/filter/rastertocapt

# 8. Install PPD
echo "[8/10] Installing PPD..."
sudo cp Canon-LBP-2900.ppd /usr/share/cups/model/

# 9. Detect printer
echo "[9/10] Detecting USB printer..."
DEVICE=$(lpinfo -v | grep -i canon | grep usb | head -n 1 | awk '{print $2}')

if [ -z "$DEVICE" ]; then
  echo "ERROR: Cannot detect Canon printer!"
  exit 1
fi

echo "Found device: $DEVICE"

# 10. Add printer clean
echo "[10/10] Adding printer..."

sudo lpadmin -x $PRINTER_NAME 2>/dev/null || true

sudo lpadmin -p $PRINTER_NAME -E -v "$DEVICE" -m $PPD_NAME

sudo lpadmin -d $PRINTER_NAME
sudo lpadmin -p $PRINTER_NAME -o printer-error-policy=abort-job

sudo systemctl restart cups

echo ""
echo "=============================="
echo " INSTALL COMPLETE "
echo " Printer: $PRINTER_NAME"
echo "=============================="

lpstat -p -d

# OPTIONAL TEST PRINT
if [ "$AUTO_PRINT" = true ]; then
  echo ""
  echo "[AUTO TEST PRINT] Sending test page..."
  echo "Using printer: $PRINTER_NAME"

  lp -d "$PRINTER_NAME" /usr/share/cups/data/testprint
  RET=$?

  echo "lp exit code: $RET"
else
  echo ""
  echo "Run test manually:"
  echo "lp -d $PRINTER_NAME /usr/share/cups/data/testprint"
fi
