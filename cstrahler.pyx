# coding: utf-8

import numpy as np

cimport numpy as np
cimport cython
from common cimport ci, cj, ingrid, ilog2
from CppTermProgress cimport CppTermProgress


@cython.boundscheck(False)
@cython.wraparound(False)
def strahler(
        np.ndarray[float, ndim=2] elevations,
        np.ndarray[unsigned char, ndim=2] flowdir,
        np.ndarray[unsigned char, ndim=2] out,
        float nodata):

    cdef long height, width, k, x
    cdef np.ndarray[long] idx
    cdef np.ndarray[unsigned char, ndim=2] count
    cdef long i, j, ix, jx, dx
    cdef float z
    cdef CppTermProgress progress

    height = elevations.shape[0]
    width = elevations.shape[1]

    progress = CppTermProgress(height*width)

    progress.write('Sort input by z ...')

    idx = elevations.reshape(height*width).argsort(kind='mergesort')
    count = np.zeros((height, width), dtype=np.uint8)

    progress.write('Compute strahler order ...')
    x = idx[height*width-1]
    msg  = 'Start from Z = %.3f' % elevations[ x // width, x % width ]
    progress.write(msg)

    with nogil:

        for k in range(height*width-1, -1, -1):

            x = idx[k]
            i = x // width
            j = x  % width

            z = elevations[ i, j ]

            if z == nodata:

                progress.update(1)
                continue

            if count[ i, j ] > 1:

                out[ i, j ] = out[ i, j ] + 1

            dx = flowdir[ i, j ]

            if dx > 0:

                dx = ilog2(dx)
                ix = i + ci[dx]
                jx = j + cj[dx]

                if ingrid(height, width, ix, jx):

                    if out[ i, j ] > out[ ix, jx ]:

                        out[ ix, jx ] = out[ i, j ]
                        count[ ix, jx ] = 1

                    elif out[ i, j ] == out[ ix, jx ]:

                        count[ ix, jx ] = count[ i, j ] + 1

            progress.update(1)

    progress.close()