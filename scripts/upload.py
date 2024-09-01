# -*- coding: utf-8 -*-
import serial
import struct
import time

def main():
    upload('../src/bb.com', 'b:bb2.com')

def upload(srcfile, dstfile):
    with open(srcfile,'rb') as f:
        data = bytearray(f.read())

    ser = serial.Serial('COM6', 9600, parity=serial.PARITY_ODD)
    if not ser.isOpen():
        print("Opening port")
        ser.open()
    
    print('Transferring package size: 0x%04X bytes' % len(data))
    print('Package checksum: 0x%04X' % crc16(data))
    
    # sending number of bytes to receive
    ser.write(struct.pack('<H', len(data))) # little endian
    
    # sending checksum
    ser.write(struct.pack('<H', crc16(data)))
    
    # check response filesize
    rsp = ser.read(2)
    print('Response filesize: 0x%04X bytes' % struct.unpack('<H', rsp))
    
    # check response checksum
    rsp = ser.read(2)
    print('Response checksum: 0x%04X' % struct.unpack('<H', rsp))
    
    time.sleep(1.0) # wait second for P2000C to catch up
    
    # transmit filename
    filename = bytearray(dstfile.encode('ascii'))
    filename.append(0x00)
    ser.write(filename)
    
    time.sleep(0.5) # wait second for P2000C to catch up
    
    # transmit data
    ser.write(data)

def crc16(data):
    crc = int(0)
    
    poly = 0x1021
    
    for c in data: # fetch byte
        crc ^= (c << 8) # xor into top byte
        for i in range(8): # prepare to rotate 8 bits
            crc = crc << 1 # rotate
            if crc & 0x10000:
                crc = (crc ^ poly) & 0xFFFF # xor with XMODEN polynomic
    
    return crc

if __name__ == '__main__':
    main()