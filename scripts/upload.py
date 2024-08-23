# -*- coding: utf-8 -*-
import serial
import struct
import time

def main():
    upload('../src/bb.com')

def upload(file):
    with open(file,'rb') as f:
        data = bytearray(f.read())

    ser = serial.Serial('COM6', 1200)
    if not ser.isOpen():
        print("Opening port")
        ser.open()
    
    print('Transferring package size: 0x%04x bytes' % len(data))
    ser.write(struct.pack('<H', len(data))) # little endian
    rsp = ser.read(2)
    print('Response: 0x%04X' % struct.unpack('<H', rsp))
    
    # transmit filename
    filename = bytearray("b:test.com".encode('ascii'))
    filename.append(0x00)
    ser.write(filename)
    
    time.sleep(1) # wait second for P2000C to catch up
    
    # transmit data
    ser.write(data)

if __name__ == '__main__':
    main()