# mbtget (modbus class 1 client)

This a simple perl script for make some modbus transaction from the command line. 

## Setup (for Linux):
1. just copy "mbtget.pl" to /usr/local/bin/ (it's the script path for user scripts in debian system).
2. set chmod +x /usr/local/bin/mbtget.pl to set execution flag

## Usage example

### read a word data at adress 1000 on modbus server at 127.0.0.1

    [root@spartacus root]# mbtget -a 1000 127.0.0.1
    
    values:
    1 (ad 01000): 52544

### write a word value of 333 at address 1000 on modbus server at 127.0.0.1 with dump mode active

    [root@spartacus root]# mbtget -w6 333 -a 1000 -d 127.0.0.1 
    Tx
    [10 01 00 00 00 06 01] 06 03 E8 01 4D
    
    Rx
    [10 01 00 00 00 06 01] 06 03 E8 01 4D
    
    word write ok
