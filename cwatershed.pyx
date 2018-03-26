# coding: utf-8

import numpy as np
import array

cimport numpy as np
cimport cython
from cpython cimport array
# from libc.stdio cimport sprintf
from libcpp.pair cimport pair
from libcpp.stack cimport stack
from libcpp.queue cimport priority_queue
from CppTermProgress cimport CppTermProgress

ctypedef pair[int, int] Cell
ctypedef stack[Cell] CellStack
ctypedef pair[float, Cell] QueueEntry
ctypedef priority_queue[QueueEntry] CellQueue

#                                    0   1   2   3   4   5   6   7
#                                    N  NE   E  SE   S  SW   W  NW
cdef int[8] ci = array.array('i', [ -1, -1,  0,  1,  1,  1,  0, -1 ])
cdef int[8] cj = array.array('i', [  0,  1,  1,  1,  0, -1, -1, -1 ])

# upward = np.power(2, np.array([ 4,  5,  6,  7,  0,  1,  2,  3 ], dtype=np.uint8))
cdef unsigned char[8] upward = array.array('B', [ 16,  32,  64,  128,  1,  2,  4,  8 ])

cdef inline bint ingrid(long height, long width, int i, int j) nogil:

    return (i >= 0) and (i < height) and (j >= 0) and (j < width)

cdef inline int ilog2(unsigned char x) nogil:

    cdef int r = 0

    if x == 0:
        return -1

    while x != 1:
        r += 1
        x = x >> 1

    return r

@cython.boundscheck(False)
@cython.wraparound(False)
def upslope(
        np.ndarray[unsigned char, ndim=2] data,
        np.ndarray[int, ndim=2] out,
        int i0,
        int j0,
        unsigned char nodata,
        int watershed_id):

    cdef long height, width
    cdef CppTermProgress progress

    height = data.shape[0]
    width  = data.shape[1]

    progress = CppTermProgress(height*width)
    _upslope(data, out, i0, j0, nodata, watershed_id, progress)

@cython.boundscheck(False)
@cython.wraparound(False)
cdef void _upslope(
        np.ndarray[unsigned char, ndim=2] data,
        np.ndarray[int, ndim=2] out,
        int i0,
        int j0,
        unsigned char nodata,
        int watershed_id,
        CppTermProgress& progress):

    cdef long height, width
    cdef CellStack process_stack
    cdef Cell c
    cdef int i, j, ni, nj, x, w

    # with nogil:

    height = data.shape[0]
    width  = data.shape[1]

    # progress = CppTermProgress(width*height)
    # msg = 'Input is %d x %d' % (width, height)
    # progress.write(msg)

    c = Cell(i0, j0)
    process_stack.push(c)

    while not process_stack.empty():

        c = process_stack.top()
        process_stack.pop()

        i = c.first
        j = c.second

        if data[ i, j ] == nodata:
            continue

        out[ i, j ] = watershed_id
        progress.update(1)

        for x in range(8):

            ni = i + ci[x]
            nj = j + cj[x]

            if not ingrid(height, width, ni, nj):
                continue

            w = out[ ni, nj ]
            if (data[ ni, nj ] == upward[x]) and (w == 0 or w == -1):

                c = Cell(ni, nj)
                process_stack.push(c)


@cython.boundscheck(False)
@cython.wraparound(False)
def watershed(
        np.ndarray[unsigned char, ndim=2] data,
        np.ndarray[int, ndim=2] out,
        int i0,
        int j0,
        unsigned char nodata,
        int watershed_id):

    cdef long height, width
    cdef int i, j, si, sj, down_x
    cdef CppTermProgress progress

    height = data.shape[0]
    width  = data.shape[1]

    progress = CppTermProgress(height*width)
    i, j = i0, j0

    while ingrid(height, width, i, j) and out[i, j] == 0:

        out[ i, j ] = -1

        si = i
        sj = j

        down_x = ilog2(data[ i, j ])
        i = i + ci[down_x]
        j = j + cj[down_x]

    _upslope(data, out, si, sj, nodata, watershed_id, progress)

@cython.boundscheck(False)
@cython.wraparound(False)
def all_watersheds(
        np.ndarray[float, ndim=2] elevation,
        np.ndarray[unsigned char, ndim=2] flowdir,
        np.ndarray[int, ndim=2] out,
        float nodata):

    cdef long height, width
    cdef float z
    cdef int i, j, k, ik, jk
    cdef int watershed_id = 0

    cdef Cell c
    cdef QueueEntry entry
    cdef CellQueue process_stack
    cdef CppTermProgress progress

    height = elevation.shape[0]
    width  = elevation.shape[1]

    progress = CppTermProgress(2*width*height)
    progress.write('Find boundary cells ...')

    for i in range(height):
        for j in range(width):

            z = elevation[ i, j ]
            
            if z != nodata:
                
                for k in range(8):
                
                    ik = i + ci[k]
                    jk = j + cj[k]
                
                    if not ingrid(height, width, ik, jk):
                        
                        c = Cell(i, j)
                        entry = QueueEntry(-z, c)
                        process_stack.push(entry)

                        break

            progress.update(1)

    progress.write('Find watersheds ...')

    while not process_stack.empty():

        entry = process_stack.top()
        process_stack.pop()

        c = entry.second
        i = c.first
        j = c.second

        if out[ i, j ] == 0:

            watershed_id += 1
            _upslope(flowdir, out, i, j, 0, watershed_id, progress)

    msg = 'Found %d watersheds' % watershed_id
    progress.write(msg)
    progress.write('Done.')
    progress.close()