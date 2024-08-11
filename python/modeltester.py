import cv2
import math

import matplotlib.pyplot as plt
import numpy as np

def generate_test_image(img_str):
    img = cv2.imread(img_str)
    height,width,channels = img.shape
    if channels != 3:
        return False
    else:
        height_bisector = math.floor(height/2)
        width_bisector = math.floor(width/2)
        if height > width:
            img_cropped = img[\
                (height_bisector-width_bisector):\
                    (height_bisector+width_bisector), 0:width]
        else:
            img_cropped = img[\
                0:height, (width_bisector-height_bisector):\
                    (width_bisector+height_bisector)]
        img_resized = cv2.resize(img_cropped, (64,64), interpolation=cv2.INTER_AREA)
        parts = img_str.split('.')
        write_binary_img_file(img_resized, parts[0])
        return cv2.imwrite(parts[0] + '64x64.png', img_resized)

def write_binary_img_file(img, img_name):
    # plt.imshow(img[...,::-1])
    # plt.show()
    binaryFile = open(img_name + ".txt", "w")
    img_size = img.shape
    for i in range(img_size[0]):
        for j in range(img_size[1]):
            for k in reversed(range(img_size[2])):
                binaryFile.write(bin(img[i,j,k])[2:].zfill(8) + '\n')
    binaryFile.close()

def recreate_image(file, height, width):
    image = np.zeros([height, width, 3])
    with open(file, 'r') as f:
        text = f.read()
        elements = text.split()
        for idx in range(0, height):
            for jdx in range(0, width):
                for kdx in range(0, 3):
                    element = elements[3 * (idx * width + jdx) + kdx]
                    try:
                        value   = int(element,2)/255.0
                    except Exception as e:
                        print(idx, jdx, kdx)
                        value = 1.0
                    image[idx, jdx, kdx] = value
    # plt.imshow(image)
    # plt.show()
    return image

if __name__ == "__main__":
    generate_test_image("python/lena.jpg")
    recreate_image("python/lena.txt", 64, 64)