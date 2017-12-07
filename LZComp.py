# -*- coding: utf-8 -*-
SIZE = 255


def start_encode_dict(size):
    dicti = {}
    for i in xrange(size):
        dicti[chr(i)] = i
    return dicti


def encode(stream):
    place_in_dictionary = SIZE + 1
    dicti = start_encode_dict(SIZE)
    output = []  # start of stream
    p = stream[0]  # next byte
    for c in stream[1:]:
        if p + c in dicti:
            p += c
        else:
            output.append(dicti[p])
            dicti[p+c] = place_in_dictionary
            place_in_dictionary += 1
            p = c

    # If we have one character left
    if p:
        output.append(dicti[p])
    return output


def start_decode_dict(size):
    dicti = {}
    for i in xrange(size):
        dicti[i] = chr(i)
    return dicti


def decode(stream):
    place_in_dictionary = SIZE + 1
    dicti = start_decode_dict(SIZE)
    old = stream[0]
    output = dicti[old]
    c = None
    for new in stream[1:]:
        if new not in dicti:
            s = dicti[old]
            s += c
        else:
            s = dicti[new]
        output += s
        c = s[0]
        dicti[place_in_dictionary] = dicti[old] + c
        place_in_dictionary += 1
        old = new

    return output


def main():
    """
    Add Documentation here
    """
##    stream = raw_input(">>>")
    stream = "BABAABAAA"
    out = encode(stream)
    print out
    out = decode(out)
    print out


if __name__ == '__main__':
    main()
