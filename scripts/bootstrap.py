# -*- coding: utf-8 -*-
import serial
import struct
import time

def main():
    upload('../src/bb.com', 'b:bb.com')

def upload(srcfile):
    with open(srcfile,'rb') as f:
        data = bytearray(f.read())

    ser = serial.Serial('COM6', 1200)
    if not ser.isOpen():
        print("Opening port")
        ser.open()
    
    # output number of bytes
    print('Transferring package size: 0x%04X bytes' % len(data))
    
    # sending number of bytes to receive
    ser.write(struct.pack('<H', len(data))) # little endian
    
    time.sleep(0.5) # wait second for P2000C to catch up
        
    # transmit data
    ser.write(data)

if __name__ == '__main__':
    main()