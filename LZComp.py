
# -*- coding: ascii -*-
# Lempel-Ziv-Welch encoding algorithm in python
# based on psudo code from http://www.geeksforgeeks.org/lzw-lempel-ziv-welch-compression-technique/
# made by Ron Tam
# -*- coding: utf-8 -*-
SIZE = 255

SIZE = 256


def start_compress_dict(size):
    """
    creates dictionary of all ascii elements until [size]
    [key:char,value:num]
    returns dictionary
    """
    dicti = {}
    for i in xrange(size):
        dicti[chr(i)] = i
    return dicti


def compress(uncompressed):
    """
    Receives a string and returns a list of the compressed values
    """
    dict_size = 256
    dicti = start_compress_dict(dict_size)
    output = []  # start of stream
    p = ""  # [p]revious char

    for c in uncompressed:  # [c]urrent char
        if p + c in dicti:
            p += c
        else:
            output.append(dicti[p])
            dicti[p+c] = dict_size
            dict_size += 1

            p = c

    # If we have one character left
    if p:
        output.append(dicti[p])
    return output


def start_uncompress_dict(size):
    """
    creates dictionary of all ascii elements until [size]
    [key:num,value:char]
    returns dictionary
    """
    dicti = {}
    for i in xrange(size):
        dicti[i] = chr(i)
    return dicti


def uncompress(stream):
    """
    receives a list of compressed values and returns the uncompressed value
    """
    dic_size = 256
    dicti = start_uncompress_dict(dic_size)

    output = ""
    old = stream.pop(0)
#    print stream
    output += dicti[old]
    c = None

    for new in stream:
        if new not in dicti:
            s = dicti[old]
            s += c
        else:
            s = dicti[new]
        output += s
        c = s[0]
        dicti[dic_size] = dicti[old] + c
        dic_size += 1
        old = new

    return output


def get_file_stream(file_name):
    """
    opens file name and returns string of file contents
    (opened as binary)
    """
    with open(file_name, 'rb+') as my_file:
        return my_file.read()


def write_to_file(stream, name):
    """
    writes the given stream to the file with the given name
    creates new file if the other does not exist
    """
    with open(name, 'wb+') as my_file:
        my_file.write(stream)


def main():
    """
    Add Documentation here
    """
##    stream = raw_input(">>>")
    stream = get_file_stream("test.jpg")

    encoded = compress(stream)
    decoded = uncompress(encoded)

    write_to_file(decoded, 't2.jpg')


if __name__ == '__main__':
    main()
