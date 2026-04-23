import serial as serial
import numpy as np
import struct as struct
import matplotlib.pyplot as plt

IMAGE_SIZE = 256

ser = serial.Serial('COM3', 115200)

fpgaIm = np.zeros([IMAGE_SIZE, IMAGE_SIZE])

pixelValsRaw = ser.read(int(IMAGE_SIZE*IMAGE_SIZE))
pixelVals = struct.unpack(f'<{int(IMAGE_SIZE*IMAGE_SIZE)}B', pixelValsRaw)

fpgaIm = np.reshape(np.array(pixelVals), [IMAGE_SIZE, IMAGE_SIZE])

print(fpgaIm)

plt.imshow(fpgaIm, cmap='gray', vmin=0, vmax=255)
plt.title("FPGA image")
plt.show()


swIm = plt.imread('cameraman.bmp')
plt.imshow(swIm, cmap='gray', vmin=0, vmax=255)
plt.title("SW original image")
plt.show()

plt.imshow(swIm-fpgaIm, cmap='gray', vmin=0, vmax=255)
plt.title("Differences between FPGA and SW image")
plt.show()
