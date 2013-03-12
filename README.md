# mbtget (modbus class 1 client)

This is a simple perl script for make some modbus transaction from the command line. 

## Setup (for Linux):
1. just copy mbtget to /usr/local/bin/ (it's the script path for user scripts in debian system).
2. set chmod +x /usr/local/bin/mbtget to set execution flag.

## Usage example

### read a word data at address 1000 on modbus server 127.0.0.1

    pi@raspberrypi ~ $ mbtget -a 1000 127.0.0.1
    
    values:
    1 (ad 01000): 52544

### read 10 words data at address 1000 on modbus server plc-1.domaine.net
    
    pi@raspberrypi ~ $ mbtget -n 10 -a 1000 plc-1.domaine.net

    values:
    1 (ad 01000): 52544
    2 (ad 01001): 33619
    3 (ad 01002): 61010
    4 (ad 01003): 11878
    5 (ad 01004): 60142
    6 (ad 01005): 21714
    7 (ad 01006): 14182
    8 (ad 01007): 64342
    9 (ad 01008): 18511
    10 (ad 01009): 59909
 
### write a word value of 333 at address 1000 on modbus server 127.0.0.1 with dump mode active

    pi@raspberrypi ~ $ mbtget -w6 333 -a 1000 -d 127.0.0.1 
    Tx
    [10 01 00 00 00 06 01] 06 03 E8 01 4D
    
    Rx
    [10 01 00 00 00 06 01] 06 03 E8 01 4D
    
    word write ok

## License

Software under version 3 of the GNU General Public License (http://www.gnu.org/licenses/quick-guide-gplv3.en.html).
