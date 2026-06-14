#!/bin/bash
set -e

PRINTER_NAME="Canon_LBP2900"

echo "=============================="
echo " Canon LBP2900 UNINSTALL "
echo " Full cleanup + verify "
echo "=============================="

CLEAN=true

# 1. Remove printers
echo "[1/6] Removing printers..."
sudo lpadmin -x $PRINTER_NAME 2>/dev/null || true
sudo lpadmin -x LBP2900 2>/dev/null || true

# 2. Clean jobs
echo "[2/6] Cleaning print jobs..."
cancel -a 2>/dev/null || true

# 3. Remove CAPT filter
echo "[3/6] Removing CAPT filter..."
sudo rm -f /usr/lib/cups/filter/rastertocapt
sudo rm -f /usr/local/bin/rastertocapt

if [ -f /usr/lib/cups/filter/rastertocapt ] || [ -f /usr/local/bin/rastertocapt ]; then
  echo "❌ rastertocapt still exists"
  CLEAN=false
else
  echo "✔ rastertocapt removed"
fi

# 4. Remove PPD
echo "[4/6] Removing PPD..."
sudo rm -f /usr/share/cups/model/Canon-LBP-2900.ppd

if ls /usr/share/cups/model/Canon-LBP-2900.ppd 2>/dev/null; then
  echo "❌ PPD still exists"
  CLEAN=false
else
  echo "✔ PPD removed"
fi

# 5. Remove source code
echo "[5/6] Removing source folder..."
rm -rf ~/Canon-LBP2900B

if [ -d ~/Canon-LBP2900B ]; then
  echo "❌ Source folder still exists"
  CLEAN=false
else
  echo "✔ Source removed"
fi

# 6. Restart CUPS
echo "[6/6] Restarting CUPS..."
sudo systemctl restart cups

echo ""
echo "=============================="
echo " FINAL CHECK "
echo "=============================="

lpstat -p -d

echo ""

if lpstat -p 2>/dev/null | grep -qi "$PRINTER_NAME"; then
  echo "❌ Printer still exists"
  CLEAN=false
else
  echo "✔ No Canon printer found"
fi

echo ""
echo "=============================="

if [ "$CLEAN" = true ]; then
  echo "✅ SYSTEM IS CLEAN (100%)"
  echo "👉 Ready for fresh install"
else
  echo "⚠️ NOT FULLY CLEAN"
  echo "👉 Re-run uninstall or check manually"
fi

echo "=============================="
