# -*- coding: utf-8 -*-

"""
##################################################################################
# PyFFmpeg v2.3
#
# Copyright (C) 2011-2015 Martin Haller <martin@h4ll3r.net>
# Copyright (C) 2011 Bertrand Nouvel <bertrand@lm3labs.com>
# Copyright (C) 2008-2010 Bertrand Nouvel <nouvel@nii.ac.jp>
#   Japanese French Laboratory for Informatics -  CNRS
#
##################################################################################
#  This file is distibuted under LGPL-3.0
#  See COPYING file attached.
##################################################################################
#
#    TODO:
#       * check motion vector related functions
#       * why seek_before mandatory
#       * Add support for video encoding
#       * add multithread support
#       * Fix first frame bug... 
#
#    Abilities
#     * Frame seeking (TO BE CHECKED again and again)
#
#    Changed compared with PyFFmpeg version 1.0:
#     * Clean up destructors
#     * Added compatibility with NumPy and PIL
#     * Added copyless mode for ordered streams/tracks ( when buffers are disabled)
#     * Added audio support
#     * MultiTrack support (possibility to pass paramer)
#     * Added support for streamed video
#     * Updated ID for compatibility with transparency
#     * Updated to latest avcodec primitives
#
##################################################################################
# Based on Pyffmpeg 0.2 by
# Copyright (C) 2006-2007 James Evans <jaevans@users.sf.net>
# Authorization to change from GPL2.0 to LGPL 3.0 provided by original author for 
# this new version
##################################################################################
"""

##################################################################################
# Settings
##################################################################################
AVCODEC_MAX_AUDIO_FRAME_SIZE=192000
AVPROBE_PADDING_SIZE=32
OUTPUTMODE_NUMPY=0
OUTPUTMODE_PIL=1


##################################################################################
#  Declaration and imports
##################################################################################
import sys
import traceback


##################################################################################
# ffmpeg uses following integer types
ctypedef signed char int8_t
ctypedef unsigned char uint8_t
ctypedef signed short int16_t
ctypedef unsigned short uint16_t
ctypedef signed long int32_t
ctypedef unsigned long uint32_t
ctypedef signed long long int64_t
ctypedef unsigned long long uint64_t

# other types
ctypedef char const_char "const char"
ctypedef AVCodecContext const_AVCodecContext "const AVCodecContext"
ctypedef struct const_struct_AVSubtitle "const struct AVSubtitle"
ctypedef AVFrame const_AVFrame "const AVFrame" 
ctypedef AVClass const_AVClass "const AVClass"
ctypedef struct const_struct_AVCodec "const struct AVCodec"
ctypedef AVCodecDescriptor const_AVCodecDescriptor "const AVCodecDescriptor"

##################################################################################
cdef enum:
    SEEK_SET = 0
    SEEK_CUR = 1
    SEEK_END = 2


##################################################################################
cdef extern from "string.h":
    memcpy(void * dst, void * src, unsigned long sz)
    memset(void * dst, unsigned char c, unsigned long sz)
    

##################################################################################
# ok libavutil    54. 20.100
cdef extern from "libavutil/mathematics.h":
    int64_t av_rescale(int64_t a, int64_t b, int64_t c)


##################################################################################
# ok libavutil    54. 20.100
cdef extern from "libavutil/mem.h":
    void *av_mallocz(size_t size)
    void *av_realloc(void * ptr, size_t size)
    void av_free(void *ptr)
    void av_freep(void *ptr)


##################################################################################
# ok libavutil    54. 20.100
cdef extern from "libavutil/rational.h":
    struct AVRational:
        int num                    #< numerator
        int den                    #< denominator

##################################################################################
# ok libavutil    54. 20.100
cdef extern from "libavutil/version.h":

    DEF LIBAVUTIL_VERSION_MAJOR = 54
    DEF LIBAVUTIL_VERSION_MINOR = 20
    DEF LIBAVUTIL_VERSION_MICRO = 100

    enum:
        FF_API_OLD_AVOPTIONS           = (LIBAVUTIL_VERSION_MAJOR < 55)
        FF_API_PIX_FMT                 = (LIBAVUTIL_VERSION_MAJOR < 55)
        FF_API_CONTEXT_SIZE            = (LIBAVUTIL_VERSION_MAJOR < 55)
        FF_API_PIX_FMT_DESC            = (LIBAVUTIL_VERSION_MAJOR < 55)
        FF_API_AV_REVERSE              = (LIBAVUTIL_VERSION_MAJOR < 55)
        FF_API_AUDIOCONVERT            = (LIBAVUTIL_VERSION_MAJOR < 55)
        FF_API_CPU_FLAG_MMX2           = (LIBAVUTIL_VERSION_MAJOR < 55)
        FF_API_LLS_PRIVATE             = (LIBAVUTIL_VERSION_MAJOR < 55)
        FF_API_AVFRAME_LAVC            = (LIBAVUTIL_VERSION_MAJOR < 55)
        FF_API_VDPAU                   = (LIBAVUTIL_VERSION_MAJOR < 55)
        FF_API_GET_CHANNEL_LAYOUT_COMPAT= (LIBAVUTIL_VERSION_MAJOR < 55)
        FF_API_XVMC                    = (LIBAVUTIL_VERSION_MAJOR < 55)
        FF_API_OPT_TYPE_METADATA       = (LIBAVUTIL_VERSION_MAJOR < 55)


##################################################################################
# ok libavutil    54. 20.100
cdef extern from "libavutil/opt.h":

    enum:
        AV_OPT_FLAG_ENCODING_PARAM = 1   #< a generic parameter which can be set by the user for muxing or encoding
        AV_OPT_FLAG_DECODING_PARAM = 2   #< a generic parameter which can be set by the user for demuxing or decoding

        # deprecated, will be removed in master 55
        # IF FF_API_OPT_TYPE_METADATA == 1:
        AV_OPT_FLAG_METADATA       = 4   #< some data extracted or inserted into the file like title, comment, ...

        AV_OPT_FLAG_AUDIO_PARAM    = 8
        AV_OPT_FLAG_VIDEO_PARAM    = 16
        AV_OPT_FLAG_SUBTITLE_PARAM = 32
        AV_OPT_FLAG_EXPORT         = 64  #< The option is inteded for exporting values to the caller.
        AV_OPT_FLAG_READONLY       = 128
        AV_OPT_FLAG_FILTERING_PARAM = (1<<16) #< a generic parameter which can be set by the user for filtering

    enum AVOptionType:
        AV_OPT_TYPE_FLAGS,
        AV_OPT_TYPE_INT,
        AV_OPT_TYPE_INT64,
        AV_OPT_TYPE_DOUBLE,
        AV_OPT_TYPE_FLOAT,
        AV_OPT_TYPE_STRING,
        AV_OPT_TYPE_RATIONAL,
        AV_OPT_TYPE_BINARY,  #< offset must point to a pointer immediately followed by an int for the length
        AV_OPT_TYPE_DICT,
        AV_OPT_TYPE_CONST = 128,
        AV_OPT_TYPE_IMAGE_SIZE = 0x53495a45, # MKBETAG('S','I','Z','E')
        AV_OPT_TYPE_PIXEL_FMT  = 0x50464d54, # MKBETAG('P','F','M','T')
        AV_OPT_TYPE_SAMPLE_FMT = 0x53464d54, # MKBETAG('S','F','M','T')
        AV_OPT_TYPE_VIDEO_RATE = 0x56524154, # MKBETAG('V','R','A','T')
        AV_OPT_TYPE_DURATION   = 0x44555220, # MKBETAG('D','U','R',' ')
        AV_OPT_TYPE_COLOR      = 0x434f4c52, # MKBETAG('C','O','L','R')
        AV_OPT_TYPE_CHANNEL_LAYOUT = 0x43484c41, # MKBETAG('C','H','L','A')
        # BEGIN deprecated, will be removed in major 55
        FF_OPT_TYPE_FLAGS = 0,
        FF_OPT_TYPE_INT,
        FF_OPT_TYPE_INT64,
        FF_OPT_TYPE_DOUBLE,
        FF_OPT_TYPE_FLOAT,
        FF_OPT_TYPE_STRING,
        FF_OPT_TYPE_RATIONAL,
        FF_OPT_TYPE_BINARY,  #< offset must point to a pointer immediately followed by an int for the length
        FF_OPT_TYPE_CONST=128
        # END deprecated, will be removed in major 55

    union AVOptionDefaultValUnion:
        int64_t i64
        double dbl
        const_char *str
        AVRational q

    struct AVOption:
        const_char *name
        const_char *help    #< short English help text
        int offset
        AVOptionType type
        
        AVOptionDefaultValUnion default_val
        
        double min          #< minimum valid value for the option
        double max          #< maximum valid value for the option
        int flags
        const_char *unit    #< The logical unit to which the option belongs
    
    struct AVOptionRange:
        const_char *str
        double value_min 
        double value_max
        double component_min
        double component_max
        int is_range
        
    struct AVOptionRanges:
        AVOptionRange **range   #< Array of option ranges
        int nb_ranges           #< Number of ranges per component
        int nb_components       #< Number of componentes
    
    int av_opt_set         (void *obj, char *name, const char *val, int search_flags)
    int av_opt_set_int     (void *obj, char *name, int64_t     val, int search_flags)
    int av_opt_set_double  (void *obj, char *name, double      val, int search_flags)
    int av_opt_set_q       (void *obj, char *name, AVRational  val, int search_flags)
    int av_opt_set_bin     (void *obj, char *name, uint8_t *val, int size, int search_flags)
    int av_opt_set_image_size(void *obj, char *name, int w, int h, int search_flags)
    int av_opt_set_pixel_fmt (void *obj, char *name, AVPixelFormat fmt, int search_flags)
    int av_opt_set_sample_fmt(void *obj, char *name, AVSampleFormat fmt, int search_flags)
    int av_opt_set_video_rate(void *obj, char *name, AVRational val, int search_flags)
    int av_opt_set_channel_layout(void *obj, char *name, int64_t ch_layout, int search_flags)
    
    
    
##################################################################################
# ok libavutil    54. 20.100
cdef extern from "libavutil/log.h":
    enum AVClassCategory:
        AV_CLASS_CATEGORY_NA = 0,
        AV_CLASS_CATEGORY_INPUT,
        AV_CLASS_CATEGORY_OUTPUT,
        AV_CLASS_CATEGORY_MUXER,
        AV_CLASS_CATEGORY_DEMUXER,
        AV_CLASS_CATEGORY_ENCODER,
        AV_CLASS_CATEGORY_DECODER,
        AV_CLASS_CATEGORY_FILTER,
        AV_CLASS_CATEGORY_BITSTREAM_FILTER,
        AV_CLASS_CATEGORY_SWSCALER,
        AV_CLASS_CATEGORY_SWRESAMPLER,
        AV_CLASS_CATEGORY_DEVICE_VIDEO_OUTPUT = 40,
        AV_CLASS_CATEGORY_DEVICE_VIDEO_INPUT,
        AV_CLASS_CATEGORY_DEVICE_AUDIO_OUTPUT,
        AV_CLASS_CATEGORY_DEVICE_AUDIO_INPUT,
        AV_CLASS_CATEGORY_DEVICE_OUTPUT,
        AV_CLASS_CATEGORY_DEVICE_INPUT,
        AV_CLASS_CATEGORY_NB

    struct AVClass:
        char* class_name
        char* (*item_name)(void* ctx)
        AVOption *option
        int version
        int log_level_offset_offset
        int parent_log_context_offset
        AVClass* (*child_class_next)(AVClass *prev)
        AVClassCategory category
        AVClassCategory (*get_category)(void* ctx)
        int (*query_ranges)(AVOptionRanges **, void *obj, const_char *key, int flags)

    
##################################################################################
# ok libavutil   54. 20.100
cdef extern from "libavutil/dict.h":
    
    enum:
        AV_DICT_MATCH_CASE      = 1 #< Only get an entry with exact-case key match. Only relevant in av_dict_get().
        AV_DICT_IGNORE_SUFFIX   = 2 #< Return first entry in a dictionary whose first part corresponds to the search key, ignoring the suffix of the found key string. Only relevant in av_dict_get().
        AV_DICT_DONT_STRDUP_KEY = 4 #< Take ownership of a key that's been allocated with av_malloc() or another memory allocation function.
        AV_DICT_DONT_STRDUP_VAL = 8 #< Take ownership of a value that's been allocated with av_malloc() or another memory allocation function.
        AV_DICT_DONT_OVERWRITE  = 16 #< Don't overwrite existing entries.
        AV_DICT_APPEND          = 32 #< If the entry already exists, append to it.  Note that no delimiter is added, the strings are simply concatenated. 
    
    struct AVDictionaryEntry:
        char *key
        char *value

    ctypedef struct AVDictionary
    
    # Get number of entries in dictionary.
    int av_dict_count(const AVDictionary *m)
    
    # Set the given entry in *pm, overwriting an existing entry.
    int av_dict_set(AVDictionary **pm, char *key, char *value, int flags)
    
    # Convenience wrapper for av_dict_set that converts the value to a string
    # and stores it.
    int av_dict_set_int(AVDictionary **pm, char *key, int64_t value, int flags)

    # Free all the memory allocated for an AVDictionary struct
    void av_dict_free(AVDictionary **m)
    
    
##################################################################################
# ok libavutil   54. 20.100
cdef extern from "libavutil/buffer.h":
    
    ctypedef struct AVBuffer
    
    struct AVBufferRef:
        AVBuffer *buffer
        uint8_t *data       #< The data buffer
        int size            #< Size of data in bytes


##################################################################################
# ok libavutil   54. 20.100
cdef extern from "libavutil/pixfmt.h":
    enum AVPixelFormat:
        AV_PIX_FMT_NONE = -1,
        AV_PIX_FMT_YUV420P,   #< planar YUV 4:2:0, 12bpp, (1 Cr & Cb sample per 2x2 Y samples)
        AV_PIX_FMT_YUYV422,   #< packed YUV 4:2:2, 16bpp, Y0 Cb Y1 Cr
        AV_PIX_FMT_RGB24,     #< packed RGB 8:8:8, 24bpp, RGBRGB...
        AV_PIX_FMT_BGR24,     #< packed RGB 8:8:8, 24bpp, BGRBGR...
        AV_PIX_FMT_YUV422P,   #< planar YUV 4:2:2, 16bpp, (1 Cr & Cb sample per 2x1 Y samples)
        AV_PIX_FMT_YUV444P,   #< planar YUV 4:4:4, 24bpp, (1 Cr & Cb sample per 1x1 Y samples)
        AV_PIX_FMT_YUV410P,   #< planar YUV 4:1:0,  9bpp, (1 Cr & Cb sample per 4x4 Y samples)
        AV_PIX_FMT_YUV411P,   #< planar YUV 4:1:1, 12bpp, (1 Cr & Cb sample per 4x1 Y samples)
        AV_PIX_FMT_GRAY8,     #<        Y        ,  8bpp
        AV_PIX_FMT_MONOWHITE, #<        Y        ,  1bpp, 0 is white, 1 is black, in each byte pixels are ordered from the msb to the lsb
        AV_PIX_FMT_MONOBLACK, #<        Y        ,  1bpp, 0 is black, 1 is white, in each byte pixels are ordered from the msb to the lsb
        AV_PIX_FMT_PAL8,      #< 8 bit with PIX_FMT_RGB32 palette
        AV_PIX_FMT_YUVJ420P,  #< planar YUV 4:2:0, 12bpp, full scale (JPEG), deprecated in favor of PIX_FMT_YUV420P and setting color_range
        AV_PIX_FMT_YUVJ422P,  #< planar YUV 4:2:2, 16bpp, full scale (JPEG), deprecated in favor of PIX_FMT_YUV422P and setting color_range
        AV_PIX_FMT_YUVJ444P,  #< planar YUV 4:4:4, 24bpp, full scale (JPEG), deprecated in favor of PIX_FMT_YUV444P and setting color_range
    # if FF_API_XVMC
    # deprecated, will be removed in major 55
        AV_PIX_FMT_XVMC_MPEG2_MC, #< XVideo Motion Acceleration via common packet passing
        AV_PIX_FMT_XVMC_MPEG2_IDCT,
    # endif /* FF_API_XVMC */
        AV_PIX_FMT_UYVY422,   #< packed YUV 4:2:2, 16bpp, Cb Y0 Cr Y1
        AV_PIX_FMT_UYYVYY411, #< packed YUV 4:1:1, 12bpp, Cb Y0 Y1 Cr Y2 Y3
        AV_PIX_FMT_BGR8,      #< packed RGB 3:3:2,  8bpp, (msb)2B 3G 3R(lsb)
        AV_PIX_FMT_BGR4,      #< packed RGB 1:2:1 bitstream,  4bpp, (msb)1B 2G 1R(lsb), a byte contains two pixels, the first pixel in the byte is the one composed by the 4 msb bits
        AV_PIX_FMT_BGR4_BYTE, #< packed RGB 1:2:1,  8bpp, (msb)1B 2G 1R(lsb)
        AV_PIX_FMT_RGB8,      #< packed RGB 3:3:2,  8bpp, (msb)2R 3G 3B(lsb)
        AV_PIX_FMT_RGB4,      #< packed RGB 1:2:1 bitstream,  4bpp, (msb)1R 2G 1B(lsb), a byte contains two pixels, the first pixel in the byte is the one composed by the 4 msb bits
        AV_PIX_FMT_RGB4_BYTE, #< packed RGB 1:2:1,  8bpp, (msb)1R 2G 1B(lsb)
        AV_PIX_FMT_NV12,      #< planar YUV 4:2:0, 12bpp, 1 plane for Y and 1 plane for the UV components, which are interleaved (first byte U and the following byte V)
        AV_PIX_FMT_NV21,      #< as above, but U and V bytes are swapped

        AV_PIX_FMT_ARGB,      #< packed ARGB 8:8:8:8, 32bpp, ARGBARGB...
        AV_PIX_FMT_RGBA,      #< packed RGBA 8:8:8:8, 32bpp, RGBARGBA...
        AV_PIX_FMT_ABGR,      #< packed ABGR 8:8:8:8, 32bpp, ABGRABGR...
        AV_PIX_FMT_BGRA,      #< packed BGRA 8:8:8:8, 32bpp, BGRABGRA...

        AV_PIX_FMT_GRAY16BE,  #<        Y        , 16bpp, big-endian
        AV_PIX_FMT_GRAY16LE,  #<        Y        , 16bpp, little-endian
        AV_PIX_FMT_YUV440P,   #< planar YUV 4:4:0 (1 Cr & Cb sample per 1x2 Y samples)
        AV_PIX_FMT_YUVJ440P,  #< planar YUV 4:4:0 full scale (JPEG), deprecated in favor of PIX_FMT_YUV440P and setting color_range
        AV_PIX_FMT_YUVA420P,  #< planar YUV 4:2:0, 20bpp, (1 Cr & Cb sample per 2x2 Y & A samples)
    # if FF_API_VDPAU
    # deprecated, will be removed in major 55
        AV_PIX_FMT_VDPAU_H264,  #< H.264 HW decoding with VDPAU, data[0] contains a vdpau_render_state struct which contains the bitstream of the slices as well as various fields extracted from headers
        AV_PIX_FMT_VDPAU_MPEG1, #< MPEG-1 HW decoding with VDPAU, data[0] contains a vdpau_render_state struct which contains the bitstream of the slices as well as various fields extracted from headers
        AV_PIX_FMT_VDPAU_MPEG2, #< MPEG-2 HW decoding with VDPAU, data[0] contains a vdpau_render_state struct which contains the bitstream of the slices as well as various fields extracted from headers
        AV_PIX_FMT_VDPAU_WMV3,  #< WMV3 HW decoding with VDPAU, data[0] contains a vdpau_render_state struct which contains the bitstream of the slices as well as various fields extracted from headers
        AV_PIX_FMT_VDPAU_VC1,   #< VC-1 HW decoding with VDPAU, data[0] contains a vdpau_render_state struct which contains the bitstream of the slices as well as various fields extracted from headers
    # endif
        AV_PIX_FMT_RGB48BE,   #< packed RGB 16:16:16, 48bpp, 16R, 16G, 16B, the 2-byte value for each R/G/B component is stored as big-endian
        AV_PIX_FMT_RGB48LE,   #< packed RGB 16:16:16, 48bpp, 16R, 16G, 16B, the 2-byte value for each R/G/B component is stored as little-endian

        AV_PIX_FMT_RGB565BE,  #< packed RGB 5:6:5, 16bpp, (msb)   5R 6G 5B(lsb), big-endian
        AV_PIX_FMT_RGB565LE,  #< packed RGB 5:6:5, 16bpp, (msb)   5R 6G 5B(lsb), little-endian
        AV_PIX_FMT_RGB555BE,  #< packed RGB 5:5:5, 16bpp, (msb)1X 5R 5G 5B(lsb), big-endian   , X=unused/undefined
        AV_PIX_FMT_RGB555LE,  #< packed RGB 5:5:5, 16bpp, (msb)1X 5R 5G 5B(lsb), little-endian, X=unused/undefined

        AV_PIX_FMT_BGR565BE,  #< packed BGR 5:6:5, 16bpp, (msb)   5B 6G 5R(lsb), big-endian
        AV_PIX_FMT_BGR565LE,  #< packed BGR 5:6:5, 16bpp, (msb)   5B 6G 5R(lsb), little-endian
        AV_PIX_FMT_BGR555BE,  #< packed BGR 5:5:5, 16bpp, (msb)1X 5B 5G 5R(lsb), big-endian   , X=unused/undefined
        AV_PIX_FMT_BGR555LE,  #< packed BGR 5:5:5, 16bpp, (msb)1X 5B 5G 5R(lsb), little-endian, X=unused/undefined

        AV_PIX_FMT_VAAPI_MOCO, #< HW acceleration through VA API at motion compensation entry-point, Picture.data[3] contains a vaapi_render_state struct which contains macroblocks as well as various fields extracted from headers
        AV_PIX_FMT_VAAPI_IDCT, #< HW acceleration through VA API at IDCT entry-point, Picture.data[3] contains a vaapi_render_state struct which contains fields extracted from headers
        AV_PIX_FMT_VAAPI_VLD,  #< HW decoding through VA API, Picture.data[3] contains a vaapi_render_state struct which contains the bitstream of the slices as well as various fields extracted from headers

        AV_PIX_FMT_YUV420P16LE,  #< planar YUV 4:2:0, 24bpp, (1 Cr & Cb sample per 2x2 Y samples), little-endian
        AV_PIX_FMT_YUV420P16BE,  #< planar YUV 4:2:0, 24bpp, (1 Cr & Cb sample per 2x2 Y samples), big-endian
        AV_PIX_FMT_YUV422P16LE,  #< planar YUV 4:2:2, 32bpp, (1 Cr & Cb sample per 2x1 Y samples), little-endian
        AV_PIX_FMT_YUV422P16BE,  #< planar YUV 4:2:2, 32bpp, (1 Cr & Cb sample per 2x1 Y samples), big-endian
        AV_PIX_FMT_YUV444P16LE,  #< planar YUV 4:4:4, 48bpp, (1 Cr & Cb sample per 1x1 Y samples), little-endian
        AV_PIX_FMT_YUV444P16BE,  #< planar YUV 4:4:4, 48bpp, (1 Cr & Cb sample per 1x1 Y samples), big-endian
    
        AV_PIX_FMT_VDPAU_MPEG4,  #< MPEG4 HW decoding with VDPAU, data[0] contains a vdpau_render_state struct which contains the bitstream of the slices as well as various fields extracted from headers
    
        AV_PIX_FMT_DXVA2_VLD,    #< HW decoding through DXVA2, Picture.data[3] contains a LPDIRECT3DSURFACE9 pointer

        AV_PIX_FMT_RGB444LE,  #< packed RGB 4:4:4, 16bpp, (msb)4X 4R 4G 4B(lsb), little-endian, X=unused/undefined
        AV_PIX_FMT_RGB444BE,  #< packed RGB 4:4:4, 16bpp, (msb)4X 4R 4G 4B(lsb), big-endian,    X=unused/undefined
        AV_PIX_FMT_BGR444LE,  #< packed BGR 4:4:4, 16bpp, (msb)4X 4B 4G 4R(lsb), little-endian, X=unused/undefined
        AV_PIX_FMT_BGR444BE,  #< packed BGR 4:4:4, 16bpp, (msb)4X 4B 4G 4R(lsb), big-endian,    X=unused/undefined
        AV_PIX_FMT_YA8,       #< 8bit gray, 8bit alpha

        AV_PIX_FMT_Y400A = AV_PIX_FMT_YA8, #< alias for AV_PIX_FMT_YA8
        AV_PIX_FMT_GRAY8A= AV_PIX_FMT_YA8, #< alias for AV_PIX_FMT_YA8

        AV_PIX_FMT_BGR48BE,   #< packed RGB 16:16:16, 48bpp, 16B, 16G, 16R, the 2-byte value for each R/G/B component is stored as big-endian
        AV_PIX_FMT_BGR48LE,   #< packed RGB 16:16:16, 48bpp, 16B, 16G, 16R, the 2-byte value for each R/G/B component is stored as little-endian

        AV_PIX_FMT_YUV420P9BE, #< planar YUV 4:2:0, 13.5bpp, (1 Cr & Cb sample per 2x2 Y samples), big-endian
        AV_PIX_FMT_YUV420P9LE, #< planar YUV 4:2:0, 13.5bpp, (1 Cr & Cb sample per 2x2 Y samples), little-endian
        AV_PIX_FMT_YUV420P10BE,#< planar YUV 4:2:0, 15bpp, (1 Cr & Cb sample per 2x2 Y samples), big-endian
        AV_PIX_FMT_YUV420P10LE,#< planar YUV 4:2:0, 15bpp, (1 Cr & Cb sample per 2x2 Y samples), little-endian
        AV_PIX_FMT_YUV422P10BE,#< planar YUV 4:2:2, 20bpp, (1 Cr & Cb sample per 2x1 Y samples), big-endian
        AV_PIX_FMT_YUV422P10LE,#< planar YUV 4:2:2, 20bpp, (1 Cr & Cb sample per 2x1 Y samples), little-endian
        AV_PIX_FMT_YUV444P9BE, #< planar YUV 4:4:4, 27bpp, (1 Cr & Cb sample per 1x1 Y samples), big-endian
        AV_PIX_FMT_YUV444P9LE, #< planar YUV 4:4:4, 27bpp, (1 Cr & Cb sample per 1x1 Y samples), little-endian
        AV_PIX_FMT_YUV444P10BE,#< planar YUV 4:4:4, 30bpp, (1 Cr & Cb sample per 1x1 Y samples), big-endian
        AV_PIX_FMT_YUV444P10LE,#< planar YUV 4:4:4, 30bpp, (1 Cr & Cb sample per 1x1 Y samples), little-endian
        AV_PIX_FMT_YUV422P9BE, #< planar YUV 4:2:2, 18bpp, (1 Cr & Cb sample per 2x1 Y samples), big-endian
        AV_PIX_FMT_YUV422P9LE, #< planar YUV 4:2:2, 18bpp, (1 Cr & Cb sample per 2x1 Y samples), little-endian
        AV_PIX_FMT_VDA_VLD,    #< hardware decoding through VDA

        AV_PIX_FMT_RGBA64BE,  #< packed RGBA 16:16:16:16, 64bpp, 16R, 16G, 16B, 16A, the 2-byte value for each R/G/B/A component is stored as big-endian
        AV_PIX_FMT_RGBA64LE,  #< packed RGBA 16:16:16:16, 64bpp, 16R, 16G, 16B, 16A, the 2-byte value for each R/G/B/A component is stored as little-endian
        AV_PIX_FMT_BGRA64BE,  #< packed RGBA 16:16:16:16, 64bpp, 16B, 16G, 16R, 16A, the 2-byte value for each R/G/B/A component is stored as big-endian
        AV_PIX_FMT_BGRA64LE,  #< packed RGBA 16:16:16:16, 64bpp, 16B, 16G, 16R, 16A, the 2-byte value for each R/G/B/A component is stored as little-endian

        AV_PIX_FMT_GBRP,      #< planar GBR 4:4:4 24bpp
        AV_PIX_FMT_GBRP9BE,   #< planar GBR 4:4:4 27bpp, big-endian
        AV_PIX_FMT_GBRP9LE,   #< planar GBR 4:4:4 27bpp, little-endian
        AV_PIX_FMT_GBRP10BE,  #< planar GBR 4:4:4 30bpp, big-endian
        AV_PIX_FMT_GBRP10LE,  #< planar GBR 4:4:4 30bpp, little-endian
        AV_PIX_FMT_GBRP16BE,  #< planar GBR 4:4:4 48bpp, big-endian
        AV_PIX_FMT_GBRP16LE,  #< planar GBR 4:4:4 48bpp, little-endian

        AV_PIX_FMT_YUVA422P_LIBAV,  #< planar YUV 4:2:2 24bpp, (1 Cr & Cb sample per 2x1 Y & A samples)
        AV_PIX_FMT_YUVA444P_LIBAV,  #< planar YUV 4:4:4 32bpp, (1 Cr & Cb sample per 1x1 Y & A samples)

        AV_PIX_FMT_YUVA420P9BE,  #< planar YUV 4:2:0 22.5bpp, (1 Cr & Cb sample per 2x2 Y & A samples), big-endian
        AV_PIX_FMT_YUVA420P9LE,  #< planar YUV 4:2:0 22.5bpp, (1 Cr & Cb sample per 2x2 Y & A samples), little-endian
        AV_PIX_FMT_YUVA422P9BE,  #< planar YUV 4:2:2 27bpp, (1 Cr & Cb sample per 2x1 Y & A samples), big-endian
        AV_PIX_FMT_YUVA422P9LE,  #< planar YUV 4:2:2 27bpp, (1 Cr & Cb sample per 2x1 Y & A samples), little-endian
        AV_PIX_FMT_YUVA444P9BE,  #< planar YUV 4:4:4 36bpp, (1 Cr & Cb sample per 1x1 Y & A samples), big-endian
        AV_PIX_FMT_YUVA444P9LE,  #< planar YUV 4:4:4 36bpp, (1 Cr & Cb sample per 1x1 Y & A samples), little-endian
        AV_PIX_FMT_YUVA420P10BE, #< planar YUV 4:2:0 25bpp, (1 Cr & Cb sample per 2x2 Y & A samples, big-endian)
        AV_PIX_FMT_YUVA420P10LE, #< planar YUV 4:2:0 25bpp, (1 Cr & Cb sample per 2x2 Y & A samples, little-endian)
        AV_PIX_FMT_YUVA422P10BE, #< planar YUV 4:2:2 30bpp, (1 Cr & Cb sample per 2x1 Y & A samples, big-endian)
        AV_PIX_FMT_YUVA422P10LE, #< planar YUV 4:2:2 30bpp, (1 Cr & Cb sample per 2x1 Y & A samples, little-endian)
        AV_PIX_FMT_YUVA444P10BE, #< planar YUV 4:4:4 40bpp, (1 Cr & Cb sample per 1x1 Y & A samples, big-endian)
        AV_PIX_FMT_YUVA444P10LE, #< planar YUV 4:4:4 40bpp, (1 Cr & Cb sample per 1x1 Y & A samples, little-endian)
        AV_PIX_FMT_YUVA420P16BE, #< planar YUV 4:2:0 40bpp, (1 Cr & Cb sample per 2x2 Y & A samples, big-endian)
        AV_PIX_FMT_YUVA420P16LE, #< planar YUV 4:2:0 40bpp, (1 Cr & Cb sample per 2x2 Y & A samples, little-endian)
        AV_PIX_FMT_YUVA422P16BE, #< planar YUV 4:2:2 48bpp, (1 Cr & Cb sample per 2x1 Y & A samples, big-endian)
        AV_PIX_FMT_YUVA422P16LE, #< planar YUV 4:2:2 48bpp, (1 Cr & Cb sample per 2x1 Y & A samples, little-endian)
        AV_PIX_FMT_YUVA444P16BE, #< planar YUV 4:4:4 64bpp, (1 Cr & Cb sample per 1x1 Y & A samples, big-endian)
        AV_PIX_FMT_YUVA444P16LE, #< planar YUV 4:4:4 64bpp, (1 Cr & Cb sample per 1x1 Y & A samples, little-endian)

        AV_PIX_FMT_VDPAU,     #< HW acceleration through VDPAU, Picture.data[3] contains a VdpVideoSurface

        AV_PIX_FMT_XYZ12LE,      #< packed XYZ 4:4:4, 36 bpp, (msb) 12X, 12Y, 12Z (lsb), the 2-byte value for each X/Y/Z is stored as little-endian, the 4 lower bits are set to 0
        AV_PIX_FMT_XYZ12BE,      #< packed XYZ 4:4:4, 36 bpp, (msb) 12X, 12Y, 12Z (lsb), the 2-byte value for each X/Y/Z is stored as big-endian, the 4 lower bits are set to 0
        AV_PIX_FMT_NV16,         #< interleaved chroma YUV 4:2:2, 16bpp, (1 Cr & Cb sample per 2x1 Y samples)
        AV_PIX_FMT_NV20LE,       #< interleaved chroma YUV 4:2:2, 20bpp, (1 Cr & Cb sample per 2x1 Y samples), little-endian
        AV_PIX_FMT_NV20BE,       #< interleaved chroma YUV 4:2:2, 20bpp, (1 Cr & Cb sample per 2x1 Y samples), big-endian

        AV_PIX_FMT_RGBA64BE_LIBAV, #< packed RGBA 16:16:16:16, 64bpp, 16R, 16G, 16B, 16A, the 2-byte value for each R/G/B/A component is stored as big-endian
        AV_PIX_FMT_RGBA64LE_LIBAV, #< packed RGBA 16:16:16:16, 64bpp, 16R, 16G, 16B, 16A, the 2-byte value for each R/G/B/A component is stored as little-endian
        AV_PIX_FMT_BGRA64BE_LIBAV, #< packed RGBA 16:16:16:16, 64bpp, 16B, 16G, 16R, 16A, the 2-byte value for each R/G/B/A component is stored as big-endian
        AV_PIX_FMT_BGRA64LE_LIBAV, #< packed RGBA 16:16:16:16, 64bpp, 16B, 16G, 16R, 16A, the 2-byte value for each R/G/B/A component is stored as little-endian

        AV_PIX_FMT_YVYU422,   #< packed YUV 4:2:2, 16bpp, Y0 Cr Y1 Cb

        AV_PIX_FMT_VDA,          #< HW acceleration through VDA, data[3] contains a CVPixelBufferRef

        AV_PIX_FMT_YA16BE,       #< 16bit gray, 16bit alpha (big-endian)
        AV_PIX_FMT_YA16LE,       #< 16bit gray, 16bit alpha (little-endian)

        AV_PIX_FMT_GBRAP_LIBAV,        #< planar GBRA 4:4:4:4 32bpp
        AV_PIX_FMT_GBRAP16BE_LIBAV,    #< planar GBRA 4:4:4:4 64bpp, big-endian
        AV_PIX_FMT_GBRAP16LE_LIBAV,    #< planar GBRA 4:4:4:4 64bpp, little-endian
        AV_PIX_FMT_QSV,

        AV_PIX_FMT_RGBA64BE=0x123,  #< packed RGBA 16:16:16:16, 64bpp, 16R, 16G, 16B, 16A, the 2-byte value for each R/G/B/A component is stored as big-endian
        AV_PIX_FMT_RGBA64LE,        #< packed RGBA 16:16:16:16, 64bpp, 16R, 16G, 16B, 16A, the 2-byte value for each R/G/B/A component is stored as little-endian
        AV_PIX_FMT_BGRA64BE,        #< packed RGBA 16:16:16:16, 64bpp, 16B, 16G, 16R, 16A, the 2-byte value for each R/G/B/A component is stored as big-endian
        AV_PIX_FMT_BGRA64LE,        #< packed RGBA 16:16:16:16, 64bpp, 16B, 16G, 16R, 16A, the 2-byte value for each R/G/B/A component is stored as little-endian

        AV_PIX_FMT_0RGB=0x123+4, #< packed RGB 8:8:8, 32bpp, XRGBXRGB...   X=unused/undefined
        AV_PIX_FMT_RGB0,         #< packed RGB 8:8:8, 32bpp, RGBXRGBX...   X=unused/undefined
        AV_PIX_FMT_0BGR,         #< packed BGR 8:8:8, 32bpp, XBGRXBGR...   X=unused/undefined
        AV_PIX_FMT_BGR0,         #< packed BGR 8:8:8, 32bpp, BGRXBGRX...   X=unused/undefined
        AV_PIX_FMT_YUVA444P,     #< planar YUV 4:4:4 32bpp, (1 Cr & Cb sample per 1x1 Y & A samples)
        AV_PIX_FMT_YUVA422P,     #< planar YUV 4:2:2 24bpp, (1 Cr & Cb sample per 2x1 Y & A samples)

        AV_PIX_FMT_YUV420P12BE, #< planar YUV 4:2:0,18bpp, (1 Cr & Cb sample per 2x2 Y samples), big-endian
        AV_PIX_FMT_YUV420P12LE, #< planar YUV 4:2:0,18bpp, (1 Cr & Cb sample per 2x2 Y samples), little-endian
        AV_PIX_FMT_YUV420P14BE, #< planar YUV 4:2:0,21bpp, (1 Cr & Cb sample per 2x2 Y samples), big-endian
        AV_PIX_FMT_YUV420P14LE, #< planar YUV 4:2:0,21bpp, (1 Cr & Cb sample per 2x2 Y samples), little-endian
        AV_PIX_FMT_YUV422P12BE, #< planar YUV 4:2:2,24bpp, (1 Cr & Cb sample per 2x1 Y samples), big-endian
        AV_PIX_FMT_YUV422P12LE, #< planar YUV 4:2:2,24bpp, (1 Cr & Cb sample per 2x1 Y samples), little-endian
        AV_PIX_FMT_YUV422P14BE, #< planar YUV 4:2:2,28bpp, (1 Cr & Cb sample per 2x1 Y samples), big-endian
        AV_PIX_FMT_YUV422P14LE, #< planar YUV 4:2:2,28bpp, (1 Cr & Cb sample per 2x1 Y samples), little-endian
        AV_PIX_FMT_YUV444P12BE, #< planar YUV 4:4:4,36bpp, (1 Cr & Cb sample per 1x1 Y samples), big-endian
        AV_PIX_FMT_YUV444P12LE, #< planar YUV 4:4:4,36bpp, (1 Cr & Cb sample per 1x1 Y samples), little-endian
        AV_PIX_FMT_YUV444P14BE, #< planar YUV 4:4:4,42bpp, (1 Cr & Cb sample per 1x1 Y samples), big-endian
        AV_PIX_FMT_YUV444P14LE, #< planar YUV 4:4:4,42bpp, (1 Cr & Cb sample per 1x1 Y samples), little-endian
        AV_PIX_FMT_GBRP12BE,    #< planar GBR 4:4:4 36bpp, big-endian
        AV_PIX_FMT_GBRP12LE,    #< planar GBR 4:4:4 36bpp, little-endian
        AV_PIX_FMT_GBRP14BE,    #< planar GBR 4:4:4 42bpp, big-endian
        AV_PIX_FMT_GBRP14LE,    #< planar GBR 4:4:4 42bpp, little-endian
        AV_PIX_FMT_GBRAP,       #< planar GBRA 4:4:4:4 32bpp
        AV_PIX_FMT_GBRAP16BE,   #< planar GBRA 4:4:4:4 64bpp, big-endian
        AV_PIX_FMT_GBRAP16LE,   #< planar GBRA 4:4:4:4 64bpp, little-endian
        AV_PIX_FMT_YUVJ411P,    #< planar YUV 4:1:1, 12bpp, (1 Cr & Cb sample per 4x1 Y samples) full scale (JPEG), deprecated in favor of PIX_FMT_YUV411P and setting color_range

        AV_PIX_FMT_BAYER_BGGR8,    #< bayer, BGBG..(odd line), GRGR..(even line), 8-bit samples */
        AV_PIX_FMT_BAYER_RGGB8,    #< bayer, RGRG..(odd line), GBGB..(even line), 8-bit samples */
        AV_PIX_FMT_BAYER_GBRG8,    #< bayer, GBGB..(odd line), RGRG..(even line), 8-bit samples */
        AV_PIX_FMT_BAYER_GRBG8,    #< bayer, GRGR..(odd line), BGBG..(even line), 8-bit samples */
        AV_PIX_FMT_BAYER_BGGR16LE, #< bayer, BGBG..(odd line), GRGR..(even line), 16-bit samples, little-endian */
        AV_PIX_FMT_BAYER_BGGR16BE, #< bayer, BGBG..(odd line), GRGR..(even line), 16-bit samples, big-endian */
        AV_PIX_FMT_BAYER_RGGB16LE, #< bayer, RGRG..(odd line), GBGB..(even line), 16-bit samples, little-endian */
        AV_PIX_FMT_BAYER_RGGB16BE, #< bayer, RGRG..(odd line), GBGB..(even line), 16-bit samples, big-endian */
        AV_PIX_FMT_BAYER_GBRG16LE, #< bayer, GBGB..(odd line), RGRG..(even line), 16-bit samples, little-endian */
        AV_PIX_FMT_BAYER_GBRG16BE, #< bayer, GBGB..(odd line), RGRG..(even line), 16-bit samples, big-endian */
        AV_PIX_FMT_BAYER_GRBG16LE, #< bayer, GRGR..(odd line), BGBG..(even line), 16-bit samples, little-endian */
        AV_PIX_FMT_BAYER_GRBG16BE, #< bayer, GRGR..(odd line), BGBG..(even line), 16-bit samples, big-endian */
        AV_PIX_FMT_XVMC,#< XVideo Motion Acceleration via common packet passing
        AV_PIX_FMT_NB,        #< number of pixel formats, DO NOT USE THIS if you want to link with shared libav* because the number of formats might differ between versions


    # ok libavutil/pixfmt.h     54. 20.100 
    enum AVColorPrimaries:
        AVCOL_PRI_BT709       = 1    #< also ITU-R BT1361 / IEC 61966-2-4 / SMPTE RP177 Annex B
        AVCOL_PRI_UNSPECIFIED = 2
        AVCOL_PRI_BT470M      = 4
        AVCOL_PRI_BT470BG     = 5    #< also ITU-R BT601-6 625 / ITU-R BT1358 625 / ITU-R BT1700 625 PAL & SECAM
        AVCOL_PRI_SMPTE170M   = 6    #< also ITU-R BT601-6 525 / ITU-R BT1358 525 / ITU-R BT1700 NTSC
        AVCOL_PRI_SMPTE240M   = 7    #< functionally identical to above
        AVCOL_PRI_FILM        = 8
        AVCOL_PRI_BT2020      = 9    #< ITU-R BT2020
        AVCOL_PRI_NB          = 10   #< Not part of ABI
      
      
    # ok libavutil/pixfmt.h   54. 20.100      
    enum AVColorTransferCharacteristic:
        AVCOL_TRC_RESERVED0    = 0
        AVCOL_TRC_BT709        = 1      #< also ITU-R BT1361
        AVCOL_TRC_UNSPECIFIED  = 2
        AVCOL_TRC_RESERVED     = 3
        AVCOL_TRC_GAMMA22      = 4      #< also ITU-R BT470M / ITU-R BT1700 625 PAL & SECAM
        AVCOL_TRC_GAMMA28      = 5      #< also ITU-R BT470BG
        AVCOL_TRC_SMPTE170M    = 6      #< also ITU-R BT601-6 525 or 625 / ITU-R BT1358 525 or 625 / ITU-R BT1700 NTSC
        AVCOL_TRC_SMPTE240M    = 7
        AVCOL_TRC_LINEAR       = 8      #< "Linear transfer characteristics"
        AVCOL_TRC_LOG          = 9      #< "Logarithmic transfer characteristic (100:1 range)"
        AVCOL_TRC_LOG_SQRT     = 10     #< "Logarithmic transfer characteristic (100 * Sqrt(10) : 1 range)"
        AVCOL_TRC_IEC61966_2_4 = 11     #< IEC 61966-2-4
        AVCOL_TRC_BT1361_ECG   = 12     #< ITU-R BT1361 Extended Colour Gamut
        AVCOL_TRC_IEC61966_2_1 = 13     #< IEC 61966-2-1 (sRGB or sYCC)
        AVCOL_TRC_BT2020_10    = 14     #< ITU-R BT2020 for 10 bit system
        AVCOL_TRC_BT2020_12    = 15     #< ITU-R BT2020 for 12 bit system
        AVCOL_TRC_NB           = 16     #< Not part of ABI


    # ok libavutil/pixfmt.h   54. 20.100
    enum AVColorSpace:
        AVCOL_SPC_RGB         = 0    #< order of coefficients is actually GBR, also IEC 61966-2-1 (sRGB)
        AVCOL_SPC_BT709       = 1    #< also ITU-R BT1361 / IEC 61966-2-4 xvYCC709 / SMPTE RP177 Annex B
        AVCOL_SPC_UNSPECIFIED = 2
        AVCOL_SPC_RESERVED    = 3
        AVCOL_SPC_FCC         = 4    #< FCC Title 47 Code of Federal Regulations 73.682 (a)(20)
        AVCOL_SPC_BT470BG     = 5    #< also ITU-R BT601-6 625 / ITU-R BT1358 625 / ITU-R BT1700 625 PAL & SECAM / IEC 61966-2-4 xvYCC601
        AVCOL_SPC_SMPTE170M   = 6    #< also ITU-R BT601-6 525 / ITU-R BT1358 525 / ITU-R BT1700 NTSC / functionally identical to above
        AVCOL_SPC_SMPTE240M   = 7
        AVCOL_SPC_YCOCG       = 8    #< Used by Dirac / VC-2 and H.264 FRext, see ITU-T SG16
        AVCOL_SPC_BT2020_NCL  = 9    #< ITU-R BT2020 non-constant luminance system
        AVCOL_SPC_BT2020_CL   = 10   #< ITU-R BT2020 constant luminance system
        AVCOL_SPC_NB          = 11   #< Not part of ABI


    # ok libavutil/pixfmt.h   54. 20.100
    enum AVColorRange:
        AVCOL_RANGE_UNSPECIFIED = 0
        AVCOL_RANGE_MPEG        = 1  #< the normal 219*2^(n-8) "MPEG" YUV ranges
        AVCOL_RANGE_JPEG        = 2  #< the normal     2^n-1   "JPEG" YUV ranges
        AVCOL_RANGE_NB          = 3  #< Not part of ABI


    # ok libavutil/pixfmt.h   54. 20.100
    enum AVChromaLocation:
        AVCHROMA_LOC_UNSPECIFIED = 0
        AVCHROMA_LOC_LEFT        = 1    #< mpeg2/4, h264 default
        AVCHROMA_LOC_CENTER      = 2    #< mpeg1, jpeg, h263
        AVCHROMA_LOC_TOPLEFT     = 3    #< DV
        AVCHROMA_LOC_TOP         = 4
        AVCHROMA_LOC_BOTTOMLEFT  = 5
        AVCHROMA_LOC_BOTTOM      = 6
        AVCHROMA_LOC_NB          = 7    #< Not part of ABI


##################################################################################
# ok libavutil    54. 20.100
cdef extern from "libavutil/avutil.h":
    # from avutil.h
    enum AVMediaType:
        AVMEDIA_TYPE_UNKNOWN = -1,
        AVMEDIA_TYPE_VIDEO,
        AVMEDIA_TYPE_AUDIO,
        AVMEDIA_TYPE_DATA,
        AVMEDIA_TYPE_SUBTITLE,
        AVMEDIA_TYPE_ATTACHMENT,
        AVMEDIA_TYPE_NB

    # ok libavutil/avutil.h     54. 20.100 
    enum AVPictureType:
        AV_PICTURE_TYPE_NONE= 0, #< Undefined
        AV_PICTURE_TYPE_BI,    #< Intra
        AV_PICTURE_TYPE_P,     #< Predicted
        AV_PICTURE_TYPE_B,     #< Bi-dir predicted
        AV_PICTURE_TYPE_S,     #< S(GMC)-VOP MPEG4
        AV_PICTURE_TYPE_SI,    #< Switching Intra
        AV_PICTURE_TYPE_SP,    #< Switching Predicted
        AV_PICTURE_TYPE_BI,    #< BI type        

    # unnamed enum for defines
    enum:        
        AV_NOPTS_VALUE = <int64_t>0x8000000000000000
        AV_TIME_BASE = 1000000

    # this is defined below as variable
    # AV_TIME_BASE_Q          (AVRational){1, AV_TIME_BASE}


##################################################################################
# ok libavutil    54. 20.100
cdef extern from "libavutil/samplefmt.h":
    enum AVSampleFormat:
        AV_SAMPLE_FMT_NONE = -1,
        AV_SAMPLE_FMT_U8,          #< unsigned 8 bits
        AV_SAMPLE_FMT_S16,         #< signed 16 bits
        AV_SAMPLE_FMT_S32,         #< signed 32 bits
        AV_SAMPLE_FMT_FLT,         #< float
        AV_SAMPLE_FMT_DBL,         #< double

        AV_SAMPLE_FMT_U8P,         #< unsigned 8 bits, planar
        AV_SAMPLE_FMT_S16P,        #< signed 16 bits, planar
        AV_SAMPLE_FMT_S32P,        #< signed 32 bits, planar
        AV_SAMPLE_FMT_FLTP,        #< float, planar
        AV_SAMPLE_FMT_DBLP,        #< double, planar

        AV_SAMPLE_FMT_NB           #< Number of sample formats. DO NOT USE if linking dynamically


##################################################################################
# ok libavformat  56. 25.101
cdef extern from "libavformat/avio.h":
    
    struct AVIOInterruptCB:
        pass
    
    struct AVIOContext:
        AVClass *av_class
        unsigned char *buffer  
        int buffer_size
        unsigned char *buf_ptr
        unsigned char *buf_end
        void *opaque
        int *read_packet
        int *write_packet
        int64_t *seek
        int64_t pos
        int must_flush
        int eof_reached
        int write_flag
        int max_packet_size
        unsigned long checksum
        unsigned char *checksum_ptr
        unsigned long *update_checksum
        int error
        int *read_pause
        int64_t *read_seek
        int seekable
        int64_t maxsize
        int direct
        int64_t bytes_read
        int seek_count
        int writeout_count
        int orig_buffer_size

    #int url_setbufsize(AVIOContext *s, int buf_size)
    #int url_ferror(AVIOContext *s)

    int avio_open(AVIOContext **s, char *url, int flags)    
    int avio_close(AVIOContext *s)
    
    # Force flushing of buffered data
    void avio_flush(AVIOContext *s)

    int avio_read(AVIOContext *s, unsigned char *buf, int size)
    # fseek() equivalent for AVIOContext
    int64_t avio_seek(AVIOContext *s, int64_t offset, int whence) 
    # Seek to a given timestamp relative to some component stream.
    int64_t avio_seek_time(AVIOContext *s, int stream_index, int64_t timestamp, int flags)
    AVIOContext *avio_alloc_context(
                      unsigned char *buffer,
                      int buffer_size,
                      int write_flag,
                      void *opaque,
                      void *a,
                      void *b,
                      void *c)
    
    #struct ByteIOContext:
    #    pass
    #ctypedef long long int  offset_t

    #int get_buffer(ByteIOContext *s, unsigned char *buf, int size)
    # use avio_read(s, buf, size);
    
    #int url_ferror(ByteIOContext *s)
    # use int url_ferror(AVIOContext *s)

    #int url_feof(ByteIOContext *s)
    # use AVIOContext.eof_reached 
    
    #int url_fopen(ByteIOContext **s,  char *filename, int flags)
    # use avio_open(s, filename, flags);    
    
    #int url_setbufsize(ByteIOContext *s, int buf_size)
    #use int url_setbufsize(AVIOContext *s, int buf_size);

    #int url_fclose(ByteIOContext *s)
    # use avio_close(s)
    
    #long long int url_fseek(ByteIOContext *s, long long int offset, int whence)
    # use avio_seek(s, offset, whence);
    
    #    ByteIOContext *av_alloc_put_byte(
    #                  unsigned char *buffer,
    #                  int buffer_size,
    #                  int write_flag,
    #                  void *opaque,
    #                  void * a , void * b , void * c)
    #                  #int (*read_packet)(void *opaque, uint8_t *buf, int buf_size),
    #                  #int (*write_packet)(void *opaque, uint8_t *buf, int buf_size),
    #                  #offset_t (*seek)(void *opaque, offset_t offset, int whence))
    # use avio_alloc_context(buffer, buffer_size, write_flag, opaque,
    #                           read_packet, write_packet, seek);               
    
##################################################################################
# ok libavutil    54. 20.100
cdef extern from "libavutil/frame.h":

    enum:
        AV_NUM_DATA_POINTERS = 8

    enum AVFrameSideDataType:
        AV_FRAME_DATA_PANSCAN,              #< The data is the AVPanScan struct defined in libavcodec.
        AV_FRAME_DATA_A53_CC,               #< ATSC A53 Part 4 Closed Captions.
        AV_FRAME_DATA_STEREO3D,             #< Stereoscopic 3d metadata.
        AV_FRAME_DATA_MATRIXENCODING,       #< The data is the AVMatrixEncoding enum defined in libavutil/channel_layout.h.
        AV_FRAME_DATA_DOWNMIX_INFO,         #< Metadata relevant to a downmix procedure.
        AV_FRAME_DATA_REPLAYGAIN,           #< ReplayGain information in the form of the AVReplayGain struct.
        AV_FRAME_DATA_DISPLAYMATRIX,        #< This side data contains a 3x3 transformation matrix describing an affine transformation that needs to be applied to the frame for correct presentation.
        AV_FRAME_DATA_AFD,                  #< Active Format Description data consisting of a single byte as specified in ETSI TS 101 154 using AVActiveFormatDescription enum
        AV_FRAME_DATA_MOTION_VECTORS,       #< Motion vectors exported by some codecs (on demand through the export_mvs flag set in the libavcodec AVCodecContext flags2 option). The data is the AVMotionVector struct defined in libavutil/motion_vector.h
        AV_FRAME_DATA_SKIP_SAMPLES,         #< Recommmends skipping the specified number of samples
        AV_FRAME_DATA_AUDIO_SERVICE_TYPE    #< his side data must be associated with an audio frame and corresponds to enum AVAudioServiceType defined in avcodec.h.

    enum AVActiveFormatDescription:
        AV_AFD_SAME         = 8
        AV_AFD_4_3          = 9
        AV_AFD_16_9         = 10
        AV_AFD_14_9         = 11
        AV_AFD_4_3_SP_14_9  = 13
        AV_AFD_16_9_SP_14_9 = 14
        AV_AFD_SP_4_3       = 15

    struct AVFrameSideData:
        AVFrameSideDataType type
        uint8_t *data
        int size
        AVDictionary *metadata

    struct AVFrame:
        uint8_t *data[AV_NUM_DATA_POINTERS]  #< pointer to the picture planes
        int linesize[AV_NUM_DATA_POINTERS]   #< For video, size in bytes of each picture line.
        uint8_t **extended_data              #< pointers to the data planes/channels.
        int width                            #< width of the video frame
        int height                           #< height of the video frame
        int nb_samples                       #< number of audio samples (per channel) described by this frame
        int format                           #< format of the frame, -1 if unknown or unset, Values correspond to enum AVPixelFormat for video frames, enum AVSampleFormat for audio)
        int key_frame                        #< 1 -> keyframe, 0-> not
        AVPictureType pict_type              #< AVPicture type of the frame, see ?_TYPE below

        # BEGIN deprecated, will be removed in major 55
        #uint8_t *base[AV_NUM_DATA_POINTERS]  #< deprecated, will be removed in major 55
        # END deprecated, will be removed in major 55

        AVRational sample_aspect_ratio       #< Sample aspect ratio for the video frame
        int64_t pts                          #< presentation timestamp in time_base units (time when frame should be shown to user)
        int64_t pkt_pts                      #< PTS copied from the AVPacket that was decoded to produce this frame
        int64_t pkt_dts                      #< DTS copied from the AVPacket that triggered returning this frame
        int coded_picture_number             #< picture number in bitstream order
        int display_picture_number           #< picture number in display order
        int quality                          #< quality (between 1 (good) and FF_LAMBDA_MAX (bad))
        
        # BEGIN deprecated, will be removed in major 55
        int reference                        #< is this picture used as reference
        int qscale_table                     #< QP table
        int qstride                          #< QP store stride
        int qscale_type
        uint8_t *mbskip_table                #< mbskip_table[mb]>=1 if MB didn't change, stride= mb_width = (width+15)>>4
        int16_t (*motion_val[2])[2]          #< motion vector table
        uint32_t *mb_type                    #< macroblock type table: mb_type_base + mb_width + 2
        short *dct_coeff                     #< DCT coefficients
        int8_t *ref_index[2]                 #< motion reference frame index
        # END deprecated, will be removed in major 55

        void *opaque                         #< for some private data of the user
        uint64_t error[AV_NUM_DATA_POINTERS] #< unused for decodig

        # BEGIN deprecated, will be removed in major 55
        int type                             #< type of the buffer (to keep track of who has to deallocate data[*]
        # END deprecated, will be removed in major 55

        int repeat_pict                      #<  When decoding, this signals how much the picture must be delayed: extra_delay = repeat_pict / (2*fps)
        int interlaced_frame                 #< The content of the picture is interlaced
        int top_field_first                  #< If the content is interlaced, is top field displayed first
        int palette_has_changed              #< Tell user application that palette has changed from previous frame

        # BEGIN deprecated, will be removed in major 55
        int buffer_hints                     #< 
        AVPanScan *pan_scan                  #< Pan scan
        # END deprecated, will be removed in major 55

        # reordered opaque 64bit (generally an integer or a double precision float
        # PTS but can be anything). 
        # The user sets AVCodecContext.reordered_opaque to represent the input at
        # that time, the decoder reorders values as needed and sets AVFrame.reordered_opaque
        # to exactly one of the values provided by the user through AVCodecContext.reordered_opaque
        # @deprecated in favor of pkt_pts        
        int64_t reordered_opaque

        # BEGIN deprecated, will be removed in major 55
        void *hwaccel_picture_private        #< hardware accelerator private data
        AVCodecContext *owner                #< the AVCodecContext which ff_thread_get_buffer() was last called on
        void *thread_opaque                  #< used by multithreading to store frame-specific info
        uint8_t motion_subsample_log2        #< log2 of the size of the block which a single vector in motion_val represents: (4->16x16, 3->8x8, 2-> 4x4, 1-> 2x2)
        # END deprecated, will be removed in major 55

        int sample_rate                      #< Sample rate of the audio data
        uint64_t channel_layout              #< Channel layout of the audio data
        AVBufferRef *buf[AV_NUM_DATA_POINTERS] #< AVBuffer references backing the data for this frame
        AVBufferRef **extended_buf           #< For planar audio which requires more than AV_NUM_DATA_POINTERS
        int nb_extended_buf                  #< Number of elements in extended_buf
        AVFrameSideData **side_data
        int nb_side_data

        int flags                            #< Frame flags, a combination of @ref lavu_frame_flags

        AVColorRange color_range             #< MPEG vs JPEG YUV range
        AVColorPrimaries color_primaries 
        AVColorTransferCharacteristic color_trc

        AVColorSpace colorspace              #< YUV colorspace type
        AVChromaLocation chroma_location

        int64_t best_effort_timestamp        #< frame timestamp estimated using various heuristics
        int64_t pkt_pos                      #< reordered pos from the last AVPacket that has been input into the decoder
        int64_t pkt_duration                 #< duration of the corresponding packet, in AVStream->time_base units
        AVDictionary *metadata

        int decode_error_flags               #< decode error flags of the frame, set to a combination of FF_DECODE_ERROR_xxx flags if the decoder produced a frame, but there were errors during the decoding.

        int channels                         #< number of audio channels, only used for audio
        int pkt_size                         #< size of the corresponding packet containing the compressed frame

        AVBufferRef *qp_table_buf            #< Not to be accessed directly from outside libavutil

    
##################################################################################
# ok libavcodec   56. 26.100
cdef extern from "libavcodec/avcodec.h":
    
    ctypedef struct AVCodecDefault
    ctypedef struct AVCodecInternal
    
    enum AVFieldOrder:
        AV_FIELD_UNKNOWN,
        AV_FIELD_PROGRESSIVE,
        AV_FIELD_TT,          #< Top coded_first, top displayed first
        AV_FIELD_BB,          #< Bottom coded first, bottom displayed first
        AV_FIELD_TB,          #< Top coded first, bottom displayed first
        AV_FIELD_BT,          #< Bottom coded first, top displayed first
    
    # use an unamed enum for defines
    enum:
        CODEC_FLAG_QSCALE               = 0x0002  #< Use fixed qscale.
        CODEC_FLAG_4MV                  = 0x0004  #< 4 MV per MB allowed / advanced prediction for H.263.
        CODEC_FLAG_QPEL                 = 0x0010  #< Use qpel MC.
        CODEC_FLAG_GMC                  = 0x0020  #< Use GMC.
        CODEC_FLAG_MV0                  = 0x0040  #< Always try a MB with MV=<0,0>.
        CODEC_FLAG_PART                 = 0x0080  #< Use data partitioning.
        # * The parent program guarantees that the input for B-frames containing
        # * streams is not written to for at least s->max_b_frames+1 frames, if
        # * this is not set the input will be copied.
        CODEC_FLAG_INPUT_PRESERVED      = 0x0100
        CODEC_FLAG_PASS1                = 0x0200   #< Use internal 2pass ratecontrol in first pass mode.
        CODEC_FLAG_PASS2                = 0x0400   #< Use internal 2pass ratecontrol in second pass mode.
        #CODEC_FLAG_EXTERN_HUFF          = 0x1000   #< Use external Huffman table (for MJPEG).
        CODEC_FLAG_GRAY                 = 0x2000   #< Only decode/encode grayscale.
        CODEC_FLAG_EMU_EDGE             = 0x4000   #< Don't draw edges.
        CODEC_FLAG_PSNR                 = 0x8000   #< error[?] variables will be set during encoding.
        CODEC_FLAG_TRUNCATED            = 0x00010000 #< Input bitstream might be truncated at a random location instead of only at frame boundaries.
        CODEC_FLAG_NORMALIZE_AQP        = 0x00020000 #< Normalize adaptive quantization.
        CODEC_FLAG_INTERLACED_DCT       = 0x00040000 #< Use interlaced DCT.
        CODEC_FLAG_LOW_DELAY            = 0x00080000 #< Force low delay.
        CODEC_FLAG_ALT_SCAN             = 0x00100000 #< Use alternate scan.
        CODEC_FLAG_GLOBAL_HEADER        = 0x00400000 #< Place global headers in extradata instead of every keyframe.
        CODEC_FLAG_BITEXACT             = 0x00800000 #< Use only bitexact stuff (except (I)DCT).
        # Fx : Flag for h263+ extra options 
        CODEC_FLAG_AC_PRED              = 0x01000000 #< H.263 advanced intra coding / MPEG-4 AC prediction
        #CODEC_FLAG_H263P_UMV            = 0x02000000 #< unlimited motion vector
        CODEC_FLAG_LOOP_FILTER          = 0x00000800 #< loop filter
        CODEC_FLAG_INTERLACED_ME        = 0x20000000 #< interlaced motion estimation
        CODEC_FLAG_CLOSED_GOP           = 0x80000000
        CODEC_FLAG2_FAST                = 0x00000001 #< Allow non spec compliant speedup tricks.
        CODEC_FLAG2_NO_OUTPUT           = 0x00000004 #< Skip bitstream encoding.
        CODEC_FLAG2_LOCAL_HEADER        = 0x00000008 #< Place global headers at every keyframe instead of in extradata.
        CODEC_FLAG2_DROP_FRAME_TIMECODE = 0x00002000 #< timecode is in drop frame format. DEPRECATED!!!!
        CODEC_FLAG2_IGNORE_CROP         = 0x00010000 #< Discard cropping information from SPS.
        CODEC_FLAG2_CHUNKS              = 0x00008000 #< Input bitstream might be truncated at a packet boundaries instead of only at frame boundaries.
        CODEC_FLAG2_SHOW_ALL            = 0x00400000 #< Show all frames before the first keyframe
        CODEC_FLAG2_EXPORT_MVS          = 0x10000000 #< Export motion vectors through frame side data
        CODEC_FLAG2_SKIP_MANUAL         = 0x20000000 #< Do not skip samples and export skip information as frame side data

        # codec capabilities
        CODEC_CAP_DRAW_HORIZ_BAND       = 0x0001 #< Decoder can use draw_horiz_band callback.
        CODEC_CAP_DR1                   = 0x0002 
        #CODEC_CAP_PARSE_ONLY            = 0x0004
        CODEC_CAP_TRUNCATED             = 0x0008
        CODEC_CAP_HWACCEL               = 0x0010
        CODEC_CAP_DELAY                 = 0x0020
        CODEC_CAP_SMALL_LAST_FRAME      = 0x0040
        CODEC_CAP_HWACCEL_VDPAU         = 0x0080
        CODEC_CAP_SUBFRAMES             = 0x0100
        CODEC_CAP_EXPERIMENTAL          = 0x0200
        CODEC_CAP_CHANNEL_CONF          = 0x0400
        CODEC_CAP_NEG_LINESIZES         = 0x0800
        CODEC_CAP_FRAME_THREADS         = 0x1000
        CODEC_CAP_SLICE_THREADS         = 0x2000
        CODEC_CAP_PARAM_CHANGE          = 0x4000
        CODEC_CAP_AUTO_THREADS          = 0x8000
        CODEC_CAP_VARIABLE_FRAME_SIZE   = 0x10000
        CODEC_CAP_INTRA_ONLY            = 0x40000000
        CODEC_CAP_LOSSLESS              = 0x80000000

        # AVFrame pict_type values DEPRECATED use AVPictureType AV_PICTURE_TYPE_*
        FF_I_TYPE            = 1         #< Intra
        FF_P_TYPE            = 2         #< Predicted
        FF_B_TYPE            = 3         #< Bi-dir predicted
        FF_S_TYPE            = 4         #< S(GMC)-VOP MPEG4
        FF_SI_TYPE           = 5         #< Switching Intra
        FF_SP_TYPE           = 6         #< Switching Predicte
        FF_BI_TYPE           = 7

        # AVFrame mb_type values
        #The following defines may change, don't expect compatibility if you use them.
        #Note bits 24-31 are reserved for codec specific use (h264 ref0, mpeg1 0mv, ...)
        MB_TYPE_INTRA4x4   = 0x0001
        MB_TYPE_INTRA16x16 = 0x0002 #FIXME H.264-specific
        MB_TYPE_INTRA_PCM  = 0x0004 #FIXME H.264-specific
        MB_TYPE_16x16      = 0x0008
        MB_TYPE_16x8       = 0x0010
        MB_TYPE_8x16       = 0x0020
        MB_TYPE_8x8        = 0x0040
        MB_TYPE_INTERLACED = 0x0080
        MB_TYPE_DIRECT2    = 0x0100 #FIXME
        MB_TYPE_ACPRED     = 0x0200
        MB_TYPE_GMC        = 0x0400
        MB_TYPE_SKIP       = 0x0800
        MB_TYPE_P0L0       = 0x1000
        MB_TYPE_P1L0       = 0x2000
        MB_TYPE_P0L1       = 0x4000
        MB_TYPE_P1L1       = 0x8000
        MB_TYPE_L0         = (MB_TYPE_P0L0 | MB_TYPE_P1L0)
        MB_TYPE_L1         = (MB_TYPE_P0L1 | MB_TYPE_P1L1)
        MB_TYPE_L0L1       = (MB_TYPE_L0   | MB_TYPE_L1)
        MB_TYPE_QUANT      = 0x00010000
        MB_TYPE_CBP        = 0x00020000
        
        # AVCodecContext compression_level
        FF_COMPRESSION_DEFAULT = -1

        # AVCodecContext
        FF_ASPECT_EXTENDED = 15

        # AVCodecContext
        FF_RC_STRATEGY_XVID = 1

        # AVCodecContext prediction_method values
        FF_PRED_LEFT   = 0
        FF_PRED_PLANE  = 1
        FF_PRED_MEDIAN = 2

        # AVCodecContext ildct_cmp values
        FF_CMP_SAD     = 0
        FF_CMP_SSE     = 1
        FF_CMP_SATD    = 2
        FF_CMP_DCT     = 3
        FF_CMP_PSNR    = 4
        FF_CMP_BIT     = 5
        FF_CMP_RD      = 6
        FF_CMP_ZERO    = 7
        FF_CMP_VSAD    = 8
        FF_CMP_VSSE    = 9
        FF_CMP_NSSE    = 10
        FF_CMP_W53     = 11
        FF_CMP_W97     = 12
        FF_CMP_DCTMAX  = 13
        FF_CMP_DCT264  = 14
        FF_CMP_CHROMA  = 256        

        # AVCodecContext dtg_active_format values
        FF_DTG_AFD_SAME         = 8
        FF_DTG_AFD_4_3          = 9
        FF_DTG_AFD_16_9         =10
        FF_DTG_AFD_14_9         =11
        FF_DTG_AFD_4_3_SP_14_9  =13
        FF_DTG_AFD_16_9_SP_14_9 =14
        FF_DTG_AFD_SP_4_3       =15

        # AVCodecContext intra_quant_bias values
        FF_DEFAULT_QUANT_BIAS = 999999

        # AVCodecContext slice_flags values
        SLICE_FLAG_CODED_ORDER= 0x0001  #< draw_horiz_band() is called in coded order instead of display
        SLICE_FLAG_ALLOW_FIELD= 0x0002  #< allow draw_horiz_band() with field slices (MPEG2 field pics)
        SLICE_FLAG_ALLOW_PLANE= 0x0004  #< allow draw_horiz_band() with 1 component at a time (SVQ1)

        # AVCodecContext mb_decision values
        FF_MB_DECISION_SIMPLE = 0   #< uses mb_cmp
        FF_MB_DECISION_BITS   = 1   #< chooses the one which needs the fewest bits
        FF_MB_DECISION_RD     = 2   #< rate distortion

        # AVCodecContext coder_type values
        FF_CODER_TYPE_VLC     = 0
        FF_CODER_TYPE_AC      = 1
        FF_CODER_TYPE_RAW     = 2
        FF_CODER_TYPE_RLE     = 3
        FF_CODER_TYPE_DEFLATE = 4

        # AVCodecContext workaround_bugs values
        FF_BUG_AUTODETECT       = 1  #< autodetection
        FF_BUG_OLD_MSMPEG4      = 2
        FF_BUG_XVID_ILACE       = 4
        FF_BUG_UMP4             = 8
        FF_BUG_NO_PADDING       = 16
        FF_BUG_AMV              = 32
        FF_BUG_AC_VLC           = 0  #< Will be removed, libavcodec can now handle these non-compliant files by default.
        FF_BUG_QPEL_CHROMA      = 64
        FF_BUG_STD_QPEL         = 128
        FF_BUG_QPEL_CHROMA2     = 256
        FF_BUG_DIRECT_BLOCKSIZE = 512
        FF_BUG_EDGE             = 1024
        FF_BUG_HPEL_CHROMA      = 2048
        FF_BUG_DC_CLIP          = 4096
        FF_BUG_MS               = 8192 #< Work around various bugs in Microsoft's broken decoders.
        FF_BUG_TRUNCATED        =16384

        # AVCodecContext strict_std_compliance values
        FF_COMPLIANCE_VERY_STRICT  =  2 #< Strictly conform to an older more strict version of the spec or reference software.
        FF_COMPLIANCE_STRICT       =  1 #< Strictly conform to all the things in the spec no matter what consequences.
        FF_COMPLIANCE_NORMAL       =  0
        FF_COMPLIANCE_UNOFFICIAL   = -1 #< Allow unofficial extensions
        FF_COMPLIANCE_EXPERIMENTAL = -2 #< Allow nonstandardized experimental things.

        # AVCodecContext error_concealment values
        FF_EC_GUESS_MV      = 1
        FF_EC_DEBLOCK       = 2
        FF_EC_FAVOR_INTER   = 256
        
        # AVCodecContext debug values
        FF_DEBUG_PICT_INFO   = 1
        FF_DEBUG_RC          = 2
        FF_DEBUG_BITSTREAM   = 4
        FF_DEBUG_MB_TYPE     = 8
        FF_DEBUG_QP          = 16
        FF_DEBUG_MV          = 32
        FF_DEBUG_DCT_COEFF   = 0x00000040
        FF_DEBUG_SKIP        = 0x00000080
        FF_DEBUG_STARTCODE   = 0x00000100
        FF_DEBUG_PTS         = 0x00000200
        FF_DEBUG_ER          = 0x00000400
        FF_DEBUG_MMCO        = 0x00000800
        FF_DEBUG_BUGS        = 0x00001000
        FF_DEBUG_VIS_QP      = 0x00002000 #< only access through AVOptions from outside libavcodec
        FF_DEBUG_VIS_MB_TYPE = 0x00004000 #< only access through AVOptions from outside libavcodec
        FF_DEBUG_BUFFERS     = 0x00008000
        FF_DEBUG_THREADS     = 0x00010000
        FF_DEBUG_NOMC        = 0x01000000
        
        # AVCodecContext debug_mv values
        FF_DEBUG_VIS_MV_P_FOR  = 0x00000001 #< visualize forward predicted MVs of P frames
        FF_DEBUG_VIS_MV_B_FOR  = 0x00000002 #< visualize forward predicted MVs of B frames
        FF_DEBUG_VIS_MV_B_BACK = 0x00000004 #< visualize backward predicted MVs of B frames
        
        # AVCodecContex err_recognition values
        AV_EF_CRCCHECK   =(1<<0)
        AV_EF_BITSTREAM  =(1<<1)         #< detect bitstream specification deviations
        AV_EF_BUFFER     =(1<<2)         #< detect improper bitstream length
        AV_EF_EXPLODE    =(1<<3)         #< abort decoding on minor error detection
        AV_EF_IGNORE_ERR =(1<<15)        #< ignore errors and continue
        AV_EF_CAREFUL    =(1<<16)        #< consider things that violate the spec, are fast to calculate and have not been seen in the wild as errors
        AV_EF_COMPLIANT  =(1<<17)        #< consider all spec non compliances as errors
        AV_EF_AGGRESSIVE =(1<<18)        #< consider things that a sane encoder should not do as an error

        # AVCodecContex dct_algo values
        FF_DCT_AUTO    = 0
        FF_DCT_FASTINT = 1
        FF_DCT_INT     = 2
        FF_DCT_MMX     = 3
        FF_DCT_ALTIVEC = 5
        FF_DCT_FAAN    = 6

        # AVCodecContex idct_algo values
        FF_IDCT_AUTO          = 0
        FF_IDCT_INT           = 1
        FF_IDCT_SIMPLE        = 2
        FF_IDCT_SIMPLEMMX     = 3
        FF_IDCT_ARM           = 7
        FF_IDCT_ALTIVEC       = 8
        FF_IDCT_SH4           = 9
        FF_IDCT_SIMPLEARM     = 10
        FF_IDCT_IPP           = 13
        FF_IDCT_XVID          = 14
        FF_IDCT_XVIDMMX       = 14
        FF_IDCT_SIMPLEARMV5TE = 16
        FF_IDCT_SIMPLEARMV6   = 17
        FF_IDCT_SIMPLEVIS     = 18
        FF_IDCT_FAAN          = 20
        FF_IDCT_SIMPLENEON    = 22
        FF_IDCT_SIMPLEALPHA   = 23
        FF_IDCT_SIMPLEAUTO    = 128

        # AVCodecContex thread_type values
        FF_THREAD_FRAME  = 1 #< Decode more than one frame at once
        FF_THREAD_SLICE  = 2 #< Decode more than one part of a single frame at once

        # AVCodecContex profile values
        FF_PROFILE_UNKNOWN     = -99
        FF_PROFILE_RESERVED    = -100

        FF_PROFILE_AAC_MAIN= 0
        FF_PROFILE_AAC_LOW = 1
        FF_PROFILE_AAC_SSR = 2
        FF_PROFILE_AAC_LTP = 3
        FF_PROFILE_AAC_HE  = 4
        FF_PROFILE_AAC_HE_V2 =28
        FF_PROFILE_AAC_LD   =22
        FF_PROFILE_AAC_ELD  =38
        FF_PROFILE_MPEG2_AAC_LOW=128
        FF_PROFILE_MPEG2_AAC_HE =131

        FF_PROFILE_DTS         = 20
        FF_PROFILE_DTS_ES      = 30
        FF_PROFILE_DTS_96_24   = 40
        FF_PROFILE_DTS_HD_HRA  = 50
        FF_PROFILE_DTS_HD_MA   = 60

        FF_PROFILE_MPEG2_422    = 0
        FF_PROFILE_MPEG2_HIGH   = 1
        FF_PROFILE_MPEG2_SS     = 2
        FF_PROFILE_MPEG2_SNR_SCALABLE  = 3
        FF_PROFILE_MPEG2_MAIN   = 4
        FF_PROFILE_MPEG2_SIMPLE = 5

        FF_PROFILE_H264_CONSTRAINED = (1<<9)  # 8+1; constraint_set1_flag
        FF_PROFILE_H264_INTRA       = (1<<11) # 8+3; constraint_set3_flag

        FF_PROFILE_H264_BASELINE            = 66
        FF_PROFILE_H264_CONSTRAINED_BASELINE= (66|FF_PROFILE_H264_CONSTRAINED)
        FF_PROFILE_H264_MAIN                = 77
        FF_PROFILE_H264_EXTENDED            = 88
        FF_PROFILE_H264_HIGH                = 100
        FF_PROFILE_H264_HIGH_10             = 110
        FF_PROFILE_H264_HIGH_10_INTRA       = (110|FF_PROFILE_H264_INTRA)
        FF_PROFILE_H264_HIGH_422            = 122
        FF_PROFILE_H264_HIGH_422_INTRA      = (122|FF_PROFILE_H264_INTRA)
        FF_PROFILE_H264_HIGH_444            = 144
        FF_PROFILE_H264_HIGH_444_PREDICTIVE = 244
        FF_PROFILE_H264_HIGH_444_INTRA      = (244|FF_PROFILE_H264_INTRA)
        FF_PROFILE_H264_CAVLC_444           = 44

        FF_PROFILE_VC1_SIMPLE   = 0
        FF_PROFILE_VC1_MAIN     = 1
        FF_PROFILE_VC1_COMPLEX  = 2
        FF_PROFILE_VC1_ADVANCED = 3

        FF_PROFILE_MPEG4_SIMPLE                    =  0
        FF_PROFILE_MPEG4_SIMPLE_SCALABLE           =  1
        FF_PROFILE_MPEG4_CORE                      =  2
        FF_PROFILE_MPEG4_MAIN                      =  3
        FF_PROFILE_MPEG4_N_BIT                     =  4
        FF_PROFILE_MPEG4_SCALABLE_TEXTURE          =  5
        FF_PROFILE_MPEG4_SIMPLE_FACE_ANIMATION     =  6
        FF_PROFILE_MPEG4_BASIC_ANIMATED_TEXTURE    =  7
        FF_PROFILE_MPEG4_HYBRID                    =  8
        FF_PROFILE_MPEG4_ADVANCED_REAL_TIME        =  9
        FF_PROFILE_MPEG4_CORE_SCALABLE             = 10
        FF_PROFILE_MPEG4_ADVANCED_CODING           = 11
        FF_PROFILE_MPEG4_ADVANCED_CORE             = 12
        FF_PROFILE_MPEG4_ADVANCED_SCALABLE_TEXTURE = 13
        FF_PROFILE_MPEG4_SIMPLE_STUDIO             = 14
        FF_PROFILE_MPEG4_ADVANCED_SIMPLE           = 15

        FF_PROFILE_JPEG2000_CSTREAM_RESTRICTION_0  = 0
        FF_PROFILE_JPEG2000_CSTREAM_RESTRICTION_1  = 1
        FF_PROFILE_JPEG2000_CSTREAM_NO_RESTRICTION = 2
        FF_PROFILE_JPEG2000_DCINEMA_2K             = 3
        FF_PROFILE_JPEG2000_DCINEMA_4K             = 4

        FF_PROFILE_HEVC_MAIN                       = 1
        FF_PROFILE_HEVC_MAIN_10                    = 2
        FF_PROFILE_HEVC_MAIN_STILL_PICTURE         = 3
        FF_PROFILE_HEVC_REXT                       = 4

        FF_LEVEL_UNKNOWN       = -99

        # AVCodecContex sub_charenc_mode values
        FF_SUB_CHARENC_MODE_DO_NOTHING  = -1  #< do nothing (demuxer outputs a stream supposed to be already in UTF-8, or the codec is bitmap for instance)
        FF_SUB_CHARENC_MODE_AUTOMATIC   =  0  #< libavcodec will select the mode itself
        FF_SUB_CHARENC_MODE_PRE_DECODER =  1  #< the AVPacket data needs to be recoded to UTF-8 before being fed to the decoder, requires iconv

    # ok libavcodec/avcodec.h   56. 26.100
    struct AVCodecDescriptor:
        AVCodecID       id
        AVMediaType     type
        const_char      *name           # Name of the codec described by this descriptor, non-empty and unique for each descriptor
        const_char      *long_name      # A more descriptive name for this codec. May be NULL
        int             props           # Codec properties, a combination of AV_CODEC_PROP_* flags
        const_char      **mime_types    # MIME type(s) associated with the codec
        
    # ok libavcodec/avcodec.h   56. 26.100
    enum AVDiscard:
        AVDISCARD_NONE   = -16 # discard nothing
        AVDISCARD_DEFAULT=   0 # discard useless packets like 0 size packets in avi
        AVDISCARD_NONREF =   8 # discard all non reference
        AVDISCARD_BIDIR  =  16 # discard all bidirectional frames
        AVDISCARD_NONINTRA= 24 # discard all non intra frames
        AVDISCARD_NONKEY =  32 # discard all frames except keyframes
        AVDISCARD_ALL    =  48 # discard all

    # ok libavcodec/avcodec.h   56. 26.100
    enum AVAudioServiceType:
        AV_AUDIO_SERVICE_TYPE_MAIN              = 0
        AV_AUDIO_SERVICE_TYPE_EFFECTS           = 1
        AV_AUDIO_SERVICE_TYPE_VISUALLY_IMPAIRED = 2
        AV_AUDIO_SERVICE_TYPE_HEARING_IMPAIRED  = 3
        AV_AUDIO_SERVICE_TYPE_DIALOGUE          = 4
        AV_AUDIO_SERVICE_TYPE_COMMENTARY        = 5
        AV_AUDIO_SERVICE_TYPE_EMERGENCY         = 6
        AV_AUDIO_SERVICE_TYPE_VOICE_OVER        = 7
        AV_AUDIO_SERVICE_TYPE_KARAOKE           = 8
        AV_AUDIO_SERVICE_TYPE_NB

    # ok libavcodec/avcodec.h   56. 26.100
    struct RcOverride:
        int start_frame
        int end_frame
        int qscale # If this is 0 then quality_factor will be used instead
        float quality_factor

    # ok libavcodec   56. 26.100
    enum AVCodecID:
        AV_CODEC_ID_NONE,
    
        # video codecs 
        AV_CODEC_ID_MPEG1VIDEO,
        AV_CODEC_ID_MPEG2VIDEO, #< preferred ID for MPEG-1/2 video decoding
        AV_CODEC_ID_MPEG2VIDEO_XVMC,
        AV_CODEC_ID_H261,
        AV_CODEC_ID_H263,
        AV_CODEC_ID_RV10,
        AV_CODEC_ID_RV20,
        AV_CODEC_ID_MJPEG,
        AV_CODEC_ID_MJPEGB,
        AV_CODEC_ID_LJPEG,
        AV_CODEC_ID_SP5X,
        AV_CODEC_ID_JPEGLS,
        AV_CODEC_ID_MPEG4,
        AV_CODEC_ID_RAWVIDEO,
        AV_CODEC_ID_MSMPEG4V1,
        AV_CODEC_ID_MSMPEG4V2,
        AV_CODEC_ID_MSMPEG4V3,
        AV_CODEC_ID_WMV1,
        AV_CODEC_ID_WMV2,
        AV_CODEC_ID_H263P,
        AV_CODEC_ID_H263I,
        AV_CODEC_ID_FLV1,
        AV_CODEC_ID_SVQ1,
        AV_CODEC_ID_SVQ3,
        AV_CODEC_ID_DVVIDEO,
        AV_CODEC_ID_HUFFYUV,
        AV_CODEC_ID_CYUV,
        AV_CODEC_ID_H264,
        AV_CODEC_ID_INDEO3,
        AV_CODEC_ID_VP3,
        AV_CODEC_ID_THEORA,
        AV_CODEC_ID_ASV1,
        AV_CODEC_ID_ASV2,
        AV_CODEC_ID_FFV1,
        AV_CODEC_ID_4XM,
        AV_CODEC_ID_VCR1,
        AV_CODEC_ID_CLJR,
        AV_CODEC_ID_MDEC,
        AV_CODEC_ID_ROQ,
        AV_CODEC_ID_INTERPLAY_VIDEO,
        AV_CODEC_ID_XAN_WC3,
        AV_CODEC_ID_XAN_WC4,
        AV_CODEC_ID_RPZA,
        AV_CODEC_ID_CINEPAK,
        AV_CODEC_ID_WS_VQA,
        AV_CODEC_ID_MSRLE,
        AV_CODEC_ID_MSVIDEO1,
        AV_CODEC_ID_IDCIN,
        AV_CODEC_ID_8BPS,
        AV_CODEC_ID_SMC,
        AV_CODEC_ID_FLIC,
        AV_CODEC_ID_TRUEMOTION1,
        AV_CODEC_ID_VMDVIDEO,
        AV_CODEC_ID_MSZH,
        AV_CODEC_ID_ZLIB,
        AV_CODEC_ID_QTRLE,
        AV_CODEC_ID_SNOW,
        AV_CODEC_ID_TSCC,
        AV_CODEC_ID_ULTI,
        AV_CODEC_ID_QDRAW,
        AV_CODEC_ID_VIXL,
        AV_CODEC_ID_QPEG,
        AV_CODEC_ID_XVID,        #< LIBAVCODEC_VERSION_MAJOR < 53
        AV_CODEC_ID_PNG,
        AV_CODEC_ID_PPM,
        AV_CODEC_ID_PBM,
        AV_CODEC_ID_PGM,
        AV_CODEC_ID_PGMYUV,
        AV_CODEC_ID_PAM,
        AV_CODEC_ID_FFVHUFF,
        AV_CODEC_ID_RV30,
        AV_CODEC_ID_RV40,
        AV_CODEC_ID_VC1,
        AV_CODEC_ID_WMV3,
        AV_CODEC_ID_LOCO,
        AV_CODEC_ID_WNV1,
        AV_CODEC_ID_AASC,
        AV_CODEC_ID_INDEO2,
        AV_CODEC_ID_FRAPS,
        AV_CODEC_ID_TRUEMOTION2,
        AV_CODEC_ID_BMP,
        AV_CODEC_ID_CSCD,
        AV_CODEC_ID_MMVIDEO,
        AV_CODEC_ID_ZMBV,
        AV_CODEC_ID_AVS,
        AV_CODEC_ID_SMACKVIDEO,
        AV_CODEC_ID_NUV,
        AV_CODEC_ID_KMVC,
        AV_CODEC_ID_FLASHSV,
        AV_CODEC_ID_CAVS,
        AV_CODEC_ID_JPEG2000,
        AV_CODEC_ID_VMNC,
        AV_CODEC_ID_VP5,
        AV_CODEC_ID_VP6,
        AV_CODEC_ID_VP6F,
        AV_CODEC_ID_TARGA,
        AV_CODEC_ID_DSICINVIDEO,
        AV_CODEC_ID_TIERTEXSEQVIDEO,
        AV_CODEC_ID_TIFF,
        AV_CODEC_ID_GIF,
        AV_CODEC_ID_FFH264,
        AV_CODEC_ID_DXA,
        AV_CODEC_ID_DNXHD,
        AV_CODEC_ID_THP,
        AV_CODEC_ID_SGI,
        AV_CODEC_ID_C93,
        AV_CODEC_ID_BETHSOFTVID,
        AV_CODEC_ID_PTX,
        AV_CODEC_ID_TXD,
        AV_CODEC_ID_VP6A,
        AV_CODEC_ID_AMV,
        AV_CODEC_ID_VB,
        AV_CODEC_ID_PCX,
        AV_CODEC_ID_SUNRAST,
        AV_CODEC_ID_INDEO4,
        AV_CODEC_ID_INDEO5,
        AV_CODEC_ID_MIMIC,
        AV_CODEC_ID_RL2,
        AV_CODEC_ID_8SVX_EXP,
        AV_CODEC_ID_8SVX_FIB,
        AV_CODEC_ID_ESCAPE124,
        AV_CODEC_ID_DIRAC,
        AV_CODEC_ID_BFI,
        AV_CODEC_ID_CMV,
        AV_CODEC_ID_MOTIONPIXELS,
        AV_CODEC_ID_TGV,
        AV_CODEC_ID_TGQ,
        AV_CODEC_ID_TQI,
        AV_CODEC_ID_AURA,
        AV_CODEC_ID_AURA2,
        AV_CODEC_ID_V210X,
        AV_CODEC_ID_TMV,
        AV_CODEC_ID_V210,
        AV_CODEC_ID_DPX,
        AV_CODEC_ID_MAD,
        AV_CODEC_ID_FRWU,
        AV_CODEC_ID_FLASHSV2,
        AV_CODEC_ID_CDGRAPHICS,
        AV_CODEC_ID_R210,
        AV_CODEC_ID_ANM,
        AV_CODEC_ID_BINKVIDEO,
        AV_CODEC_ID_IFF_ILBM,
        AV_CODEC_ID_IFF_BYTERUN1,
        AV_CODEC_ID_KGV1,
        AV_CODEC_ID_YOP,
        AV_CODEC_ID_VP8,
        AV_CODEC_ID_PICTOR,
        AV_CODEC_ID_ANSI,
        AV_CODEC_ID_A64_MULTI,
        AV_CODEC_ID_A64_MULTI5,
        AV_CODEC_ID_R10K,
        AV_CODEC_ID_MXPEG,
        AV_CODEC_ID_LAGARITH,
        AV_CODEC_ID_PRORES,
        AV_CODEC_ID_JV,
        AV_CODEC_ID_DFA,
        AV_CODEC_ID_WMV3IMAGE,
        AV_CODEC_ID_VC1IMAGE,
        AV_CODEC_ID_UTVIDEO,
        AV_CODEC_ID_BMV_VIDEO,
        AV_CODEC_ID_VBLE,
        AV_CODEC_ID_DXTORY,
        AV_CODEC_ID_V410,
        AV_CODEC_ID_XWD,
        AV_CODEC_ID_CDXL,
        AV_CODEC_ID_XBM,
        AV_CODEC_ID_ZEROCODEC,
        AV_CODEC_ID_MSS1,
        AV_CODEC_ID_MSA1,
        AV_CODEC_ID_TSCC2,
        AV_CODEC_ID_MTS2,
        AV_CODEC_ID_CLLC,
        AV_CODEC_ID_MSS2,
        AV_CODEC_ID_VP9,
        AV_CODEC_ID_AIC,
        AV_CODEC_ID_ESCAPE130_DEPRECATED,
        AV_CODEC_ID_G2M_DEPRECATED,
        AV_CODEC_ID_WEBP_DEPRECATED,
        AV_CODEC_ID_HNM4_VIDEO,
        AV_CODEC_ID_HEVC_DEPRECATED,
        AV_CODEC_ID_FIC,
        AV_CODEC_ID_ALIAS_PIX,
        AV_CODEC_ID_BRENDER_PIX_DEPRECATED,
        AV_CODEC_ID_PAF_VIDEO_DEPRECATED,
        AV_CODEC_ID_EXR_DEPRECATED,
        AV_CODEC_ID_VP7_DEPRECATED,
        AV_CODEC_ID_SANM_DEPRECATED,
        AV_CODEC_ID_SGIRLE_DEPRECATED,
        AV_CODEC_ID_MVC1_DEPRECATED,
        AV_CODEC_ID_MVC2_DEPRECATED,
        AV_CODEC_ID_HQX,
        
        AV_CODEC_ID_BRENDER_PIX = 0x42504958, # MKBETAG('B','P','I','X')
        AV_CODEC_ID_Y41P        = 0x59343150, # MKBETAG('Y','4','1','P')
        AV_CODEC_ID_ESCAPE130   = 0x45313330, # MKBETAG('E','1','3','0')
        AV_CODEC_ID_EXR         = 0x30455852, # MKBETAG('0','E','X','R')
        AV_CODEC_ID_AVRP        = 0x41565250, # MKBETAG('A','V','R','P')

        AV_CODEC_ID_012V        = 0x30313256, # MKBETAG('0','1','2','V')
        AV_CODEC_ID_G2M         = 0x47324d, # MKBETAG(0,'G','2','M')
        AV_CODEC_ID_AVUI        = 0x41565549, # MKBETAG('A','V','U','I')
        AV_CODEC_ID_AYUV        = 0x41595556, # MKBETAG('A','Y','U','V')
        AV_CODEC_ID_TARGA_Y216  = 0x54323136, # MKBETAG('T','2','1','6')
        AV_CODEC_ID_V308        = 0x56333038, # MKBETAG('V','3','0','8')
        AV_CODEC_ID_V408        = 0x56343038, # MKBETAG('V','4','0','8')
        AV_CODEC_ID_YUV4        = 0x59555634, # MKBETAG('Y','U','V','4')
        AV_CODEC_ID_SANM        = 0x53414e4d, # MKBETAG('S','A','N','M')
        AV_CODEC_ID_PAF_VIDEO   = 0x50414656, # MKBETAG('P','A','F','V')
        AV_CODEC_ID_AVRN        = 0x4156526e, # MKBETAG('A','V','R','n')
        AV_CODEC_ID_CPIA        = 0x43504941, # MKBETAG('C','P','I','A')
        AV_CODEC_ID_XFACE       = 0x58464143, # MKBETAG('X','F','A','C')
        AV_CODEC_ID_SGIRLE      = 0x53474952, # MKBETAG('S','G','I','R')
        AV_CODEC_ID_MVC1        = 0x4d564331, # MKBETAG('M','V','C','1')
        AV_CODEC_ID_MVC2        = 0x4d564332, # MKBETAG('M','V','C','2')
        AV_CODEC_ID_SNOW        = 0x534e4f57, # MKBETAG('S','N','O','W')
        AV_CODEC_ID_WEBP        = 0x57454250, # MKBETAG('W','E','B','P')
        AV_CODEC_ID_SMVJPEG     = 0x534d564a, # MKBETAG('S','M','V','J')
        AV_CODEC_ID_HEVC        = 0x48323635, # MKBETAG('H','2','6','5')
        AV_CODEC_ID_VP7         = 0x56503730, # MKBETAG('V','P','7','0')
        AV_CODEC_ID_APNG        = 0x41504e47, # MKBETAG('A','P','N','G')

        # various PCM "codecs" 
        AV_CODEC_ID_FIRST_AUDIO= 0x10000,     #< A dummy id pointing at the start of audio codecs
        AV_CODEC_ID_PCM_S16LE= 0x10000,
        AV_CODEC_ID_PCM_S16BE,
        AV_CODEC_ID_PCM_U16LE,
        AV_CODEC_ID_PCM_U16BE,
        AV_CODEC_ID_PCM_S8,
        AV_CODEC_ID_PCM_U8,
        AV_CODEC_ID_PCM_MULAW,
        AV_CODEC_ID_PCM_ALAW,
        AV_CODEC_ID_PCM_S32LE,
        AV_CODEC_ID_PCM_S32BE,
        AV_CODEC_ID_PCM_U32LE,
        AV_CODEC_ID_PCM_U32BE,
        AV_CODEC_ID_PCM_S24LE,
        AV_CODEC_ID_PCM_S24BE,
        AV_CODEC_ID_PCM_U24LE,
        AV_CODEC_ID_PCM_U24BE,
        AV_CODEC_ID_PCM_S24DAUD,
        AV_CODEC_ID_PCM_ZORK,
        AV_CODEC_ID_PCM_S16LE_PLANAR,
        AV_CODEC_ID_PCM_DVD,
        AV_CODEC_ID_PCM_F32BE,
        AV_CODEC_ID_PCM_F32LE,
        AV_CODEC_ID_PCM_F64BE,
        AV_CODEC_ID_PCM_F64LE,
        AV_CODEC_ID_PCM_BLURAY,
        AV_CODEC_ID_PCM_LXF,
        AV_CODEC_ID_S302M,
        AV_CODEC_ID_PCM_S8_PLANAR,
        AV_CODEC_ID_PCM_S24LE_PLANAR_DEPRECATED,
        AV_CODEC_ID_PCM_S32LE_PLANAR_DEPRECATED,
        AV_CODEC_ID_PCM_S24LE_PLANAR= 0x18505350, # MKBETAG(24,'P','S','P')
        AV_CODEC_ID_PCM_S32LE_PLANAR= 0x20505350, # MKBETAG(32,'P','S','P')
        AV_CODEC_ID_PCM_S16BE_PLANAR= 0x50535010, # MKBETAG('P','S','P',16)

        # various ADPCM codecs 
        AV_CODEC_ID_ADPCM_IMA_QT = 0x11000,
        AV_CODEC_ID_ADPCM_IMA_WAV,
        AV_CODEC_ID_ADPCM_IMA_DK3,
        AV_CODEC_ID_ADPCM_IMA_DK4,
        AV_CODEC_ID_ADPCM_IMA_WS,
        AV_CODEC_ID_ADPCM_IMA_SMJPEG,
        AV_CODEC_ID_ADPCM_MS,
        AV_CODEC_ID_ADPCM_4XM,
        AV_CODEC_ID_ADPCM_XA,
        AV_CODEC_ID_ADPCM_ADX,
        AV_CODEC_ID_ADPCM_EA,
        AV_CODEC_ID_ADPCM_G726,
        AV_CODEC_ID_ADPCM_CT,
        AV_CODEC_ID_ADPCM_SWF,
        AV_CODEC_ID_ADPCM_YAMAHA,
        AV_CODEC_ID_ADPCM_SBPRO_4,
        AV_CODEC_ID_ADPCM_SBPRO_3,
        AV_CODEC_ID_ADPCM_SBPRO_2,
        AV_CODEC_ID_ADPCM_THP,
        AV_CODEC_ID_ADPCM_IMA_AMV,
        AV_CODEC_ID_ADPCM_EA_R1,
        AV_CODEC_ID_ADPCM_EA_R3,
        AV_CODEC_ID_ADPCM_EA_R2,
        AV_CODEC_ID_ADPCM_IMA_EA_SEAD,
        AV_CODEC_ID_ADPCM_IMA_EA_EACS,
        AV_CODEC_ID_ADPCM_EA_XAS,
        AV_CODEC_ID_ADPCM_EA_MAXIS_XA,
        AV_CODEC_ID_ADPCM_IMA_ISS,
        AV_CODEC_ID_ADPCM_G722,
        AV_CODEC_ID_ADPCM_IMA_APC,
        AV_CODEC_ID_ADPCM_VIMA_DEPRECATED,

        AV_CODEC_ID_ADPCM_VIMA = 0x56494d41, # MKBETAG('V','I','M','A')
        AV_CODEC_ID_VIMA       = 0x56494d41, # MKBETAG('V','I','M','A')
        AV_CODEC_ID_ADPCM_AFC  = 0x41464320, # MKBETAG('A','F','C',' ')
        AV_CODEC_ID_ADPCM_IMA_OKI = 0x4f4b4920, # MKBETAG('O','K','I',' ')
        AV_CODEC_ID_ADPCM_DTK  = 0x44544b20, # MKBETAG('D','T','K',' ')
        AV_CODEC_ID_ADPCM_IMA_RAD = 0x52414420, # MKBETAG('R','A','D',' ')
        AV_CODEC_ID_ADPCM_G726LE = 0x36323747, # MKBETAG('6','2','7','G')
    
        # AMR 
        AV_CODEC_ID_AMR_NB= 0x12000,
        AV_CODEC_ID_AMR_WB,
     
        # RealAudio codecs
        AV_CODEC_ID_RA_144= 0x13000,
        AV_CODEC_ID_RA_288,
    
        # various DPCM codecs 
        AV_CODEC_ID_ROQ_DPCM= 0x14000,
        AV_CODEC_ID_INTERPLAY_DPCM,
        AV_CODEC_ID_XAN_DPCM,
        AV_CODEC_ID_SOL_DPCM,
    
        # audio codecs 
        AV_CODEC_ID_MP2 = 0x15000,
        AV_CODEC_ID_MP3, #< preferred ID for decoding MPEG audio layer 1, 2 or 3
        AV_CODEC_ID_AAC,
        AV_CODEC_ID_AC3,
        AV_CODEC_ID_DTS,
        AV_CODEC_ID_VORBIS,
        AV_CODEC_ID_DVAUDIO,
        AV_CODEC_ID_WMAV1,
        AV_CODEC_ID_WMAV2,
        AV_CODEC_ID_MACE3,
        AV_CODEC_ID_MACE6,
        AV_CODEC_ID_VMDAUDIO,
        AV_CODEC_ID_FLAC,
        AV_CODEC_ID_MP3ADU,
        AV_CODEC_ID_MP3ON4,
        AV_CODEC_ID_SHORTEN,
        AV_CODEC_ID_ALAC,
        AV_CODEC_ID_WESTWOOD_SND1,
        AV_CODEC_ID_GSM, #< as in Berlin toast format
        AV_CODEC_ID_QDM2,
        AV_CODEC_ID_COOK,
        AV_CODEC_ID_TRUESPEECH,
        AV_CODEC_ID_TTA,
        AV_CODEC_ID_SMACKAUDIO,
        AV_CODEC_ID_QCELP,
        AV_CODEC_ID_WAVPACK,
        AV_CODEC_ID_DSICINAUDIO,
        AV_CODEC_ID_IMC,
        AV_CODEC_ID_MUSEPACK7,
        AV_CODEC_ID_MLP,
        AV_CODEC_ID_GSM_MS, # as found in WAV 
        AV_CODEC_ID_ATRAC3,
        AV_CODEC_ID_VOXWARE,
        AV_CODEC_ID_APE,
        AV_CODEC_ID_NELLYMOSER,
        AV_CODEC_ID_MUSEPACK8,
        AV_CODEC_ID_SPEEX,
        AV_CODEC_ID_WMAVOICE,
        AV_CODEC_ID_WMAPRO,
        AV_CODEC_ID_WMALOSSLESS,
        AV_CODEC_ID_ATRAC3P,
        AV_CODEC_ID_EAC3,
        AV_CODEC_ID_SIPR,
        AV_CODEC_ID_MP1,
        AV_CODEC_ID_TWINVQ,
        AV_CODEC_ID_TRUEHD,
        AV_CODEC_ID_MP4ALS,
        AV_CODEC_ID_ATRAC1,
        AV_CODEC_ID_BINKAUDIO_RDFT,
        AV_CODEC_ID_BINKAUDIO_DCT,
        AV_CODEC_ID_AAC_LATM,
        AV_CODEC_ID_QDMC,
        AV_CODEC_ID_CELT,
        AV_CODEC_ID_G723_1,
        AV_CODEC_ID_G729,
        AV_CODEC_ID_8SVX_EXP,
        AV_CODEC_ID_8SVX_FIB,
        AV_CODEC_ID_BMV_AUDIO,
        AV_CODEC_ID_RALF,
        AV_CODEC_ID_IAC,
        AV_CODEC_ID_ILBC,
        AV_CODEC_ID_OPUS_DEPRECATED,
        AV_CODEC_ID_COMFORT_NOISE,
        AV_CODEC_ID_TAK_DEPRECATED,
        AV_CODEC_ID_METASOUND,
        AV_CODEC_ID_PAF_AUDIO_DEPRECATED,
        AV_CODEC_ID_ON2AVC,
        AV_CODEC_ID_DSS_SP,
        AV_CODEC_ID_FFWAVESYNTH = 0x46465753, # MKBETAG('F','F','W','S')
        AV_CODEC_ID_SONIC       = 0x534f4e43, # MKBETAG('S','O','N','C')
        AV_CODEC_ID_SONIC_LS    = 0x534f4e4c, # MKBETAG('S','O','N','L')
        AV_CODEC_ID_PAF_AUDIO   = 0x50414641, # MKBETAG('P','A','F','A')
        AV_CODEC_ID_OPUS        = 0x4f505553, # MKBETAG('O','P','U','S')
        AV_CODEC_ID_TAK         = 0x7442614b, # MKBETAG('t','B','a','K')
        AV_CODEC_ID_EVRC        = 0x73657663, # MKBETAG('s','e','v','c')
        AV_CODEC_ID_SMV         = 0x73736d76, # MKBETAG('s','s','m','v')
        AV_CODEC_ID_DSD_LSBF    = 0x4453444c, # MKBETAG('D','S','D','L')
        AV_CODEC_ID_DSD_MSBF    = 0x4453444d, # MKBETAG('D','S','D','M')
        AV_CODEC_ID_DSD_LSBF_PLANAR = 0x44534431, # MKBETAG('D','S','D','1')
        AV_CODEC_ID_DSD_MSBF_PLANAR = 0x44534438, # MKBETAG('D','S','D','8')
        
        # subtitle codecs
        AV_CODEC_ID_FIRST_SUBTITLE = 0x17000,          #< A dummy ID pointing at the start of subtitle codecs.
        AV_CODEC_ID_DVD_SUBTITLE = 0x17000,
        AV_CODEC_ID_DVB_SUBTITLE,
        AV_CODEC_ID_TEXT,  #< raw UTF-8 text
        AV_CODEC_ID_XSUB,
        AV_CODEC_ID_SSA,
        AV_CODEC_ID_MOV_TEXT,
        AV_CODEC_ID_HDMV_PGS_SUBTITLE,
        AV_CODEC_ID_DVB_TELETEXT,
        AV_CODEC_ID_SRT,
        AV_CODEC_ID_MICRODVD   = 0x6d445644, # MKBETAG('m','D','V','D')
        AV_CODEC_ID_EIA_608    = 0x63363038, # MKBETAG('c','6','0','8')
        AV_CODEC_ID_JACOSUB    = 0x4a535542, # MKBETAG('J','S','U','B')
        AV_CODEC_ID_SAMI       = 0x53414d49, # MKBETAG('S','A','M','I')
        AV_CODEC_ID_REALTEXT   = 0x52545854, # MKBETAG('R','T','X','T')
        AV_CODEC_ID_STL        = 0x5370544c, # MKBETAG('S','p','T','L')
        AV_CODEC_ID_SUBVIEWER1 = 0x53625631, # MKBETAG('S','b','V','1')
        AV_CODEC_ID_SUBVIEWER  = 0x53756256, # MKBETAG('S','u','b','V')
        AV_CODEC_ID_SUBRIP     = 0x53526970, # MKBETAG('S','R','i','p')
        AV_CODEC_ID_WEBVTT     = 0x57565454, # MKBETAG('W','V','T','T')
        AV_CODEC_ID_MPL2       = 0x4d504c32, # MKBETAG('M','P','L','2')
        AV_CODEC_ID_VPLAYER    = 0x56506c72, # MKBETAG('V','P','l','r')
        AV_CODEC_ID_PJS        = 0x50684a53, # MKBETAG('P','h','J','S')
        AV_CODEC_ID_ASS        = 0x41535320, # MKBETAG('A','S','S',' ')

        # other specific kind of codecs (generally used for attachments)
        AV_CODEC_ID_FIRST_UNKNOWN = 0x18000,           #< A dummy ID pointing at the start of various fake codecs.
        AV_CODEC_ID_TTF = 0x18000,
        AV_CODEC_ID_BINTEXT    = 0x42545854, # MKBETAG('B','T','X','T')
        AV_CODEC_ID_XBIN       = 0x5842494e, # MKBETAG('X','B','I','N')
        AV_CODEC_ID_IDF        = 0x494446, # MKBETAG(0,'I','D','F')
        AV_CODEC_ID_OTF        = 0x4f5446, # MKBETAG(0,'O','T','F')
        AV_CODEC_ID_SMPTE_KLV  = 0x4b4c5641, # MKBETAG('K','L','V','A')
        AV_CODEC_ID_DVD_NAV    = 0x444e4156, # MKBETAG('D','N','A','V')
        AV_CODEC_ID_TIMED_ID3  = 0x54494433, # MKBETAG('T','I','D','3')
        AV_CODEC_ID_BIN_DATA   = 0x44415441, # MKBETAG('D','A','T','A')


        AV_CODEC_ID_PROBE= 0x19000,
        AV_CODEC_ID_MPEG2TS= 0x20000,
        AV_CODEC_ID_MPEG4SYSTEMS= 0x20001,
        AV_CODEC_ID_FFMETADATA= 0x21000,   #< Dummy codec for streams containing only metadata information.
   

    # ok libavutil   54. 20.100
    # PyFFmpeg mapping for AVMediaType from libavutil/avutil.h 
    enum CodecType:
        CODEC_TYPE_UNKNOWN     = AVMEDIA_TYPE_UNKNOWN
        CODEC_TYPE_VIDEO       = AVMEDIA_TYPE_VIDEO
        CODEC_TYPE_AUDIO       = AVMEDIA_TYPE_AUDIO
        CODEC_TYPE_DATA        = AVMEDIA_TYPE_DATA
        CODEC_TYPE_SUBTITLE    = AVMEDIA_TYPE_SUBTITLE
        CODEC_TYPE_ATTACHMENT  = AVMEDIA_TYPE_ATTACHMENT
        CODEC_TYPE_NB          = AVMEDIA_TYPE_NB


    # ok libavcodec   56. 26.100
    struct AVPanScan:
        int id
        int width
        int height
        int16_t position[3][2]

    # ok libavcodec/avcodec.h   56. 26.100
    enum AVPacketSideDataType:
        AV_PKT_DATA_PALETTE,
        AV_PKT_DATA_NEW_EXTRADATA,
        AV_PKT_DATA_PARAM_CHANGE,
        AV_PKT_DATA_H263_MB_INFO,
        AV_PKT_DATA_REPLAYGAIN,
        AV_PKT_DATA_DISPLAYMATRIX,
        AV_PKT_DATA_STEREO3D,
        AV_PKT_DATA_AUDIO_SERVICE_TYPE,
        AV_PKT_DATA_SKIP_SAMPLES=70,
        AV_PKT_DATA_JP_DUALMONO,
        AV_PKT_DATA_STRINGS_METADATA,
        AV_PKT_DATA_SUBTITLE_POSITION,
        AV_PKT_DATA_MATROSKA_BLOCKADDITIONAL,
        AV_PKT_DATA_WEBVTT_IDENTIFIER,
        AV_PKT_DATA_WEBVTT_SETTINGS,
        AV_PKT_DATA_METADATA_UPDATE

    # ok libavcodec/avcodec.h   56. 26.100
    struct AVPacketSideData:
        uint8_t *data
        int      size
        AVPacketSideDataType type
  
    # ok libavcodec/avcodec.h   56. 26.100
    struct AVPacket:
        AVBufferRef *buf
        int64_t pts            #< presentation time stamp in time_base units
        int64_t dts            #< decompression time stamp in time_base units
        char *data
        int   size
        int   stream_index
        int   flags
        AVPacketSideData *side_data
        int side_data_elems
        int   duration         #< presentation duration in time_base units (0 if not available)
        void  *destruct
        void  *priv
        int64_t pos            #< byte position in Track, -1 if unknown
        #===============================================================================
        # * Time difference in AVStream->time_base units from the pts of this
        # * packet to the point at which the output from the decoder has converged
        # * independent from the availability of previous frames. That is, the
        # * frames are virtually identical no matter if decoding started from
        # * the very first frame or from this keyframe.
        # * Is AV_NOPTS_VALUE if unknown.
        # * This field is not the display duration of the current packet.
        # * This field has no meaning if the packet does not have AV_PKT_FLAG_KEY
        # * set.
        # *
        # * The purpose of this field is to allow seeking in streams that have no
        # * keyframes in the conventional sense. It corresponds to the
        # * recovery point SEI in H.264 and match_time_delta in NUT. It is also
        # * essential for some types of subtitle streams to ensure that all
        # * subtitles are correctly displayed after seeking.
        #===============================================================================
        int64_t convergence_duration
  
    # ok libavcodec/avcodec.h   56. 26.100
    struct AVProfile:
        int         profile
        char *      name                    #< short name for the profile


    # ok libavcodec/avcodec.h   56. 26.100
    struct AVCodec:
        char *        name
        char *        long_name
        AVMediaType   type
        AVCodecID     id
        int           capabilities    # see CODEC_CAP_*
        AVRational *supported_framerates #< array of supported framerates, or NULL if any, array is terminated by {0,0}
        AVPixelFormat *pix_fmts      #< array of supported pixel formats, or NULL if unknown, array is terminated by -1
        int *supported_samplerates   #< array of supported audio samplerates, or NULL if unknown, array is terminated by 0
        AVSampleFormat *sample_fmts  #< array of supported sample formats, or NULL if unknown, array is terminated by -1
        uint64_t *channel_layouts    #< array of support channel layouts, or NULL if unknown. array is terminated by 0
#if FF_API_LOWRES
        uint8_t max_lowres       #< maximum value for lowres supported by the decoder, no direct access, use av_codec_get_max_lowres()
#endif
        AVClass *priv_class      #< AVClass for the private context
        AVProfile *profiles      #< array of recognized profiles, or NULL if unknown, array is terminated by {FF_PROFILE_UNKNOWN}
        int priv_data_size
        AVCodec *next

        int (*init_thread_copy)(AVCodecContext *)
        int (*update_thread_context)(AVCodecContext *dst, const_AVCodecContext *src)
        AVCodecDefault *defaults
        void (*init_static_data)(AVCodec *codec)
        int (*init)(AVCodecContext *)
        int (*encode_sub)(AVCodecContext *, uint8_t *buf, int buf_size, const_struct_AVSubtitle *sub)
        int (*encode2)(AVCodecContext *avctx, AVPacket *avpkt, const_AVFrame *frame, int *got_packet_ptr)
        int (*decode)(AVCodecContext *, void *outdata, int *outdata_size, AVPacket *avpkt)
        int (*close)(AVCodecContext *)
        void (*flush)(AVCodecContext *)
        
    # ok libavcodec/avcodec.h   56. 26.100
    struct AVHWAccel:
        const_char          *name       # Name of the hardware accelerated codec
        AVMediaType         type        # Type of codec implemented by the hardware accelerator, See AVMEDIA_TYPE_xxx
        AVCodecID           id          # Codec implemented by the hardware accelerator, See AV_CODEC_ID_xxx
        AVPixelFormat       pix_fmt     # Supported pixel format
        int                 capabilities # Hardware accelerated codec capabilities, see FF_HWACCEL_CODEC_CAP_*
        
    # ok libavcodec/avcodec.h   56. 26.100
    # main external API structure
    # Please use AVOptions (av_opt* / av_set/get*()) to access these fields from user applications
    # sizeof(AVCodecContext) must not be used outside libav*.
    struct AVCodecContext:
        const_AVClass *av_class
        int                     log_level_offset
        AVMediaType             codec_type  # see AVMEDIA_TYPE_xxx
        const_struct_AVCodec    *codec
        
        # deprecated, will be removed in major 57
        char                    codec_name[32]
        
        AVCodecID               codec_id    # see AV_CODEC_ID_xxx
        unsigned int            codec_tag   # fourcc
        
        # deprecated, will be removed in major 59
        unsigned int stream_codec_tag
        
        void                    *priv_data
        AVCodecInternal         *internal   # Private context used for internal data
        
        void                    *opaque     # Private data of the user, can be used to carry app specific stuff

        int                     bit_rate    # the average bitrate
        int                     bit_rate_tolerance # number of bits the bitstream is allowed to diverge from the reference
        
        int                     global_quality  # Global quality for codecs which cannot change it per frame
        int                     compression_level
        
        int                     flags       # CODEC_FLAG_*
        int                     flags2      # CODEC_FLAG2_*

        uint8_t                 *extradata  # some codecs need / can use extradata like Huffman tables
        int                     extradata_size
        
        AVRational              time_base   # fundamental unit of time (in seconds)
        int                     ticks_per_frame # For some codecs, the time base is closer to the field rate than the frame rate

        int                     delay       # Codec delay
        
        int                     width       # video only: picture width
        int                     height      # video only: picture height
        
        int                     coded_width # Bitstream width 
        int                     coded_height # Bitstream height 
        
        int                     gop_size    # the number of pictures in a group of pictures, or 0 for intra_only
        
        AVPixelFormat           pix_fmt     # Pixel format, see AV_PIX_FMT_xxx.

        # 1 (zero), 2 (full), 3 (log), 4 (phods), 5 (epzs), 6 (x1), 7 (hex),
        # 8 (umh), 9 (iter), 10 (tesa) [7, 8, 10 are x264 specific, 9 is snow specific]
        int                     me_method   # Motion estimation algorithm used for video coding           

        void (*draw_horiz_band)(AVCodecContext *s, const_AVFrame *src, int offset[AV_NUM_DATA_POINTERS], int y, int type, int height)

        # callback to negotiate the pixelFormat
        AVPixelFormat (*get_format)(AVCodecContext *s, AVPixelFormat * fmt)

        int                     max_b_frames    # maximum number of B-frames between non-B-frames
        float                   b_quant_factor  # qscale factor between IP and B-frames
        int                     rc_strategy
        int                     b_frame_strategy
        float                   b_quant_offset  # qscale offset between IP and B-frames
        int                     has_b_frames    # Size of the frame reordering buffer in the decoder
        int                     mpeg_quant      # 0-> h263 quant 1-> mpeg quant
        float                   i_quant_factor  # qscale factor between P and I-frames
        float                   i_quant_offset  # qscale offset between P and I-frames
        float                   lumi_masking    # luminance masking (0-> disabled)
        float                   temporal_cplx_masking # temporary complexity masking (0-> disabled)
        float                   spatial_cplx_masking # spatial complexity masking (0-> disabled)
        float                   p_masking       # p block masking (0-> disabled)
        float                   dark_masking    # darkness masking (0-> disabled)
        
        int                     slice_count     # slice count
        int                     prediction_method # see FF_PRED_*
        int                     *slice_offset   # slice offsets in the frame in bytes
        
        AVRational              sample_aspect_ratio  # sample aspect ratio (0 if unknown)
        
        int                     me_cmp          # motion estimation comparison function
        int                     me_sub_cmp      # subpixel motion estimation comparison function
        int                     mb_cmp          # macroblock comparison function (not supported yet)
        int                     ildct_cmp       # interlaced DCT comparison function, see FF_CMP_*
        int                     dia_size        # ME diamond size & shape
        int                     last_predictor_count # amount of previous MV predictors (2a+1 x 2a+1 square)
        
        int                     pre_me          # prepass for motion estimation
        int                     me_pre_cmp      # motion estimation prepass comparison function
        int                     pre_dia_size    # ME prepass diamond size & shape
        int                     me_subpel_quality # subpel ME quality
        
        # deprecated, will be removed in major 57
        int                     dtg_active_format # DTG active format information, see FF_DTG_AFD_*

        int                     me_range        # maximum motion estimation search range in subpel units, if 0 then no limit
        
        int                     intra_quant_bias # intra quantizer bias
        int                     inter_quant_bias # inter quantizer bias
        
        int                     slice_flags     # slice flags, see SLICE_FLAG_*
        
        # deprecated, will be removed in major 55 or 57
        int                     xvmc_acceleration
        
        int                     mb_decision     # macroblock decision mode, see FF_MB_DECISION_*
        
        uint16_t                *intra_matrix   # custom intra quantization matrix
        uint16_t                *inter_matrix   # custom inter quantization matrix
        
        int                     scenechange_threshold # scene change detection threshold, 0 is default, larger means fewer detected scene changes
        
        int                     noise_reduction # noise reduction strength
    
        # deprecated, will be removed in major 59
        int                     me_threshold    # unused
        # deprecated, will be removed in major 59
        int                     mb_threshold    # unused

        int                     intra_dc_precision # precision of the intra DC coefficient - 8
        
        int                     skip_top        # Number of macroblock rows at the top which are skipped
        int                     skip_bottom     # Number of macroblock rows at the bottom which are skipped
        
        # deprecated, will be removed in major 59
        float                   border_masking  # use encoder private options instead

        int                     mb_lmin         # minimum MB lagrange multipler
        int                     mb_lmax         # maximum MB lagrange multipler
        int                     me_penalty_compensation
        int                     bidir_refine
        int                     brd_scale
        
        int                     keyint_min      # minimum GOP size
        
        int                     refs            # number of reference frames
        
        int                     chromaoffset    # chroma qp offset from luma
        
        # deprecated, will be removed in major 57        
        int                     scenechange_factor
        
        int                     mv0_threshold   # Note: Value depends upon the compare function used for fullpel ME
        
        int                     b_sensitivity   # Adjust sensitivity of b_frame_strategy 1
        
        AVColorPrimaries        color_primaries # Chromaticity coordinates of the source primaries
        AVColorTransferCharacteristic color_trc # Color Transfer Characteristic
        AVColorSpace            colorspace      # YUV colorspace type
        AVColorRange            color_range     # MPEG vs JPEG YUV range
        AVChromaLocation        chroma_sample_location # location of chroma samples
        
        int                     slices          # Number of slices
        
        AVFieldOrder            field_order
        
        # audio only
        int                     sample_rate     # samples per second
        int                     channels        # number of audio channels
        AVSampleFormat          sample_fmt      # audio sample format
        int                     frame_size      # Number of samples per channel in an audio frame
        int                     frame_number    # Frame counter
        int                     block_align     # number of bytes per packet if constant and known or 0
        
        int                     cutoff          # Audio cutoff bandwidth (0 means "automatic")
        
        # deprecated, will be removed in major 57
        int                     request_channels
        
        uint64_t                channel_layout  # Audio channel layout
        uint64_t                request_channel_layout # Request decoder to use this channel layout if it can (0 for default)
        AVAudioServiceType      audio_service_type # Type of service that the audio stream conveys
        AVSampleFormat          request_sample_fmt # desired sample format
        
        # BEGIN deprecated, will be removed in major 57
        int (*get_buffer)(AVCodecContext *c, AVFrame *pic)
        void (*release_buffer)(AVCodecContext *c, AVFrame *pic)
        int (*reget_buffer)(AVCodecContext *c, AVFrame *pic)
        # END deprecated, will be removed in major 57
        
        int (*get_buffer2)(AVCodecContext *s, AVFrame *frame, int flags)
        int                     refcounted_frames # If non-zero, the decoded audio and video frames returned from ...
        float                   qcompress       # amount of qscale change between easy & hard scenes (0.0-1.0)
        float                   qblur           # amount of qscale smoothing over time (0.0-1.0)
        int                     qmin            # minimum quantizer
        int                     qmax            # maximum quantizer
        int                     max_qdiff       # maximum quantizer difference between frames
        
        # BEGIN deprecated, will be removed in major 59
        float                   rc_qsquish
        float                   rc_qmod_amp
        int                     rc_qmod_freq
        # END deprecated, will be removed in major 59
        
        int                     rc_buffer_size  # decoder bitstream buffer size
        int                     rc_override_count # ratecontrol override, see RcOverride
        RcOverride              *rc_override
        
        # deprecated, will be removed in major 59
        const_char              *rc_eq
        
        int                     rc_max_rate     # maximum bitrate
        int                     rc_min_rate     # minimum bitrate
        
        # BEGIN deprecated, will be removed in major 59
        float                   rc_buffer_aggressivity
        float                   rc_initial_cplx
        # END deprecated, will be removed in major 59
        
        float                   rc_max_available_vbv_use # Ratecontrol attempt to use, at maximum, <value> of what can be used without an underflow.
        float                   rc_min_vbv_overflow_use # Ratecontrol attempt to use, at least, <value> times the amount needed to prevent a vbv overflow.
        int                     rc_initial_buffer_occupancy # Number of bits which should be loaded into the rc buffer before decoding starts.

        int                     coder_type # see FF_CODER_TYPE_*
        int context_model
        
        # BEGIN deprecated, will be removed in major 59
        int                     lmin
        int                     lmax
        # END deprecated, will be removed in major 59
        
        int                     frame_skip_threshold # frame skip threshold
        int                     frame_skip_factor # frame skip factor
        int                     frame_skip_exp  # frame skip exponent
        int                     frame_skip_cmp  # frame skip comparison function
        int                     trellis         # trellis RD quantization
        int                     min_prediction_order
        int                     max_prediction_order
        
        int64_t                 timecode_frame_start # GOP timecode frame start number
        
        void (*rtp_callback)(AVCodecContext *avctx, void *data, int size, int mb_nb)
        int                     rtp_payload_size # The size of the RTP payload
        
        # statistics, used for 2-pass encoding 
        int                     mv_bits
        int                     header_bits
        int                     i_tex_bits
        int                     p_tex_bits
        int                     i_count
        int                     p_count
        int                     skip_count
        int                     misc_bits
        
        int                     frame_bits      # number of bits used for the previously encoded frame
        
        char                    *stats_out      # pass1 encoding statistics output buffer
        
        int                     workaround_bugs # Work around bugs in encoders which sometimes cannot be detected automatically, see FF_BUG_*
        int                     strict_std_compliance # strictly follow the standard, see FF_COMPLIANCE_*
        int                     error_concealment # error concealment flags, see FF_EC_*
        
        int                     debug           # see FF_DEBUG_*
        
        # deprecated, will be removed in major 57
        int                     debug_mv        # Code outside libavcodec should access this field using AVOptions, previsouly used FF_DEBUG_VIS_MV_*
        
        int                     err_recognition # Error recognition; may misdetect some more or less valid parts as errors, see AV_EF_*
        
        int64_t                 reordered_opaque # opaque 64bit number (generally a PTS)
        
        AVHWAccel               *hwaccel        # Hardware accelerator in use
        void                    *hwaccel_context
        
        uint64_t                error[AV_NUM_DATA_POINTERS] # encoding error, if if flags&CODEC_FLAG_PSNR set
        
        int                     dct_algo        # DCT algorithm, see FF_DCT_*
        int                     idct_algo       # IDCT algorithm, see FF_IDCT_*
        
        int                     bits_per_coded_sample # bits per sample/pixel from the demuxer (needed for huffyuv)
        int                     bits_per_raw_sample # Bits per sample/pixel of internal libavcodec pixel/sample format
        
        # deprecated, will be removed in major 57
        int                     lowres          # use instead av_codec_{get,set}_lowres(avctx)
        
        AVFrame                 *coded_frame    # the picture in the bitstream
        
        int                     thread_count    # thread count
        int                     thread_type     # Which multithreading methods to use, see FF_THREAD_*
        
        int                     active_thread_type # Which multithreading methods are in use by the codec
        int                     thread_safe_callbacks  
        
        # he codec may call this to execute several independent things
        int (*execute)(AVCodecContext *c, int (*func)(AVCodecContext *c2, void *arg), void *arg2, int *ret, int count, int size)
        int (*execute2)(AVCodecContext *c, int (*func)(AVCodecContext *c2, void *arg, int jobnr, int threadnr), void *arg2, int *ret, int count)
        
        # deprecated, will be removed in major 57
        void                    *thread_opaque
        
        int                     nsse_weight     # noise vs. sse weight for the nsse comparison function
        
        int                     profile         # see FF_PROFILE_*
        int                     level
        
        AVDiscard               skip_loop_filter # Skip loop filtering for selected frames
        AVDiscard               skip_idct       # Skip IDCT/dequantization for selected frames
        AVDiscard               skip_frame      # Skip decoding for selected frames
        
        uint8_t                 *subtitle_header # Header containing style information for text subtitles
        int                     subtitle_header_size
        
        # deprecated, will be removed in major 57
        int                     error_rate 
        
        # deprecated, will be removed in major 57
        AVPacket                *pkt
        
        uint64_t                vbv_delay       # VBV delay coded in the last frame (in periods of a 27 MHz clock)
        
        int                     side_data_only_packets
        
        int                     initial_padding
        
        AVRational              framerate       # For codecs that store a framerate value
        AVPixelFormat           sw_pix_fmt      # Nominal unaccelerated pixel format, see AV_PIX_FMT_xxx
        
        AVRational              pkt_timebase    # Timebase in which pkt_dts/pts and AVPacket.dts/pts are
        const_AVCodecDescriptor *codec_descriptor # use av_codec_{get,set}_codec_descriptor(avctx)
        
        # will be used in major 57
        #int                     lowres         # use av_codec_{get,set}_lowres(avctx)
        
        # Current statistics for PTS correction.
        int64_t                 pts_correction_num_faulty_pts # Number of incorrect PTS values so far
        int64_t                 pts_correction_num_faulty_dts # Number of incorrect DTS values so far
        int64_t                 pts_correction_last_pts # PTS of the last frame
        int64_t                 pts_correction_last_dts # DTS of the last frame
        
        char                    *sub_charenc    # Character encoding of the input subtitles file
        int                     sub_charenc_mode # Subtitles character encoding mode, see FF_SUB_CHARENC_MODE_
        
        int                     skip_alpha      # Skip processing alpha if supported by codec
        
        int                     seek_preroll    # Number of samples to skip after a discontinuity
        
        # will be used in major 57
        #int                     debug_mv    # debug motion vectors, Code outside libavcodec should access this field using AVOptions

        uint16_t                *chroma_intra_matrix # custom intra quantization matrix
        
        uint8_t                 *dump_separator # dump format separator
        
        char                    *codec_whitelist # ',' separated list of allowed decoders
        
    struct AVPicture:
        uint8_t *data[AV_NUM_DATA_POINTERS] #< pointers to the image data planes 
        int linesize[AV_NUM_DATA_POINTERS] #< number of bytes per line

    enum AVPictureStructure:
        AV_PICTURE_STRUCTURE_UNKNOWN,      #< unknown
        AV_PICTURE_STRUCTURE_TOP_FIELD,    #< coded as top field
        AV_PICTURE_STRUCTURE_BOTTOM_FIELD, #< coded as bottom field
        AV_PICTURE_STRUCTURE_FRAME,        #< coded as frame        

    # AVCodecParserContext.flags
    enum:
        PARSER_FLAG_COMPLETE_FRAMES          = 0x0001
        PARSER_FLAG_ONCE                     = 0x0002
        PARSER_FLAG_FETCHED_OFFSET           = 0x0004        #< Set if the parser has a valid file offset
        PARSER_FLAG_USE_CODEC_TS             = 0x1000
        
    # for AVCodecParserContext array lengths
    enum:        
        AV_PARSER_PTS_NB = 4        
     
    struct AVCodecParser:
        pass
     
    struct AVCodecParserContext:
        void *priv_data
        AVCodecParser *parser
        int64_t frame_offset                #< offset of the current frame 
        int64_t cur_offset                      #< current offset (incremented by each av_parser_parse()) 
        int64_t next_frame_offset               #< offset of the next frame 
        # video info 
        int pict_type #< XXX: Put it back in AVCodecContext. 
        #     * This field is used for proper frame duration computation in lavf.
        #     * It signals, how much longer the frame duration of the current frame
        #     * is compared to normal frame duration.
        #     * frame_duration = (1 + repeat_pict) * time_base
        #     * It is used by codecs like H.264 to display telecined material.
        int repeat_pict #< XXX: Put it back in AVCodecContext. 
        int64_t pts     #< pts of the current frame 
        int64_t dts     #< dts of the current frame 

        # private data 
        int64_t last_pts
        int64_t last_dts
        int fetch_timestamp

        int cur_frame_start_index
        int64_t cur_frame_offset[AV_PARSER_PTS_NB]
        int64_t cur_frame_pts[AV_PARSER_PTS_NB]
        int64_t cur_frame_dts[AV_PARSER_PTS_NB]
        int flags
        int64_t offset      #< byte offset from starting packet start
        int64_t cur_frame_end[AV_PARSER_PTS_NB]
        #     * Set by parser to 1 for key frames and 0 for non-key frames.
        #     * It is initialized to -1, so if the parser doesn't set this flag,
        #     * old-style fallback using FF_I_TYPE picture type as key frames
        #     * will be used.
        int key_frame
        #     * Time difference in stream time base units from the pts of this
        #     * packet to the point at which the output from the decoder has converged
        #     * independent from the availability of previous frames. That is, the
        #     * frames are virtually identical no matter if decoding started from
        #     * the very first frame or from this keyframe.
        #     * Is AV_NOPTS_VALUE if unknown.
        #     * This field is not the display duration of the current frame.
        #     * This field has no meaning if the packet does not have AV_PKT_FLAG_KEY
        #     * set.
        #     *
        #     * The purpose of this field is to allow seeking in streams that have no
        #     * keyframes in the conventional sense. It corresponds to the
        #     * recovery point SEI in H.264 and match_time_delta in NUT. It is also
        #     * essential for some types of subtitle streams to ensure that all
        #     * subtitles are correctly displayed after seeking.
        int64_t convergence_duration
        # Timestamp generation support:
        #     * Synchronization point for start of timestamp generation.
        #     *
        #     * Set to >0 for sync point, 0 for no sync point and <0 for undefined
        #     * (default).
        #     *
        #     * For example, this corresponds to presence of H.264 buffering period
        #     * SEI message.
        int dts_sync_point
        #     * Offset of the current timestamp against last timestamp sync point in
        #     * units of AVCodecContext.time_base.
        #     * Set to INT_MIN when dts_sync_point unused. Otherwise, it must
        #     * contain a valid timestamp offset.
        #     * Note that the timestamp of sync point has usually a nonzero
        #     * dts_ref_dts_delta, which refers to the previous sync point. Offset of
        #     * the next frame after timestamp sync point will be usually 1.
        #     * For example, this corresponds to H.264 cpb_removal_delay.
        int dts_ref_dts_delta
        #     * Presentation delay of current frame in units of AVCodecContext.time_base.
        #     * Set to INT_MIN when dts_sync_point unused. Otherwise, it must
        #     * contain valid non-negative timestamp delta (presentation time of a frame
        #     * must not lie in the past).
        #     * This delay represents the difference between decoding and presentation
        #     * time of the frame.
        #     * For example, this corresponds to H.264 dpb_output_delay.
        int pts_dts_delta
        int64_t cur_frame_pos[AV_PARSER_PTS_NB]            #< Position of the packet in file. Analogous to cur_frame_pts/dts
        int64_t pos                                        #< * Byte position of currently parsed frame in stream.
        int64_t last_pos                                   #< * Previous frame byte position.
        int duration # Duration of the current frame.
        #    * For audio, this is in units of 1 / AVCodecContext.sample_rate.
        #    * For all other types, this is in units of AVCodecContext.time_base.
        AVFieldOrder field_order
        AVPictureStructure picture_structure    # Indicate whether a picture is coded as a frame, top field or bottom field
        int output_picture_number               # Picture number incremented in presentation or output order.
        
        # Dimensions of the decoded video intended for presentation.
        int width
        int height
        
        # Dimensions of the coded video.
        int coded_width
        int coded_height
        
        int format #  The format of the coded data, corresponds to enum AVPixelFormat for video and for enum AVSampleFormat for audio.
        

    AVCodec *avcodec_find_decoder(AVCodecID id)
    AVCodec *avcodec_find_decoder_by_name(const_char *name)
    
    int avcodec_open2(AVCodecContext *avctx, AVCodec *codec, AVDictionary **options)

    int avcodec_close(AVCodecContext *avctx)

    # deprecated ... use instead avcodec_decode_video2
    int avcodec_decode_video2(AVCodecContext *avctx, AVFrame *picture,
                         int *got_picture_ptr,
                         AVPacket *avpkt)
                         
    # FIXME: deprecated: avcodec_decode_audio3
    # @TODO: USE avcodec_decode_audio4
    int avcodec_decode_audio3(AVCodecContext *avctx, int16_t *samples,
                         int *frame_size_ptr,
                         AVPacket *avpkt)

    int avpicture_fill(AVPicture *picture, uint8_t *ptr,
                       AVPixelFormat pix_fmt, int width, int height)
    int avpicture_layout(AVPicture* src, AVPixelFormat pix_fmt, 
                         int width, int height, unsigned char *dest, int dest_size)
    int avpicture_get_size(AVPixelFormat pix_fmt, int width, int height)

    void avcodec_get_chroma_sub_sample(AVPixelFormat pix_fmt, int *h_shift, int *v_shift)
    
    # FIXME: not available anymore
    #char *avcodec_get_pix_fmt_name(AVPixelFormat pix_fmt)
    
    # FIXME: deprecated:
    void avcodec_set_dimensions(AVCodecContext *s, int width, int height)

    # FIXME: deprecated:
    AVFrame *avcodec_alloc_frame()
    
    void avcodec_flush_buffers(AVCodecContext *avctx)

    # Return a single letter to describe the given picture type pict_type.
    # FIXME: not available anymore
    #char av_get_pict_type_char(int pict_type)

    # * Parse a packet.
    # *
    # * @param s             parser context.
    # * @param avctx         codec context.
    # * @param poutbuf       set to pointer to parsed buffer or NULL if not yet finished.
    # * @param poutbuf_size  set to size of parsed buffer or zero if not yet finished.
    # * @param buf           input buffer.
    # * @param buf_size      input length, to signal EOF, this should be 0 (so that the last frame can be output).
    # * @param pts           input presentation timestamp.
    # * @param dts           input decoding timestamp.
    # * @param pos           input byte position in stream.
    # * @return the number of bytes of the input bitstream used.
    # *
    # * Example:
    # * @code
    # *   while(in_len){
    # *       len = av_parser_parse2(myparser, AVCodecContext, &data, &size,
    # *                                        in_data, in_len,
    # *                                        pts, dts, pos);
    # *       in_data += len;
    # *       in_len  -= len;
    # *
    # *       if(size)
    # *          decode_frame(data, size);
    # *   }
    # * @endcode
    int av_parser_parse2(AVCodecParserContext *s,
                     AVCodecContext *avctx,
                     uint8_t **poutbuf, int *poutbuf_size,
                     uint8_t *buf, int buf_size,
                     int64_t pts, int64_t dts,
                     int64_t pos)
    int av_parser_change(AVCodecParserContext *s,
                     AVCodecContext *avctx,
                     uint8_t **poutbuf, int *poutbuf_size,
                     uint8_t *buf, int buf_size, int keyframe)
    void av_parser_close(AVCodecParserContext *s)

    void av_free_packet(AVPacket *pkt)


##################################################################################
# Used for debugging
##################################################################################

#class DLock:
#    def __init__(self):
#        self.l=threading.Lock()
#    def acquire(self,*args,**kwargs):
#        sys.stderr.write("MTX:"+str((self, "A", args, kwargs))+"\n")
#        try:
#            raise Exception
#        except:
#            if (hasattr(sys,"last_traceback")):
#                traceback.print_tb(sys.last_traceback)
#            else:
#                traceback.print_tb(sys.exc_traceback)
#        sys.stderr.flush()
#        sys.stdout.flush()
#        #return self.l.acquire(*args,**kwargs)
#        return True
#    def release(self):
#        sys.stderr.write("MTX:"+str((self, "R"))+"\n")
#        try:
#            raise Exception
#        except:
#            if (hasattr(sys,"last_traceback")):
#                traceback.print_tb(sys.last_traceback)
#            else:
#                traceback.print_tb(sys.exc_traceback)
#        sys.stderr.flush()
#        sys.stdout.flush()
#        #return self.l.release()


##################################################################################
# ok libavformat  52.102. 0
cdef extern from "libavformat/avformat.h":

    enum:    
        AVSEEK_FLAG_BACKWARD = 1 #< seek backward
        AVSEEK_FLAG_BYTE     = 2 #< seeking based on position in bytes
        AVSEEK_FLAG_ANY      = 4 #< seek to any frame, even non-keyframes
        AVSEEK_FLAG_FRAME    = 8 #< seeking based on frame number
    
    # ok libavformat/avformat.h     56. 25.101 
    struct AVFrac:
        int64_t val, num, den

    # ok libavformat/avformat.h     56. 25.101 
    struct AVProbeData:
        const_char *filename
        unsigned char *buf
        int buf_size
        const_char *mime_type

    # ok libavformat/avformat.h     56. 25.101 
    struct AVIndexEntry:
        int64_t pos
        int64_t timestamp
        int flags
        int size
        int min_distance
    
    struct AVMetadataConv:
        pass
    
    struct AVMetadata:
        pass
    
    struct AVCodecTag:
        pass
    
    # ok libavformat/avformat.h     56. 25.101 
    enum AVStreamParseType:
        AVSTREAM_PARSE_NONE,
        AVSTREAM_PARSE_FULL,        #< full parsing and repack */
        AVSTREAM_PARSE_HEADERS,     #< Only parse headers, do not repack. */
        AVSTREAM_PARSE_TIMESTAMPS,  #< full parsing and interpolation of timestamps for frames not starting on a packet boundary */
        AVSTREAM_PARSE_FULL_ONCE,   #< full parsing and repack of the first frame only, only implemented for H.264 currently
        AVSTREAM_PARSE_FULL_RAW = 0x57415200, # MKTAG(0,'R','A','W') 
    
    # ok libavformat/avformat.h     56. 25.101 
    struct AVPacketList:
        AVPacket pkt
        AVPacketList *next

    # ok libavformat/avformat.h     56. 25.101 
    struct AVOutputFormat:
        const_char *name
        const_char *long_name
        const_char *mime_type
        const_char *extensions
        AVCodecID audio_codec       #< default audio codec
        AVCodecID video_codec       #< default video codec
        AVCodecID subtitle_codec    #< default subtitle codec
        # * can use flags: AVFMT_NOFILE, AVFMT_NEEDNUMBER, AVFMT_RAWPICTURE,
        # * AVFMT_GLOBALHEADER, AVFMT_NOTIMESTAMPS, AVFMT_VARIABLE_FPS,
        # * AVFMT_NODIMENSIONS, AVFMT_NOSTREAMS, AVFMT_ALLOW_FLUSH,
        # * AVFMT_TS_NONSTRICT
        int flags
        AVCodecTag **codec_tag
        const_AVClass *priv_class

    # ok libavformat/avformat.h     56. 25.101 
    struct AVInputFormat:
        const_char *name            #< A comma separated list of short names for the format
        const_char *long_name       #< Descriptive name for the format, meant to be more human-readable than name  
        # * Can use flags: AVFMT_NOFILE, AVFMT_NEEDNUMBER, AVFMT_SHOW_IDS,
        # * AVFMT_GENERIC_INDEX, AVFMT_TS_DISCONT, AVFMT_NOBINSEARCH,
        # * AVFMT_NOGENSEARCH, AVFMT_NO_BYTE_SEEK, AVFMT_SEEK_TO_PTS.
        int flags
        const_char *extensions
        AVCodecTag **codec_tag
        const_AVClass *priv_class
        const_char *mime_type       #< Comma-separated list of mime types

    # ok libavformat/avformat.h     56. 25.101 
    struct AVStream:
        int                 index       #< stream index in AVFormatContext
        int                 id          #< Format-specific stream ID
        AVCodecContext      *codec      #< Codec context associated with this stream
        void                *priv_data
        # deprecated, will be removed in major 57
        # IF FF_API_LAVF_FRAC
        AVFrac              pts
        AVRational          time_base   #< This is the fundamental unit of time (in seconds) in terms of which frame timestamps are represented
        int64_t             start_time  #< Decoding: pts of the first frame of the stream in presentation order
        int64_t             duration    #< Decoding: duration of the stream, in stream time base
        int64_t             nb_frames   #< < number of frames in this stream if known or 0
        int                 disposition #< see AV_DISPOSITION_*
        AVDiscard           discard     #< Selects which packets can be discarded at will and do not need to be demuxed.
        AVRational          sample_aspect_ratio #< sample aspect ratio (0 if unknown)
        AVDictionary        *metadata
        AVRational          avg_frame_rate #< Average framerate
        AVPacket            attached_pic #< For streams with AV_DISPOSITION_ATTACHED_PIC disposition, this packet will contain the attached picture.
        AVPacketSideData    *side_data  #< An array of side data that applies to the whole stream
        int                 nb_side_data #< The number of elements in the AVStream.side_data array
        int                 event_flags # Flags for the user to detect events happening on the stream be cleared by the user once the event has been handled, see AVSTREAM_EVENT_FLAG_*
        
    # ok libavformat/avformat.h     56. 25.101 
    enum:
        # for AVFormatContext.flags
        AVFMT_FLAG_GENPTS      = 0x0001     #< Generate missing pts even if it requires parsing future frames.
        AVFMT_FLAG_IGNIDX      = 0x0002     #< Ignore index.
        AVFMT_FLAG_NONBLOCK    = 0x0004     #< Do not block when reading packets from input.
        AVFMT_FLAG_IGNDTS      = 0x0008     #< Ignore DTS on frames that contain both DTS & PTS
        AVFMT_FLAG_NOFILLIN    = 0x0010     #< Do not infer any values from other values, just return what is stored in the container
        AVFMT_FLAG_NOPARSE     = 0x0020     #< Do not use AVParsers, you also must set AVFMT_FLAG_NOFILLIN as the fillin code works on frames and no parsing -> no frames. Also seeking to frames can not work if parsing to find frame boundaries has been disabled
        AVFMT_FLAG_NOBUFFER    = 0x0040     #< Add RTP hinting to the output file
        AVFMT_FLAG_CUSTOM_IO   = 0x0080     #< The caller has supplied a custom AVIOContext, don't avio_close() it.
        AVFMT_FLAG_DISCARD_CORRUPT = 0x0100 #< Discard frames marked corrupted
        AVFMT_FLAG_FLUSH_PACKETS   = 0x0200 #< Flush the AVIOContext every packet.
        AVFMT_FLAG_BITEXACT        = 0x0400
        AVFMT_FLAG_MP4A_LATM   = 0x8000     #< Enable RTP MP4A-LATM payload
        AVFMT_FLAG_SORT_DTS    = 0x10000    #< try to interleave outputted packets by dts (using this flag can slow demuxing down)
        AVFMT_FLAG_PRIV_OPT    = 0x20000    #< Enable use of private options by delaying codec open (this could be made default once all code is converted)
        AVFMT_FLAG_KEEP_SIDE_DATA = 0x40000 #< Don't merge side data but keep it separate.


    struct AVProgram:
        pass


    struct AVChapter:
        pass

    
    # ok libavformat/avformat.h     56. 25.101 
    enum AVDurationEstimationMethod:
        AVFMT_DURATION_FROM_PTS,    #< Duration accurately estimated from PTSes
        AVFMT_DURATION_FROM_STREAM, #< Duration estimated from a stream with a known duration
        AVFMT_DURATION_FROM_BITRATE #< Duration estimated from bitrate (less accurate)
    
    ctypedef struct AVFormatInternal

    # ok libavformat/avformat.h     56. 25.101 
    struct AVFormatContext:
        const_AVClass       av_class
        AVInputFormat *     iformat         # The input container format
        AVOutputFormat *    oformat         # The output container format
        void *              priv_data       # Format private data
        AVIOContext *       pb              # I/O context
        int                 ctx_flags       # stream info, see AVFMTCTX_
        unsigned int        nb_streams      # Number of elements in AVFormatContext.streams
        AVStream            **streams       # A list of all streams in the file
        char                filename[1024]  # input or output filename
        int64_t             start_time      # Position of the first frame of the component, in AV_TIME_BASE fractional seconds
        int64_t             duration        # Duration of the stream, in AV_TIME_BASE fractional seconds
        int                 bit_rate        # Total stream bitrate in bit/s, 0 if not available
        unsigned int        packet_size
        int                 max_delay
        int                 flags           # Flags modifying the (de)muxer behaviour. A combination of AVFMT_FLAG_*
        unsigned int        probesize       # deprecated in favor of probesize2
        int                 max_analyze_duration # deprecated in favor of max_analyze_duration2
        uint8_t             *key
        int                 keylen
        unsigned int        nb_programs
        AVProgram           **programs
        AVCodecID           video_codec_id  # Forced video codec_id
        AVCodecID           audio_codec_id  # Forced audio codec_id
        AVCodecID           subtitle_codec_id # Forced subtitle codec_id
        unsigned int        max_index_size  # Maximum amount of memory in bytes to use for the index of each stream
        unsigned int        max_picture_buffer # Maximum amount of memory in bytes to use for buffering frames
        unsigned int        nb_chapters     # Number of chapters in AVChapter array
        AVChapter           **chapters
        AVDictionary        *metadata       # Metadata that applies to the whole file
        int64_t             start_time_realtime # Start time of the stream in real world time, in microseconds since the Unix epoch
        int                 fps_probe_size  # The number of frames used for determining the framerate in avformat_find_stream_info()
        int                 error_recognition # Error recognition; higher values will detect more errors
        AVIOInterruptCB     interrupt_callback # Custom interrupt callbacks for the I/O layer
        int                 debug           # Flags to enable debugging
        int64_t             max_interleave_delta # Maximum buffering duration for interleaving
        int                 strict_std_compliance # Allow non-standard and experimental extension
        int                 event_flags     # Flags for the user to detect events happening on the file
        int                 max_ts_probe    # Maximum number of packets to read while waiting for the first timestamp
        int                 avoid_negative_ts # Avoid negative timestamps during muxing, see AVFMT_AVOID_NEG_TS_*
        int                 ts_id           # Transport stream id
        int                 audio_preload   # Audio preload in microseconds
        int                 max_chunk_duration # Max chunk time in microseconds
        int                 max_chunk_size  # Max chunk size in bytes
        int                 use_wallclock_as_timestamps # forces the use of wallclock timestamps as pts/dts of packets
        int                 avio_flags      # avio flags
        AVDurationEstimationMethod duration_estimation_method
        int64_t             skip_initial_bytes # Skip initial bytes when opening stream
        unsigned int        correct_ts_overflow # Correct single timestamp overflows
        int                 seek2any        # Force seeking to any (also non key) frames
        int                 flush_packets   # Flush the I/O context after each packet
        int                 probe_score     # format probing score
        int                 format_probesize # number of bytes to read maximally to identify format
        char                *codec_whitelist # ',' separated list of allowed decoders
        char                *format_whitelist # ',' separated list of allowed demuxers
        AVFormatInternal    *internal       # An opaque field for libavformat internal usage
        int                 io_repositioned # IO repositioned flag
        AVCodec             *video_codec    # Forced video codec
        AVCodec             *audio_codec    # Forced audio codec
        AVCodec             *subtitle_codec # Forced subtitle codec
        AVCodec             *data_codec     # Forced data codec
        int                 metadata_header_padding # Number of bytes to be written as padding in a metadata header
        void                *opaque         # User data
        # Callback used by devices to communicate with application
        int (*control_message_cb)(AVFormatContext *s, int type, void *data, size_t data_size)
        int64_t             output_ts_offset # Output timestamp offset, in microseconds
        int64_t             max_analyze_duration2 # Maximum duration (in AV_TIME_BASE units) of the data read from input in avformat_find_stream_info()
        int64_t             probesize2      # Maximum size of the data read from input for determining the input container format
        uint8_t             *dump_separator # dump format separator
        AVCodecID           data_codec_id   # Forced Data codec_id


    struct AVInputFormat:
        pass


    struct AVFormatParameters:
        pass


    AVOutputFormat *av_guess_format(char *short_name,
                                char *filename,
                                char *mime_type)

    AVCodecID av_guess_codec(AVOutputFormat *fmt, char *short_name,
                           char *filename, char *mime_type,
                           AVMediaType type)

    # * Initialize libavformat and register all the muxers, demuxers and
    # * protocols. If you do not call this function, then you can select
    # * exactly which formats you want to support.
    void av_register_all()
    
    # * Find AVInputFormat based on the short name of the input format.
    AVInputFormat *av_find_input_format(char *short_name)

    # * Guess the file format.
    AVInputFormat *av_probe_input_format(AVProbeData *pd, int is_opened)

    # * Guess the file format.
    AVInputFormat *av_probe_input_format2(AVProbeData *pd, int is_opened, int *score_max)


    # FIXME: not available anymore 
    # * Allocate all the structures needed to read an input stream.
    # *        This does not open the needed codecs for decoding the stream[s].
    #int av_open_input_stream(AVFormatContext **ic_ptr,
    #                     AVIOContext *pb, char *filename,
    #                     AVInputFormat *fmt, AVFormatParameters *ap)

    # FIXME: not available anymore 
    # * Open a media file as input. The codecs are not opened. Only the file
    # * header (if present) is read.
    # *
    # * @param ic_ptr The opened media file handle is put here.
    # * @param filename filename to open
    # * @param fmt If non-NULL, force the file format to use.
    # * @param buf_size optional buffer size (zero if default is OK)
    # * @param ap Additional parameters needed when opening the file
    # *           (NULL if default).
    # * @return 0 if OK, AVERROR_xxx otherwise
    #int av_open_input_file(AVFormatContext **ic_ptr, char *filename,
    #                   AVInputFormat *fmt, int buf_size,
    #                   AVFormatParameters *ap)

    # Open an input stream and read the header. The codecs are not opened.
    # The stream must be closed with avformat_close_input().
    #
    # @param ps Pointer to user-supplied AVFormatContext (allocated by avformat_alloc_context).
    #           May be a pointer to NULL, in which case an AVFormatContext is allocated by this
    #           function and written into ps.
    #           Note that a user-supplied AVFormatContext will be freed on failure.
    # @param filename Name of the stream to open.
    # @param fmt If non-NULL, this parameter forces a specific input format.
    #            Otherwise the format is autodetected.
    # @param options  A dictionary filled with AVFormatContext and demuxer-private options.
    #                 On return this parameter will be destroyed and replaced with a dict containing
    #                 options that were not found. May be NULL.
    #
    # @return 0 on success, a negative AVERROR on failure.
    #
    # @section lavf_decoding_open Opening a media file
    # The minimum information required to open a file is its URL or filename, which
    # is passed to avformat_open_input(), as in the following code:
    # @code
    # const char    *url = "in.mp3";
    # AVFormatContext *s = NULL;
    # int ret = avformat_open_input(&s, url, NULL, NULL);
    # if (ret < 0)
    #     abort();
    # @endcode
    int avformat_open_input(AVFormatContext **ps, char *filename, AVInputFormat *fmt, AVDictionary **options)

    # Read packets of a media file to get stream information. This
    # is useful for file formats with no headers such as MPEG. This
    # function also computes the real framerate in case of MPEG-2 repeat
    # frame mode.
    # The logical file position is not changed by this function;
    # examined packets may be buffered for later processing.
    #
    # @param ic media file handle
    # @param options  If non-NULL, an ic.nb_streams long array of pointers to
    #                 dictionaries, where i-th member contains options for
    #                 codec corresponding to i-th stream.
    #                 On return each dictionary will be filled with options that were not found.
    # @return >=0 if OK, AVERROR_xxx on error
    #
    # @note this function isn't guaranteed to open all the codecs, so
    #       options being non-empty at return is a perfectly normal behavior.
    #
    # @todo Let the user decide somehow what information is needed so that
    #       we do not waste time getting stuff the user does not need.
    int avformat_find_stream_info(AVFormatContext *ic, AVDictionary **options)

    # * Read packets of a media file to get stream information. This
    # * is useful for file formats with no headers such as MPEG. This
    # * function also computes the real framerate in case of MPEG-2 repeat
    # * frame mode.
    # * The logical file position is not changed by this function;
    # * examined packets may be buffered for later processing.
    # *
    # * @param ic media file handle
    # * @return >=0 if OK, AVERROR_xxx on error
    # * @todo Let the user decide somehow what information is needed so that
    # *       we do not waste time getting stuff the user does not need.
    #int av_find_stream_info(AVFormatContext *ic)
    # FIXME: use avformat_find_stream_info() instead 
    
    # * Read a transport packet from a media file.
    # *
    # * This function is obsolete and should never be used.
    # * Use av_read_frame() instead.
    # *
    # * @param s media file handle
    # * @param pkt is filled
    # * @return 0 if OK, AVERROR_xxx on error
    #int av_read_packet(AVFormatContext *s, AVPacket *pkt)
    # FIXME: not available anymore
 
    # Return the next frame of a stream.
    # This function returns what is stored in the file, and does not validate
    # that what is there are valid frames for the decoder. It will split what is
    # stored in the file into frames and return one for each call. It will not
    # omit invalid data between valid frames so as to give the decoder the maximum
    # information possible for decoding.
    #
    # If pkt->buf is NULL, then the packet is valid until the next
    # av_read_frame() or until avformat_close_input(). Otherwise the packet
    # is valid indefinitely. In both cases the packet must be freed with
    # av_free_packet when it is no longer needed. For video, the packet contains
    # exactly one frame. For audio, it contains an integer number of frames if each
    # frame has a known fixed size (e.g. PCM or ADPCM data). If the audio frames
    # have a variable size (e.g. MPEG audio), then it contains one frame.
    #
    # pkt->pts, pkt->dts and pkt->duration are always set to correct
    # values in AVStream.time_base units (and guessed if the format cannot
    # provide them). pkt->pts can be AV_NOPTS_VALUE if the video format
    # has B-frames, so it is better to rely on pkt->dts if you do not
    # decompress the payload.
    #
    # @return 0 if OK, < 0 on error or end of file
    int av_read_frame(AVFormatContext *s, AVPacket *pkt)
    
    # Seek to the keyframe at timestamp.
    # 'timestamp' in 'stream_index'.
    #
    # @param s media file handle
    # @param stream_index If stream_index is (-1), a default
    # stream is selected, and timestamp is automatically converted
    # from AV_TIME_BASE units to the stream specific time_base.
    # @param timestamp Timestamp in AVStream.time_base units
    #        or, if no stream is specified, in AV_TIME_BASE units.
    # @param flags flags which select direction and seeking mode
    # @return >= 0 on success
    int av_seek_frame(AVFormatContext *s, int stream_index, int64_t timestamp,
                  int flags)
    
    # Discard all internally buffered data
    int avformat_flush(AVFormatContext *s)
    
    # * Start playing a network-based stream (e.g. RTSP stream) at the
    # * current position.
    int av_read_play(AVFormatContext *s)

    # * Pause a network-based stream (e.g. RTSP stream).
    # * Use av_read_play() to resume it.
    int av_read_pause(AVFormatContext *s)
    
    # * Free a AVFormatContext allocated by av_open_input_stream.
    # * @param s context to free
    #void av_close_input_stream(AVFormatContext *s)
    # FIXME: use  avformat_close_input() instead
    
    # Close an opened input AVFormatContext. Free it and all its contents
    # and set *s to NULL.
    void avformat_close_input(AVFormatContext **s)

    # * Close a media file (but not its codecs).
    # * @param s media file handle
    #void av_close_input_file(AVFormatContext *s)
    # FIXME: use avformat_close_input() instead

    # * Add a new stream to a media file.
    # *
    # * Can only be called in the read_header() function. If the flag
    # * AVFMTCTX_NOHEADER is in the format context, then new streams
    # * can be added in read_packet too.
    # *
    # * @param s media file handle
    # * @param id file-format-dependent stream ID
    #AVStream *av_new_stream(AVFormatContext *s, int id)
    # FIXME: use avformat_new_stream() instead
    # Add a new stream to a media file
    AVStream *avformat_new_stream(AVFormatContext *s, AVCodec *c)
    AVProgram *av_new_program(AVFormatContext *s, int id)
    
    int av_find_default_stream_index(AVFormatContext *s)
    
    # Get the index for a specific timestamp.
    int av_index_search_timestamp(AVStream *st, int64_t timestamp, int flags)    

    # Add an index entry into a sorted list. Update the entry if the list
    # already contains it.
    int av_add_index_entry(AVStream *st, int64_t pos, int64_t timestamp,
                       int size, int distance, int flags)

    # * Perform a binary search using av_index_search_timestamp() and
    # * AVInputFormat.read_timestamp().
    # * This is not supposed to be called directly by a user application,
    # * but by demuxers.
    # * @param target_ts target timestamp in the time base of the given stream
    # * @param stream_index stream number
    #int av_seek_frame_binary(AVFormatContext *s, int stream_index,
    #                     int64_t target_ts, int flags)
    # FIXME: not available anymore
    
    # Print detailed information about the input or output format
    void av_dump_format(AVFormatContext *ic, int index, char *url, int is_output)

    # Allocate an AVFormatContext.
    # avformat_free_context() can be used to free the context and everything
    # allocated by the framework within it.
    AVFormatContext *avformat_alloc_context()

    AVCodecParserContext *av_stream_get_parser(AVStream *s)


##################################################################################
# ok libswscale    0. 12. 0 
cdef extern from "libswscale/swscale.h":
    cdef enum:
        SWS_FAST_BILINEAR,
        SWS_BILINEAR,
        SWS_BICUBIC,
        SWS_X,
        SWS_POINT,
        SWS_AREA,
        SWS_BICUBLIN,
        SWS_GAUSS,
        SWS_SINC,
        SWS_LANCZOS,
        SWS_SPLINE

    struct SwsContext:
        pass

    struct SwsFilter:
        pass

    # deprecated use sws_alloc_context() and sws_init_context()
    SwsContext *sws_getContext(int srcW, int srcH, int srcFormat, int dstW, int dstH, int dstFormat, int flags,SwsFilter *srcFilter, SwsFilter *dstFilter, double *param)
    #SwsContext *sws_alloc_context()
    #int sws_init_context(struct SwsContext *sws_context, SwsFilter *srcFilter, SwsFilter *dstFilter)
    void sws_freeContext(SwsContext *swsContext)
    int sws_scale(SwsContext *context, uint8_t* src[], int srcStride[], int srcSliceY,int srcSliceH, uint8_t* dst[], int dstStride[])


##################################################################################
# from Python.h
##################################################################################
cdef extern from "Python.h":
    ctypedef unsigned long size_t # TODO: or int?
    object PyBuffer_FromMemory( void *ptr, int size)
    object PyBuffer_FromReadWriteMemory( void *ptr, int size)
    object PyString_FromStringAndSize(char *s, int len)
    void* PyMem_Malloc( size_t n)
    void PyMem_Free( void *p)


def rwbuffer_at(pos,len):
    cdef unsigned long ptr=int(pos)
    return PyBuffer_FromReadWriteMemory(<void *>ptr,len)


##################################################################################
# General includes
##################################################################################
try:
    import numpy
    from pyffmpeg_numpybindings import *
except:
    numpy=None

try:
    import PIL
    from PIL import Image
except:
    Image=None


##################################################################################
# Utility elements
##################################################################################


# original definiton as define in libavutil/avutil.h
cdef AVRational AV_TIME_BASE_Q
AV_TIME_BASE_Q.num = 1
AV_TIME_BASE_Q.den = AV_TIME_BASE

AVFMT_NOFILE = 1

cdef av_read_frame_flush(AVFormatContext *s):
    cdef AVStream *st
    cdef int i
    cdef AVCodecParserContext *pc
    
    # flush the I/O context
    avio_flush(s.pb)
    # discard all internally buffered data
    avformat_flush(s)
    
    for i in range(s.nb_streams):
        st = s.streams[i]
        pc = av_stream_get_parser(st)
        if (pc):
            av_parser_close(pc)
            pc.parser = NULL
            #st.last_IP_pts = AV_NOPTS_VALUE
            #st.cur_dts = 0

# originally defined in mpegvideo.h
def IS_INTRA4x4(a):
    return (((a)&MB_TYPE_INTRA4x4)>0)*1
def IS_INTRA16x16(a):
    return (((a)&MB_TYPE_INTRA16x16)>0)*1
def IS_PCM(a):        
    return (((a)&MB_TYPE_INTRA_PCM)>0)*1
def IS_INTRA(a):      
    return (((a)&7)>0)*1
def IS_INTER(a):      
    return (((a)&(MB_TYPE_16x16|MB_TYPE_16x8|MB_TYPE_8x16|MB_TYPE_8x8))>0)*1
def IS_SKIP(a):       
    return (((a)&MB_TYPE_SKIP)>0)*1
def IS_INTRA_PCM(a):  
    return (((a)&MB_TYPE_INTRA_PCM)>0)*1
def IS_INTERLACED(a): 
    return (((a)&MB_TYPE_INTERLACED)>0)*1
def IS_DIRECT(a):     
    return (((a)&MB_TYPE_DIRECT2)>0)*1
def IS_GMC(a):        
    return (((a)&MB_TYPE_GMC)>0)*1
def IS_16x16(a):      
    return (((a)&MB_TYPE_16x16)>0)*1
def IS_16x8(a):       
    return (((a)&MB_TYPE_16x8)>0)*1
def IS_8x16(a):       
    return (((a)&MB_TYPE_8x16)>0)*1
def IS_8x8(a):        
    return (((a)&MB_TYPE_8x8)>0)*1
def IS_SUB_8x8(a):    
    return (((a)&MB_TYPE_16x16)>0)*1 #note reused
def IS_SUB_8x4(a):    
    return (((a)&MB_TYPE_16x8)>0)*1  #note reused
def IS_SUB_4x8(a):    
    return (((a)&MB_TYPE_8x16)>0)*1  #note reused
def IS_SUB_4x4(a):    
    return (((a)&MB_TYPE_8x8)>0)*1   #note reused
def IS_DIR(a, part, whichlist):
    return (((a) & (MB_TYPE_P0L0<<((part)+2*(whichlist))))>0)*1
def USES_LIST(a, whichlist):
    return (((a) & ((MB_TYPE_P0L0|MB_TYPE_P1L0)<<(2*(whichlist))))>0)*1 #< does this mb use listX, note does not work if subMBs


##################################################################################
## AudioQueue Object  (This may later be exported with another object)
##################################################################################
cdef DEBUG(s):
    sys.stderr.write("DEBUG: %s\n"%(s,))
    sys.stderr.flush()

## contains pairs of timestamp, array
try:
    from audioqueue import AudioQueue, Queue_Empty, Queue_Full
except:
    pass


##################################################################################
# Initialization
##################################################################################

# Initialize libavformat and register all the muxers, demuxers and
# protocols
cdef __registered
__registered = 0
if not __registered:
    __registered = 1
    av_register_all()


##################################################################################
# Some default settings
##################################################################################
TS_AUDIOVIDEO={'video1':(CODEC_TYPE_VIDEO, -1,  {}), 'audio1':(CODEC_TYPE_AUDIO, -1, {})}
TS_AUDIO={ 'audio1':(CODEC_TYPE_AUDIO, -1, {})}
TS_VIDEO={ 'video1':(CODEC_TYPE_VIDEO, -1, {})}
TS_VIDEO_PIL={ 'video1':(CODEC_TYPE_VIDEO, -1, {'outputmode':OUTPUTMODE_PIL})}


###############################################################################
## The Abstract Reader Class
###############################################################################
cdef class AFFMpegReader:
    """ Abstract version of FFMpegReader"""
    ### File
    cdef object filename
    ### used when streaming
    cdef AVIOContext *io_context
    ### Tracks contained in the file
    cdef object tracks
    cdef void * ctracks
    ### current timing
    cdef float opts ## orginal pts recoded as a float
    cdef unsigned long long int pts
    cdef unsigned long long int dts
    cdef unsigned long long int errjmppts # when trying to skip over buggy area
    cdef unsigned long int frameno
    cdef float fps # real frame per seconds (not declared one)
    cdef float tps # ticks per seconds

    cdef AVPacket * packet
    cdef AVPacket * prepacket
    cdef AVPacket packetbufa
    cdef AVPacket packetbufb
    cdef int altpacket
    #
    cdef bint observers_enabled

    cdef AVFormatContext *FormatCtx
 #   self.prepacket=<AVPacket *>None
#   self.packet=&self.packetbufa

    def __cinit__(self):
        pass

    def dump(self):
        pass

    def open(self,char *filename, track_selector={'video1':(CODEC_TYPE_VIDEO, -1), 'audio1':(CODEC_TYPE_AUDIO, -1)}):
        pass

    def close(self):
        pass

    cdef read_packet(self):
        print "FATAL Error This function is abstract and should never be called, it is likely that you compiled pyffmpeg with a too old version of pyffmpeg !!!"
        print "Try running 'easy_install -U cython' and rerun the pyffmpeg2 install"
        assert(False)

    def process_current_packet(self):
        pass

    def __prefetch_packet(self):
        pass

    def read_until_next_frame(self):
        pass

cdef class Track:
    """
     A track is used for memorizing all the aspect related to
     Video, or an Audio Track.

     Practically a Track is managing the decoder context for itself.
    """
    cdef AFFMpegReader vr
    cdef int no
    ## cdef AVFormatContext *FormatCtx
    cdef AVCodecContext *CodecCtx
    cdef AVCodec *Codec
    cdef AVOptions *codec_options
    cdef AVFrame *frame
    cdef AVStream *stream
    cdef long start_time
    cdef object packet_queue
    cdef frame_queue
    cdef unsigned long long int pts
    cdef unsigned long long int last_pts
    cdef unsigned long long int last_dts
    cdef object observer
    cdef int support_truncated
    cdef int do_check_start
    cdef int do_check_end
    cdef int reopen_codec_on_buffer_reset

    cdef __new__(Track self):
        self.vr=None
        self.observer=None
        self.support_truncated=1
        self.reopen_codec_on_buffer_reset=1

    def get_no(self):
        """Returns the number of the tracks."""
        return self.no

    def __len__(self):
        """Returns the number of data frames on this track."""
        return self.stream.nb_frames

    def duration(self):
        """Return the duration of one track in PTS"""
        if (self.stream.duration==0x8000000000000000):
            raise KeyError
        return self.stream.duration

    def _set_duration(self,x):
        """Allows to set the duration to correct inconsistent information"""
        self.stream.duration=x

    def duration_time(self):
        """ returns the duration of one track in seconds."""
        return float(self.duration())/ (<float>AV_TIME_BASE)

    cdef init0(Track self,  AFFMpegReader vr,int no, AVCodecContext *CodecCtx):
        """ This is a private constructor """
        self.vr=vr
        self.CodecCtx=CodecCtx
        self.no=no
        self.stream = self.vr.FormatCtx.streams[self.no]
        self.frame_queue=[]
        self.Codec = avcodec_find_decoder(self.CodecCtx.codec_id)
        self.frame = avcodec_alloc_frame()
        self.start_time=self.stream.start_time
        self.do_check_start=0
        self.do_check_end=0


    def init(self, observer=None, support_truncated=0, **args):
        """ This is a private constructor

            It supports also the following parameted from ffmpeg
            skip_frame
            skip_idct
            skip_loop_filter
            hurry_up
            dct_algo
            idct_algo

            To set all value for keyframes_only
            just set up hurry_mode to any value.
        """
        self.observer=None
        self.support_truncated=support_truncated
        for k in args.keys():
            if k not in [ "skip_frame", "skip_loop_filter", "skip_idct", "hurry_up", "hurry_mode", "dct_algo", "idct_algo", "check_start" ,"check_end"]:
                sys.stderr.write("warning unsupported arguments in stream initialization :"+k+"\n")
        if self.Codec == NULL:
            raise IOError("Unable to get decoder")
        if (self.Codec.capabilities & CODEC_CAP_TRUNCATED) and (self.support_truncated!=0):
            self.CodecCtx.flags = self.CodecCtx.flags | CODEC_FLAG_TRUNCATED

        # FIXME: self.codec_options allocated and to be nulled?
        if avcodec_open2(self.CodecCtx, self.Codec, self.codec_options) < 0:
            raise Exception("Cannot open codec")
        
        if args.has_key("hurry_mode"):
            # discard all frames except keyframes
            self.CodecCtx.skip_loop_filter = AVDISCARD_NONKEY
            self.CodecCtx.skip_frame = AVDISCARD_NONKEY
            self.CodecCtx.skip_idct = AVDISCARD_NONKEY
            # deprecated
            # 1-> Skip B-frames, 2-> Skip IDCT/dequant too, 5-> Skip everything except header
            self.CodecCtx.hurry_up=2  
        if args.has_key("skip_frame"):
            self.CodecCtx.skip_frame=args["skip_frame"]
        if args.has_key("skip_idct"):
            self.CodecCtx.skip_idct=args["skip_idct"]
        if args.has_key("skip_loop_filter"):
            self.CodecCtx.skip_loop_filter=args["skip_loop_filter"]
        if args.has_key("hurry_up"):
            self.CodecCtx.skip_loop_filter=args["hurry_up"]
        if args.has_key("dct_algo"):
            self.CodecCtx.dct_algo=args["dct_algo"]
        if args.has_key("idct_algo"):
            self.CodecCtx.idct_algo=args["idct_algo"]
        if not args.has_key("check_start"): 
            self.do_check_start=1
        else:
            self.do_check_start=args["check_start"]
        if (args.has_key("check_end") and args["check_end"]):
            self.do_check_end=0


    def check_start(self):
        """ It seems that many file have incorrect initial time information.
            The best way to avoid offset in shifting is thus to check what
            is the time of the beginning of the track.
        """
        if (self.do_check_start):
            try:
                self.seek_to_pts(0)
                self.vr.read_until_next_frame()
                sys.stderr.write("start time checked : pts = %d , declared was : %d\n"%(self.pts,self.start_time))
                self.start_time=self.pts
                self.seek_to_pts(0)
                self.do_check_start=0
            except Exception,e:
                #DEBUG("check start FAILED " + str(e))
                pass
        else:
            pass


    def check_end(self):
        """ It seems that many file have incorrect initial time information.
            The best way to avoid offset in shifting is thus to check what
            is the time of the beginning of the track.
        """
        if (self.do_check_end):
            try:
                self.vr.packetbufa.dts=self.vr.packetbufa.pts=self.vr.packetbufb.dts=self.vr.packetbufb.pts=0
                self.seek_to_pts(0x00FFFFFFFFFFFFF)
                self.vr.read_packet()
                try:
                    dx=self.duration()
                except:
                    dx=-1
                newend=max(self.vr.packetbufa.dts,self.vr.packetbufa.pts,self.vr.packetbufb.dts)
                sys.stderr.write("end time checked : pts = %d, declared was : %d\n"%(newend,dx))
                assert((newend-self.start_time)>=0)
                self._set_duration((newend-self.start_time))
                self.vr.reset_buffers()
                self.seek_to_pts(0)
                self.do_check_end=0
            except Exception,e:
                DEBUG("check end FAILED " + str(e))
                pass
        else:
            #DEBUG("no check end " )
            pass

    def set_observer(self, observer=None):
        """ An observer is a callback function that is called when a new
            frame of data arrives.

            Using this function you may setup the function to be called when
            a frame of data is decoded on that track.
        """
        self.observer=observer

    def _reopencodec(self):
        """
          This is used to reset the codec context.
          Very often, this is the safest way to get everything clean
          when seeking.
        """
        if (self.CodecCtx!=NULL):
            avcodec_close(self.CodecCtx)
        self.CodecCtx=NULL
        self.CodecCtx = self.vr.FormatCtx.streams[self.no].codec
        self.Codec = avcodec_find_decoder(self.CodecCtx.codec_id)
        if self.Codec == NULL:
            raise IOError("Unable to get decoder")
        if (self.Codec.capabilities & CODEC_CAP_TRUNCATED) and (self.support_truncated!=0):
            self.CodecCtx.flags = self.CodecCtx.flags | CODEC_FLAG_TRUNCATED
        ret = avcodec_open(self.CodecCtx, self.Codec)

    def close(self):
        """
           This closes the track. And thus closes the context."
        """
        if (self.CodecCtx!=NULL):
            avcodec_close(self.CodecCtx)
        self.CodecCtx=NULL

    def prepare_to_read_ahead(self):
        """
        In order to avoid delay during reading, our player try always
        to read a little bit of that is available ahead.
        """
        pass

    def reset_buffers(self):
        """
        This function is used on seek to reset everything.
        """
        self.pts=0
        self.last_pts=0
        self.last_dts=0
        if (self.CodecCtx!=NULL):
            avcodec_flush_buffers(self.CodecCtx)
        ## violent solution but the most efficient so far...
        if (self.reopen_codec_on_buffer_reset):
            self._reopencodec()

    #  cdef process_packet(self, AVPacket * pkt):
    #      print "FATAL : process_packet : Error This function is abstract and should never be called, it is likely that you compiled pyffmpeg with a too old version of pyffmpeg !!!"
    #      print "Try running 'easy_install -U cython' and rerun the pyffmpeg2 install"
    #      assert(False)

    def seek_to_seconds(self, seconds ):
        """ Seek to the specified time in seconds.

            Note that seeking is always bit more complicated when we want to be exact.
            * We do not use any precomputed index structure for seeking (which would make seeking exact)
            * Due to codec limitations, FFMPEG often provide approximative seeking capabilites
            * Sometimes "time data" in video file are invalid
            * Sometimes "seeking is simply not possible"

            We are working on improving our seeking capabilities.
        """
        pts = (<float>seconds) * (<float>AV_TIME_BASE)
        #pts=av_rescale(seconds*AV_TIME_BASE, self.stream.time_base.den, self.stream.time_base.num*AV_TIME_BASE)
        self.seek_to_pts(pts)

    def seek_to_pts(self,  unsigned long long int pts):
        """ Seek to the specified PTS

            Note that seeking is always bit more complicated when we want to be exact.
            * We do not use any precomputed index structure for seeking (which would make seeking exact)
            * Due to codec limitations, FFMPEG often provide approximative seeking capabilites
            * Sometimes "time data" in video file are invalid
            * Sometimes "seeking is simply not possible"

            We are working on improving our seeking capabilities.
        """

        if (self.start_time!=AV_NOPTS_VALUE):
            pts+=self.start_time


        self.vr.seek_to(pts)



cdef class AudioPacketDecoder:
    cdef uint8_t *audio_pkt_data
    cdef int audio_pkt_size

    cdef __new__(self):
        self.audio_pkt_data =<uint8_t *>NULL
        self.audio_pkt_size=0

    cdef int audio_decode_frame(self,  AVCodecContext *aCodecCtx,
            uint8_t *audio_buf,  int buf_size, double * pts_ptr, 
            double * audio_clock, int nchannels, int samplerate, AVPacket * pkt, int first) :
        cdef double pts
        cdef int n
        cdef int len1
        cdef int data_size

        
        data_size = buf_size
        #print "datasize",data_size
        len1 = avcodec_decode_audio3(aCodecCtx, <int16_t *>audio_buf, &data_size, pkt)
        if(len1 < 0) :
                raise IOError,("Audio decoding error (i)",len1)
        if(data_size < 0) :
                raise IOError,("Audio decoding error (ii)",data_size)

        #We have data, return it and come back for more later */
        pts = audio_clock[0]
        pts_ptr[0] = pts
        n = 2 * nchannels
        audio_clock[0] += ((<double>data_size) / (<double>(n * samplerate)))
        return data_size


###############################################################################
## The AudioTrack Class
###############################################################################


cdef class AudioTrack(Track):
    cdef object audioq   #< This queue memorize the data to be reagglomerated
    cdef object audiohq  #< This queue contains the audio packet for hardware devices
    cdef double clock    #< Just a clock
    cdef AudioPacketDecoder apd
    cdef float tps
    cdef int data_size
    cdef int rdata_size
    cdef int sdata_size
    cdef int dest_frame_overlap #< If you want to computer spectrograms it may be useful to have overlap in-between data
    cdef int dest_frame_size
    cdef int hardware_queue_len
    cdef object lf
    cdef int os
    cdef object audio_buf # buffer used in decoding of  audio

    def init(self, tps=30, hardware_queue_len=5, dest_frame_size=0, dest_frame_overlap=0, **args):
        """
        The "tps" denotes the assumed frame per seconds.
        This is use to synchronize the emission of audio packets with video packets.

        The hardware_queue_len, denotes the output audio queue len, in this queue all packets have a size determined by dest_frame_size or tps

        dest_frame_size specifies the size of desired audio frames,
        when dest_frame_overlap is not null some datas will be kept in between
        consecutive audioframes, this is useful for computing spectrograms.

        """
        assert (numpy!=None), "NumPy must be available for audio support to work. Please install numpy."
        Track.init(self,  **args)
        self.tps=tps
        self.hardware_queue_len=hardware_queue_len
        self.dest_frame_size=dest_frame_size
        self.dest_frame_overlap=dest_frame_overlap

        #
        # audiohq =
        # hardware queue : agglomerated and time marked packets of a specific size (based on audioq)
        #
        self.audiohq=AudioQueue(limitsz=self.hardware_queue_len)
        self.audioq=AudioQueue(limitsz=12,tps=self.tps,
                              samplerate=self.CodecCtx.sample_rate,
                              destframesize=self.dest_frame_size if (self.dest_frame_size!=0) else (self.CodecCtx.sample_rate//self.tps),
                              destframeoverlap=self.dest_frame_overlap,
                              destframequeue=self.audiohq)



        self.data_size=AVCODEC_MAX_AUDIO_FRAME_SIZE # ok let's try for try
        self.sdata_size=0
        self.rdata_size=self.data_size-self.sdata_size
        self.audio_buf=numpy.ones((AVCODEC_MAX_AUDIO_FRAME_SIZE,self.CodecCtx.channels),dtype=numpy.int16 )
        self.clock=0
        self.apd=AudioPacketDecoder()
        self.os=0
        self.lf=None

    def reset_tps(self,tps):
        self.tps=tps
        self.audiohq=AudioQueue(limitsz=self.hardware_queue_len)  # hardware queue : agglomerated and time marked packets of a specific size (based on audioq)
        self.audioq=AudioQueue(limitsz=12,tps=self.tps,
                              samplerate=self.CodecCtx.sample_rate,
                              destframesize=self.dest_frame_size if (self.dest_frame_size!=0) else (self.CodecCtx.sample_rate//self.tps),
#                              destframesize=self.dest_frame_size or (self.CodecCtx.sample_rate//self.tps),
                              destframeoverlap=self.dest_frame_overlap,
                              destframequeue=self.audiohq)


    def get_cur_pts(self):
        return self.last_pts

    def reset_buffers(self):
        ## violent solution but the most efficient so far...
        Track.reset_buffers(self)
        try:
            while True:
                self.audioq.get()
        except Queue_Empty:
            pass
        try:
            while True:
                self.audiohq.get()
        except Queue_Empty:
            pass
        self.apd=AudioPacketDecoder()

    def get_channels(self):
        """ Returns the number of channels of the AudioTrack."""
        return self.CodecCtx.channels

    def get_samplerate(self):
        """ Returns the samplerate of the AudioTrack."""
        return self.CodecCtx.sample_rate

    def get_audio_queue(self):
        """ Returns the audioqueue where received packets are agglomerated to form
            audio frames of the desired size."""
        return self.audioq

    def get_audio_hardware_queue(self):
        """ Returns the audioqueue where data are stored while waiting to be used by user."""
        return self.audiohq

    def __read_subsequent_audio(self):
        """ This function is used internally to do some read ahead.

        we will push in the audio queue the datas that appear after a specified frame,
        or until the audioqueue is full
        """
        calltrack=self.get_no()
        #DEBUG("read_subsequent_audio")
        if (self.vr.tracks[0].get_no()==self.get_no()):
            calltrack=-1
        self.vr.read_until_next_frame(calltrack=calltrack)
        #self.audioq.print_buffer_stats()

    cdef process_packet(self, AVPacket * pkt):
        cdef double xpts
        self.rdata_size=self.data_size
        lf=2
        audio_size=self.rdata_size*lf

        first=1
        #DEBUG( "process packet size=%s pts=%s dts=%s "%(str(pkt.size),str(pkt.pts),str(pkt.dts)))
        #while or if? (see version 2.0)
        if (audio_size>0):
            audio_size=self.rdata_size*lf
            audio_size = self.apd.audio_decode_frame(self.CodecCtx,
                                      <uint8_t *> <unsigned long long> (PyArray_DATA_content( self.audio_buf)),
                                      audio_size,
                                      &xpts,
                                      &self.clock,
                                      self.CodecCtx.channels,
                                      self.CodecCtx.sample_rate,
                                      pkt,
                                      first)
            first=0
            if (audio_size>0):
                self.os+=1
                audio_start=0
                len1 = audio_size
                bb= ( audio_start )//lf
                eb= ( audio_start +(len1//self.CodecCtx.channels) )//lf
                if pkt.pts == AV_NOPTS_VALUE:
                    pts = pkt.dts
                else:
                    pts = pkt.pts
                opts=pts
                #self.pts=pts
                self.last_pts=av_rescale(pkt.pts,AV_TIME_BASE * <int64_t>self.stream.time_base.num,self.stream.time_base.den)
                self.last_dts=av_rescale(pkt.dts,AV_TIME_BASE * <int64_t>self.stream.time_base.num,self.stream.time_base.den)
                xpts= av_rescale(pts,AV_TIME_BASE * <int64_t>self.stream.time_base.num,self.stream.time_base.den)
                xpts=float(pts)/AV_TIME_BASE
                cb=self.audio_buf[bb:eb].copy()
                self.lf=cb
                self.audioq.putforce((cb,pts,float(opts)/self.tps)) ## this audio q is for processing
                #print ("tp [%d:%d]/as:%d/bs:%d:"%(bb,eb,audio_size,self.Adata_size))+str(cb.mean())+","+str(cb.std())
                self.rdata_size=self.data_size
        if (self.observer):
            try:
                while (True) :
                    x=self.audiohq.get_nowait()
                    if (self.vr.observers_enabled):
                        self.observer(x)
            except Queue_Empty:
                pass

    def prepare_to_read_ahead(self):
        """ This function is used internally to do some read ahead """
        self.__read_subsequent_audio()

    def get_next_frame(self):
        """
        Reads a packet and return last decoded frame.

        NOTE : Usage of this function is discouraged for now.

        TODO : Check again this function
        """
        os=self.os
        #DEBUG("AudioTrack : get_next_frame")
        while (os==self.os):
            self.vr.read_packet()
        #DEBUG("/AudioTrack : get_next_frame")
        return self.lf

    def get_current_frame(self):
        """
          Reads audio packet so that the audioqueue contains enough data for
          one one frame, and then decodes that frame

          NOTE : Usage of this function is discouraged for now.

          TODO : this approximative yet
          TODO : this shall use the hardware queue
        """

        dur=int(self.get_samplerate()//self.tps)
        while (len(self.audioq)<dur):
            self.vr.read_packet()
        return self.audioq[0:dur]

    def print_buffer_stats(self):
        ##
        ##
        ##
        self.audioq.print_buffer_stats("audio queue")






###############################################################################
## The VideoTrack Class
###############################################################################


cdef class VideoTrack(Track):
    """
        VideoTrack implement a video codec to access the videofile.

        VideoTrack reads in advance up to videoframebanksz frames in the file.
        The frames are put in a temporary pool with their presentation time.
        When the next image is queried the system look at for the image the most likely to be the next one...
    """

    cdef int outputmode
    cdef AVPixelFormat pixel_format
    cdef int frameno
    cdef int videoframebanksz
    cdef object videoframebank ### we use this to reorder image though time
    cdef object videoframebuffers ### TODO : Make use of these buffers
    cdef int videobuffers
    cdef int hurried_frames
    cdef int width
    cdef int height
    cdef int dest_height
    cdef int dest_width
    cdef int with_motion_vectors
    cdef  SwsContext * convert_ctx




    def init(self, pixel_format=PIX_FMT_NONE, videoframebanksz=1, dest_width=-1, dest_height=-1,videobuffers=2,outputmode=OUTPUTMODE_NUMPY,with_motion_vectors=0,** args):
        """ Construct a video track decoder for a specified image format

            You may specify :

            pixel_format to force data to be in a specified pixel format.
            (note that only array like formats are supported, i.e. no YUV422)

            dest_width, dest_height in order to force a certain size of output

            outputmode : 0 for numpy , 1 for PIL

            videobuffers : Number of video buffers allocated
            videoframebanksz : Number of decoded buffers to be kept in memory

            It supports also the following parameted from ffmpeg
            skip_frame
            skip_idct
            skip_loop_filter
            hurry_up
            dct_algo
            idct_algo

            To set all value for keyframes_only
            just set up hurry_mode to any value.

        """
        cdef int numBytes
        Track.init(self,  **args)
        self.outputmode=outputmode
        self.pixel_format=pixel_format
        if (self.pixel_format==PIX_FMT_NONE):
            self.pixel_format=PIX_FMT_RGB24
        self.videoframebank=[]
        self.videoframebanksz=videoframebanksz
        self.videobuffers=videobuffers
        self.with_motion_vectors=with_motion_vectors
        if self.with_motion_vectors:
            self.CodecCtx.debug = FF_DEBUG_MV | FF_DEBUG_MB_TYPE        
        self.width = self.CodecCtx.width
        self.height = self.CodecCtx.height
        self.dest_width=(dest_width==-1) and self.width or dest_width
        self.dest_height=(dest_height==-1) and self.height or dest_height
        numBytes=avpicture_get_size(self.pixel_format, self.dest_width, self.dest_height)
        #print  "numBytes", numBytes,self.pixel_format,
        if (outputmode==OUTPUTMODE_NUMPY):
            #print "shape", (self.dest_height, self.dest_width,numBytes/(self.dest_width*self.dest_height))
            self.videoframebuffers=[ numpy.zeros(shape=(self.dest_height, self.dest_width,
                                                        numBytes/(self.dest_width*self.dest_height)),  dtype=numpy.uint8)      for i in range(self.videobuffers) ]
        else:
            assert self.pixel_format==PIX_FMT_RGB24, "While using PIL only RGB pixel format is supported by pyffmpeg"
            self.videoframebuffers=[ Image.new("RGB",(self.dest_width,self.dest_height)) for i in range(self.videobuffers) ]
        self.convert_ctx = sws_getContext(self.width, self.height, self.CodecCtx.pix_fmt, self.dest_width,self.dest_height,self.pixel_format, SWS_BILINEAR, NULL, NULL, NULL)
        if self.convert_ctx == NULL:
            raise MemoryError("Unable to allocate scaler context")


    def reset_buffers(self):
        """ Reset the internal buffers. """

        Track.reset_buffers(self)
        for x in self.videoframebank:
            self.videoframebuffers.append(x[2])
        self.videoframebank=[]


    def print_buffer_stats(self):
        """ Display some informations on internal buffer system """

        print "video buffers :", len(self.videoframebank), " used out of ", self.videoframebanksz


    def get_cur_pts(self):

        return self.last_pts



    def get_orig_size(self) :
        """ return the size of the image in the current video track """

        return (self.width,  self.height)


    def get_size(self) :
        """ return the size of the image in the current video track """

        return (self.dest_width,  self.dest_height)


    def close(self):
        """ closes the track and releases the video decoder """

        Track.close(self)
        if (self.convert_ctx!=NULL):
            sws_freeContext(self.convert_ctx)
        self.convert_ctx=NULL


    cdef _read_current_macroblock_types(self, AVFrame *f):
        cdef int mb_width
        cdef int mb_height
        cdef int mb_stride

        mb_width = (self.width+15)>>4
        mb_height = (self.height+15)>>4
        mb_stride = mb_width + 1

        #if (self.CodecCtx.codec_id == CODEC_ID_MPEG2VIDEO) && (self.CodecCtx.progressive_sequence!=0)
        #    mb_height = (self.height + 31) / 32 * 2
        #elif self.CodecCtx.codec_id != CODEC_ID_H264
        #    mb_height = self.height + 15) / 16;

        res = numpy.zeros((mb_height,mb_width), dtype=numpy.uint32)

        if ((<void*>f.mb_type)==NULL):
            print "no mb_type available"
            return None           

        cdef int x,y
        for x in range(mb_width):
            for y in range(mb_height):
                res[y,x]=f.mb_type[x + y*mb_stride]
        return res


    cdef _read_current_motion_vectors(self,AVFrame * f):
        cdef int mv_sample_log2
        cdef int mb_width
        cdef int mb_height
        cdef int mv_stride

        mv_sample_log2 = 4 - f.motion_subsample_log2
        mb_width = (self.width+15)>>4
        mb_height = (self.height+15)>>4
        mv_stride = (mb_width << mv_sample_log2)
        if self.CodecCtx.codec_id != CODEC_ID_H264:
            mv_stride += 1
        res = numpy.zeros((mb_height<<mv_sample_log2,mb_width<<mv_sample_log2,2), dtype=numpy.int16)

        # TODO: support also backward prediction
        
        if ((<void*>f.motion_val[0])==NULL):
            print "no motion_val available"
            return None
        
        cdef int x,y,xydirection,preddirection    
        preddirection = 0
        for xydirection in range(2):
            for x in range(2*mb_width):
                for y in range(2*mb_height):
                    res[y,x,xydirection]=f.motion_val[preddirection][x + y*mv_stride][xydirection]
        return res


    cdef _read_current_ref_index(self, AVFrame *f):
        # HAS TO BE DEBUGGED
        cdef int mv_sample_log2
        cdef int mv_width
        cdef int mv_height
        cdef int mv_stride

        mv_sample_log2= 4 - f.motion_subsample_log2
        mb_width= (self.width+15)>>4
        mb_height= (self.height+15)>>4
        mv_stride= (mb_width << mv_sample_log2) + 1
        res = numpy.zeros((mb_height,mb_width,2), dtype=numpy.int8)

        # currently only forward predicition is supported
        if ((<void*>f.ref_index[0])==NULL):
            print "no ref_index available"
            return None

        cdef int x,y,xydirection,preddirection,mb_stride
        mb_stride = mb_width + 1
        
#00524     s->mb_stride = mb_width + 1;
#00525     s->b8_stride = s->mb_width*2 + 1;
#00526     s->b4_stride = s->mb_width*4 + 1;

        # currently only forward predicition is supported
        preddirection = 0
        for xydirection in range(2):
            for x in range(mb_width):
                for y in range(mb_height):
                    res[y,x]=f.ref_index[preddirection][x + y*mb_stride]
        return res
        
        
    cdef process_packet(self, AVPacket *packet):

        cdef int frameFinished=0
        ret = avcodec_decode_video2(self.CodecCtx,self.frame,&frameFinished,packet)
        #DEBUG( "process packet size=%s pts=%s dts=%s keyframe=%d picttype=%d"%(str(packet.size),str(packet.pts),str(packet.dts),self.frame.key_frame,self.frame.pict_type))
        if ret < 0:
                #DEBUG("IOError")
            raise IOError("Unable to decode video picture: %d" % (ret,))
        if (frameFinished):
            #DEBUG("frame finished")
            self.on_frame_finished()
        self.last_pts=av_rescale(packet.pts,AV_TIME_BASE * <int64_t>self.stream.time_base.num,self.stream.time_base.den)
        self.last_dts=av_rescale(packet.dts,AV_TIME_BASE * <int64_t>self.stream.time_base.num,self.stream.time_base.den)
        #DEBUG("/__nextframe")

    #########################################
    ### FRAME READING RELATED ISSUE
    #########################################


    def get_next_frame(self):
        """ reads the next frame and observe it if necessary"""

        #DEBUG("videotrack get_next_frame")
        self.__next_frame()
        #DEBUG("__next_frame done")
        am=self.smallest_videobank_time()
        #print am
        f=self.videoframebank[am][2]
        if (self.vr.observers_enabled):
            if (self.observer):
                self.observer(f)
        #DEBUG("/videotack get_next_frame")
        return f



    def get_current_frame(self):
        """ return the image with the smallest time index among the not yet displayed decoded frame """

        am=self.safe_smallest_videobank_time()
        return self.videoframebank[am]



    def _internal_get_current_frame(self):
        """
            This function is normally not aimed to be called by user it essentially does a conversion in-between the picture that is being decoded...
        """

        cdef AVFrame *pFrameRes
        cdef int numBytes
        if self.outputmode==OUTPUTMODE_NUMPY:
            img_image=self.videoframebuffers.pop()
            pFrameRes = self._convert_withbuf(<AVPicture *>self.frame,<char *><unsigned long long>PyArray_DATA_content(img_image))
        else:
            img_image=self.videoframebuffers.pop()
            bufferdata="\0"*(self.dest_width*self.dest_height*3)
            pFrameRes = self._convert_withbuf(<AVPicture *>self.frame,<char *>bufferdata)
            img_image.fromstring(bufferdata)
        av_free(pFrameRes)
        return img_image



    def _get_current_frame_without_copy(self,numpyarr):
        """
            This function is normally returns without copying it the image that is been read
            TODO: Make this work at the correct time (not at the position at the preload cursor)
        """

        cdef AVFrame *pFrameRes
        cdef int numBytes
        numBytes=avpicture_get_size(self.pixel_format, self.CodecCtx.width, self.CodecCtx.height)
        if (self.numpy):
            pFrameRes = self._convert_withbuf(<AVPicture *>self.frame,<char *><unsigned long long>PyArray_DATA_content(numpyarr))
        else:
            raise Exception, "Not yet implemented" # TODO : <



    def on_frame_finished(self):
        #DEBUG("on frame finished")
        if self.vr.packet.pts == AV_NOPTS_VALUE:
            pts = self.vr.packet.dts
        else:
            pts = self.vr.packet.pts
        self.pts = av_rescale(pts,AV_TIME_BASE * <int64_t>self.stream.time_base.num,self.stream.time_base.den)
        #print "unparsed pts", pts,  self.stream.time_base.num,self.stream.time_base.den,  self.pts
        self.frameno += 1
        pict_type = self.frame.pict_type
        if (self.with_motion_vectors):
            motion_vals = self._read_current_motion_vectors(self.frame)
            mb_type = self._read_current_macroblock_types(self.frame)
            ref_index = self._read_current_ref_index(self.frame)
        else:
            motion_vals = None
            mb_type = None
            ref_index = None
        self.videoframebank.append((self.pts, 
                                    self.frameno,
                                    self._internal_get_current_frame(),
                                    pict_type,
                                    mb_type,
                                    motion_vals,
                                    ref_index))
        # DEBUG this
        if (len(self.videoframebank)>self.videoframebanksz):
            self.videoframebuffers.append(self.videoframebank.pop(0)[2])
        #DEBUG("/on_frame_finished")

    def __next_frame(self):
        cdef int fno
        cfno=self.frameno
        while (cfno==self.frameno):
            #DEBUG("__nextframe : reading packet...")
            self.vr.read_packet()
        return self.pts
        #return av_rescale(pts,AV_TIME_BASE * <int64_t>Track.time_base.num,Track.time_base.den)






    ########################################
    ### videoframebank management
    #########################################

    def prefill_videobank(self):
        """ Use for read ahead : fill in the video buffer """

        if (len(self.videoframebank)<self.videoframebanksz):
            self.__next_frame()



    def refill_videobank(self,no=0):
        """ empty (partially) the videobank and refill it """

        if not no:
            for x in self.videoframebank:
                self.videoframebuffers.extend(x[2])
            self.videoframebank=[]
            self.prefill_videobank()
        else:
            for i in range(self.videoframebanksz-no):
                self.__next_frame()



    def smallest_videobank_time(self):
        """ returns the index of the frame in the videoframe bank that have the smallest time index """

        mi=0
        if (len(self.videoframebank)==0):
            raise Exception,"empty"
        vi=self.videoframebank[mi][0]
        for i in range(1,len(self.videoframebank)):
            if (vi<self.videoframebank[mi][0]):
                mi=i
                vi=self.videoframebank[mi][0]
        return mi



    def prepare_to_read_ahead(self):
        """ generic function called after seeking to prepare the buffer """
        self.prefill_videobank()


    ########################################
    ### misc
    #########################################

    def _finalize_seek(self, rtargetPts):
        while True:
            self.__next_frame()
#           if (self.debug_seek):
#             sys.stderr.write("finalize_seek : %d\n"%(self.pts,))
            if self.pts >= rtargetPts:
                break


    def set_hurry(self, b=1):
        #if we hurry it we can get bad frames later in the GOP
        if (b) :
            self.CodecCtx.skip_idct = AVDISCARD_BIDIR
            self.CodecCtx.skip_frame = AVDISCARD_BIDIR
            self.CodecCtx.hurry_up = 1
            self.hurried_frames = 0
        else:
            self.CodecCtx.skip_idct = AVDISCARD_DEFAULT
            self.CodecCtx.skip_frame = AVDISCARD_DEFAULT
            self.CodecCtx.hurry_up = 0

    ########################################
    ###
    ########################################


    cdef AVFrame *_convert_to(self,AVPicture *frame, AVPixelFormat pixformat=PIX_FMT_NONE):
        """ Convert AVFrame to a specified format (Intended for copy) """

        cdef AVFrame *pFrame
        cdef int numBytes
        cdef char *rgb_buffer
        cdef int width,height
        cdef AVCodecContext *pCodecCtx = self.CodecCtx

        if (pixformat==PIX_FMT_NONE):
            pixformat=self.pixel_format

        pFrame = avcodec_alloc_frame()
        if pFrame == NULL:
            raise MemoryError("Unable to allocate frame")
        width = self.dest_width
        height = self.dest_height
        numBytes=avpicture_get_size(pixformat, width,height)
        rgb_buffer = <char *>PyMem_Malloc(numBytes)
        avpicture_fill(<AVPicture *>pFrame, <uint8_t *>rgb_buffer, pixformat,width, height)
        sws_scale(self.convert_ctx, frame.data, frame.linesize, 0, self.height, <uint8_t **>pFrame.data, pFrame.linesize)
        if (pFrame==NULL):
            raise Exception,("software scale conversion error")
        return pFrame






    cdef AVFrame *_convert_withbuf(self,AVPicture *frame,char *buf,  AVPixelFormat pixformat=PIX_FMT_NONE):
        """ Convert AVFrame to a specified format (Intended for copy)  """

        cdef AVFrame *pFramePixFormat
        cdef int numBytes
        cdef int width,height
        cdef AVCodecContext *pCodecCtx = self.CodecCtx

        if (pixformat==PIX_FMT_NONE):
            pixformat=self.pixel_format

        pFramePixFormat = avcodec_alloc_frame()
        if pFramePixFormat == NULL:
            raise MemoryError("Unable to allocate Frame")

        width = self.dest_width
        height = self.dest_height
        avpicture_fill(<AVPicture *>pFramePixFormat, <uint8_t *>buf, self.pixel_format,   width, height)
        sws_scale(self.convert_ctx, frame.data, frame.linesize, 0, self.height, <uint8_t**>pFramePixFormat.data, pFramePixFormat.linesize)
        return pFramePixFormat


    # #########################################################
    # time  related functions
    # #########################################################

    def get_fps(self):
        """ return the number of frame per second of the video """
        return (<float>self.stream.r_frame_rate.num / <float>self.stream.r_frame_rate.den)

    def get_base_freq(self):
        """ return the base frequency of a file """
        return (<float>self.CodecCtx.time_base.den/<float>self.CodecCtx.time_base.num)

    def seek_to_frame(self, fno):
        fps=self.get_fps()
        dst=float(fno)/fps
        #sys.stderr.write( "seeking to %f seconds (fps=%f)\n"%(dst,fps))
        self.seek_to_seconds(dst)

    #        def GetFrameTime(self, timestamp):
    #           cdef int64_t targetPts
    #           targetPts = timestamp * AV_TIME_BASE
    #           return self.GetFramePts(targetPts)

    def safe_smallest_videobank_time(self):
        """ return the smallest time index among the not yet displayed decoded frame """
        try:
            return self.smallest_videobank_time()
        except:
            self.__next_frame()
            return self.smallest_videobank_time()

    def get_current_frame_pts(self):
        """ return the PTS for the frame with the smallest time index 
        among the not yet displayed decoded frame """
        am=self.safe_smallest_videobank_time()
        return self.videoframebank[am][0]

    def get_current_frame_frameno(self):
        """ return the frame number for the frame with the smallest time index 
        among the not yet displayed decoded frame """
        am=self.safe_smallest_videobank_time()
        return self.videoframebank[am][1]

    def get_current_frame_type(self):
        """ return the pict_type for the frame with the smallest time index 
        among the not yet displayed decoded frame """
        am=self.safe_smallest_videobank_time()
        return self.videoframebank[am][3]

    def get_current_frame_macroblock_types(self):
        """ return the motion_vals for the frame with the smallest time index 
        among the not yet displayed decoded frame """
        am=self.safe_smallest_videobank_time()
        return self.videoframebank[am][4]        

    def get_current_frame_motion_vectors(self):
        """ return the motion_vals for the frame with the smallest time index 
        among the not yet displayed decoded frame """
        am=self.safe_smallest_videobank_time()
        return self.videoframebank[am][5]        

    def get_current_frame_reference_index(self):
        """ return the motion_vals for the frame with the smallest time index 
        among the not yet displayed decoded frame """
        am=self.safe_smallest_videobank_time()
        return self.videoframebank[am][6]        

    def _get_current_frame_frameno(self):
        return self.CodecCtx.frame_number


    #def write_picture():
        #cdef int out_size
        #if (self.cframe == None):
                #self.CodecCtx.bit_rate = self.bitrate;
                #self.CodecCtx.width = self.width;
                #self.CodecCtx.height = self.height;
                #CodecCtx.frame_rate = (int)self.frate;
                #c->frame_rate_base = 1;
                #c->gop_size = self.gop;
                #c->me_method = ME_EPZS;

                #if (avcodec_open(c, codec) < 0):
                #        raise Exception, "Could not open codec"

                # Write header
                #av_write_header(self.oc);

                # alloc image and output buffer
                #pict = &pic1;
                #avpicture_alloc(pict,PIX_FMT_YUV420P, c->width,c->height);

                #outbuf_size = 1000000;
                #outbuf = "\0"*outbuf_size
                #avframe->linesize[0]=c->width*3;


        #avframe->data[0] = pixmap_;

        ### TO UPDATE
        #img_convert(pict,PIX_FMT_YUV420P, (AVPicture*)avframe, PIX_FMT_RGB24,c->width, c->height);


        ## ENCODE
        #out_size = avcodec_encode_video(c, outbuf, outbuf_size, (AVFrame*)pict);

        #if (av_write_frame(oc, 0, outbuf, out_size)):
        #        raise Exception, "Error while encoding picture"
        #cframe+=1


###############################################################################
## The Reader Class
###############################################################################

cdef class FFMpegReader(AFFMpegReader):
    """ A reader is responsible for playing the file demultiplexing it, and
        to passing the data of each stream to the corresponding track object.

    """
    cdef object default_audio_track
    cdef object default_video_track
    cdef int with_readahead
    cdef unsigned long long int seek_before_security_interval

    def __cinit__(self,with_readahead=True,seek_before=4000):
        self.filename = None
        self.tracks=[]
        self.ctracks=NULL
        self.FormatCtx=NULL
        self.io_context=NULL
        self.frameno = 0
        self.pts=0
        self.dts=0
        self.altpacket=0
        self.prepacket=<AVPacket *>None
        self.packet=&self.packetbufa
        self.observers_enabled=True
        self.errjmppts=0
        self.default_audio_track=None
        self.default_video_track=None
        self.with_readahead=with_readahead
        self.seek_before_security_interval=seek_before


    def __dealloc__(self):
        self.tracks=[]
        if (self.FormatCtx!=NULL):
            if (self.packet):
                av_free_packet(self.packet)
                self.packet=NULL
            if (self.prepacket):
                av_free_packet(self.prepacket)
                self.prepacket=NULL
            av_close_input_file(self.FormatCtx)
            self.FormatCtx=NULL


    def __del__(self):
        self.close()


    def dump(self):
        av_dump_format(self.FormatCtx,0,self.filename,0)


    #def open_old(self,char *filename,track_selector=None,mode="r"):

        #
        # Open the Multimedia File
        #

#        ret = av_open_input_file(&self.FormatCtx,filename,NULL,0,NULL)
#        if ret != 0:
#            raise IOError("Unable to open file %s" % filename)
#        self.filename = filename
#        if (mode=="r"):
#            self.__finalize_open(track_selector)
#        else:
#            self.__finalize_open_write()


    def open(self,char *filename,track_selector=None,mode="r",buf_size=1024):
        cdef int ret
        cdef int score
        cdef AVInputFormat * fmt
        cdef AVProbeData pd
        fmt=NULL
        pd.filename=filename
        pd.buf=NULL
        pd.buf_size=0

        self.filename = filename
        self.FormatCtx = avformat_alloc_context()

        if (mode=="w"):
            raise Exception,"Not yet supported sorry"
            self.FormatCtx.oformat = av_guess_format(NULL, filename_, NULL)
            if (self.FormatCtx.oformat==NULL):
                raise Exception, "Unable to find output format for %s\n"

        if (fmt==NULL):
            fmt=av_probe_input_format(&pd,0)
        
        if (fmt==NULL) or (not (fmt.flags & AVFMT_NOFILE)):
            ret = avio_open(&self.FormatCtx.pb, filename, 0)
            if ret < 0:
                raise IOError("Unable to open file %s (avio_open)" % filename)
            if (buf_size>0):
                url_setbufsize(self.FormatCtx.pb,buf_size)
            #raise Exception, "Not Yet Implemented"
            for log2_probe_size in range(11,20):
                probe_size=1<<log2_probe_size
                #score=(AVPROBE_SCORE_MAX/4 if log2_probe_size!=20 else 0)
                pd.buf=<unsigned char *>av_realloc(pd.buf,probe_size+AVPROBE_PADDING_SIZE)
                pd.buf_size=avio_read(self.FormatCtx.pb,pd.buf,probe_size)
                memset(pd.buf+pd.buf_size,0,AVPROBE_PADDING_SIZE)
                if (avio_seek(self.FormatCtx.pb,0,SEEK_SET)):
                    avio_close(self.FormatCtx.pb)
                    ret=avio_open(&self.FormatCtx.pb, filename, 0)
                    if (ret < 0):
                        raise IOError("Unable to open file %s (avio_open with but)" % filename)
                fmt=av_probe_input_format(&pd,1)#,&score)
                if (fmt!=NULL):
                    break

        assert(fmt!=NULL)
        self.FormatCtx.iformat=fmt

        if (mode=="r"):
            ret = av_open_input_stream(&self.FormatCtx,self.FormatCtx.pb,filename,self.FormatCtx.iformat,NULL)
            if ret != 0:
                raise IOError("Unable to open stream %s" % filename)
            self.__finalize_open(track_selector)
        elif (mode=="w"):
            ret=avio_open(&self.FormatCtx.pb, filename, 1)
            if ret != 0:
                raise IOError("Unable to open file %s" % filename)
            self.__finalize_open_write()
        else:
            raise ValueError, "Unknown Mode"


    def __finalize_open_write(self):
        """
         EXPERIMENTAL !
        """
        cdef  AVFormatContext * oc
        oc = avformat_alloc_context()
        # Guess file format with file extention
        oc.oformat = av_guess_format(NULL, filename_, NULL)
        if (oc.oformat==NULL):
            raise Exception, "Unable to find output format for %s\n"
        # Alloc priv_data for format
        oc.priv_data = av_mallocz(oc.oformat.priv_data_size)
        #avframe = avcodec_alloc_frame();



        # Create the video stream on output AVFormatContext oc
        #self.st = av_new_stream(oc,0)
        # Alloc the codec to the new stream
        #c = &self.st.codec
        # find the video encoder

        #codec = avcodec_find_encoder(oc.oformat.video_codec);
        #if (self.st.codec==None):
        #    raise Exception,"codec not found\n"
        #codec_name = <char *> codec.name;

        # Create the output file
        avio_open(&oc.pb, filename_, URL_WRONLY)

        # last part of init will be set when first frame write()
        # because we need user parameters like size, bitrate...
        self.mode = "w"


    def __finalize_open(self, track_selector=None):
        cdef AVCodecContext * CodecCtx
        cdef VideoTrack vt
        cdef AudioTrack at
        cdef int ret
        cdef int i

        if (track_selector==None):
            track_selector=TS_VIDEO
        ret = av_find_stream_info(self.FormatCtx)
        if ret < 0:
            raise IOError("Unable to find Track info: %d" % (ret,))

        self.pts=0
        self.dts=0

        self.altpacket=0
        self.prepacket=<AVPacket *>None
        self.packet=&self.packetbufa
        #
        # Open the selected Track
        #


        #for i in range(self.FormatCtx.nb_streams):
        #  print "stream #",i," codec_type:",self.FormatCtx.streams[i].codec.codec_type

        for s in track_selector.values():
            #print s
            trackno = -1
            trackb=s[1]
            if (trackb<0):
                for i in range(self.FormatCtx.nb_streams):
                    if self.FormatCtx.streams[i].codec.codec_type == s[0]:
                        if (trackb!=-1):
                            trackb+=1
                        else:
                            #DEBUG("associated "+str(s)+" to "+str(i))
                            #sys.stdin.readline()
                            trackno = i
                            break
            else:
                trackno=s[1]
                assert(trackno<self.FormatCtx.nb_streams)
                assert(self.FormatCtx.streams[i].codec.codec_type == s[0])
            if trackno == -1:
                raise IOError("Unable to find specified Track")

            CodecCtx = self.FormatCtx.streams[trackno].codec
            if (s[0]==CODEC_TYPE_VIDEO):
                try:
                    vt=VideoTrack()
                except:
                    vt=VideoTrack(support_truncated=1)
                if (self.default_video_track==None):
                    self.default_video_track=vt
                vt.init0(self,trackno,  CodecCtx) ## here we are passing cpointers so we do a C call
                vt.init(**s[2])## here we do a python call
                self.tracks.append(vt)
            elif (s[0]==CODEC_TYPE_AUDIO):
                try:
                    at=AudioTrack()
                except:
                    at=AudioTrack(support_truncated=1)
                if (self.default_audio_track==None):
                    self.default_audio_track=at
                at.init0(self,trackno,  CodecCtx) ## here we are passing cpointers so we do a C call
                at.init(**s[2])## here we do a python call
                self.tracks.append(at)
            else:
                raise "unknown type of Track"
        if (self.default_audio_track!=None and self.default_video_track!=None):
            self.default_audio_track.reset_tps(self.default_video_track.get_fps())
        for t in self.tracks:
            t.check_start() ### this is done only if asked
            savereadahead=self.with_readahead
            savebsi=self.seek_before_security_interval
            self.seek_before_security_interval=0
            self.with_readahead=0
            t.check_end()
            self.with_readahead=savereadahead
            self.seek_before_security_interval=savebsi
        try:
            if (self.tracks[0].duration()<0):
                sys.stderr.write("WARNING : inconsistent file duration %x\n"%(self.tracks[0].duration() ,))
                new_duration=-self.tracks[0].duration()
                self.tracks[0]._set_duration(new_duration)
        except KeyError:
            pass


    def close(self):
        if (self.FormatCtx!=NULL):
            for s in self.tracks:
                s.close()
            if (self.packet):
                av_free_packet(self.packet)
                self.packet=NULL
            if (self.prepacket):
                av_free_packet(self.prepacket)
                self.prepacket=NULL
            self.tracks=[] # break cross references
            av_close_input_file(self.FormatCtx)
            self.FormatCtx=NULL


    cdef __prefetch_packet(self):
        """ this function is used for prefetching a packet
            this is used when we want read until something new happen on a specified channel
        """
        #DEBUG("prefetch_packet")
        ret = av_read_frame(self.FormatCtx,self.prepacket)
        if ret < 0:
            #for xerrcnts in range(5,1000):
            #  if (not self.errjmppts):
            #      self.errjmppts=self.tracks[0].get_cur_pts()
            #  no=self.errjmppts+xerrcnts*(AV_TIME_BASE/50)
            #  sys.stderr.write("Unable to read frame:trying to skip some packet and trying again.."+str(no)+","+str(xerrcnts)+"...\n")
            #  av_seek_frame(self.FormatCtx,-1,no,0)
            #  ret = av_read_frame(self.FormatCtx,self.prepacket)
            #  if (ret!=-5):
            #      self.errjmppts=no
            #      print "solved : ret=",ret
            #      break
            #if ret < 0:
            raise IOError("Unable to read frame: %d" % (ret,))
        #DEBUG("/prefetch_packet")


    cdef read_packet_buggy(self):
        """
         This function is supposed to make things nicer...
         However, it is buggy right now and I have to check
         whether it is sitll necessary... So it will be re-enabled ontime...
        """
        cdef bint packet_processed=False
        #DEBUG("read_packet %d %d"%(long(<long int>self.packet),long(<long int>self.prepacket)))
        while not packet_processed:
                #ret = av_read_frame(self.FormatCtx,self.packet)
                #if ret < 0:
                #    raise IOError("Unable to read frame: %d" % (ret,))
            if (self.prepacket==<AVPacket *>None):
                self.prepacket=&self.packetbufa
                self.packet=&self.packetbufb
                self.__prefetch_packet()
            self.packet=self.prepacket
            if (self.packet==&self.packetbufa):
                self.prepacket=&self.packetbufb
            else:
                self.prepacket=&self.packetbufa
            #DEBUG("...PRE..")
            self.__prefetch_packet()
            #DEBUG("packets %d %d"%(long(<long int>self.packet),long(<long int>self.prepacket)))
            packet_processed=self.process_current_packet()
        #DEBUG("/read_packet")

    cdef read_packet(self):
        self.prepacket=&self.packetbufb
        ret = av_read_frame(self.FormatCtx,self.prepacket)
        if ret < 0:
            raise IOError("Unable to read frame: %d" % (ret,))
        self.packet=self.prepacket
        packet_processed=self.process_current_packet()


    def process_current_packet(self):
        """ This function implements the demuxes.
            It dispatch the packet to the correct track processor.

            Limitation : TODO: This function is to be improved to support more than audio and  video tracks.
        """
        cdef Track ct
        cdef VideoTrack vt
        cdef AudioTrack at
        #DEBUG("process_current_packet")
        processed=False
        for s in self.tracks:
            ct=s ## does passing through a pointer solves virtual issues...
            #DEBUG("track : %s = %s ??" %(ct.no,self.packet.stream_index))
            if (ct.no==self.packet.stream_index):
                #ct.process_packet(self.packet)
                ## I don't know why it seems that Windows Cython have problem calling the correct virtual function
                ##
                ##
                if ct.CodecCtx.codec_type==CODEC_TYPE_VIDEO:
                    processed=True
                    vt=ct
                    vt.process_packet(self.packet)
                elif ct.CodecCtx.codec_type==CODEC_TYPE_AUDIO:
                    processed=True
                    at=ct
                    at.process_packet(self.packet)
                else:
                    raise Exception, "Unknown codec type"
                    #ct.process_packet(self.packet)
                #DEBUG("/process_current_packet (ok)")
                av_free_packet(self.packet)
                self.packet=NULL
                return True
        #DEBUG("A packet tageted to track %d has not been processed..."%(self.packet.stream_index))
        #DEBUG("/process_current_packet (not processed !!)")
        av_free_packet(self.packet)
        self.packet=NULL
        return False

    def disable_observers(self):
        self.observers_enabled=False

    def enable_observers(self):
        self.observers_enabled=True

    def get_current_frame(self):
        r=[]
        for tt in self.tracks:
            r.append(tt.get_current_frame())
        return r


    def get_next_frame(self):
        self.tracks[0].get_next_frame()
        return self.get_current_frame()


    def __len__(self):
        try:
            return len(self.tracks[0])
        except:
            raise IOError,"File not correctly opened"


    def read_until_next_frame(self, calltrack=0,maxerrs=10, maxread=10):
        """ read all packets until a frame for the Track "calltrack" arrives """
        #DEBUG("read untiil next fame")
        try :
            while ((maxread>0)  and (calltrack==-1) or (self.prepacket.stream_index != (self.tracks[calltrack].get_no()))):
                if (self.prepacket==<AVPacket *>None):
                    self.prepacket=&self.packetbufa
                    self.packet=&self.packetbufb
                    self.__prefetch_packet()
                self.packet=self.prepacket
                cont=True
                #DEBUG("read until next frame iteration ")
                while (cont):
                    try:
                        self.__prefetch_packet()
                        cont=False
                    except KeyboardInterrupt:
                        raise
                    except:
                        maxerrs-=1
                        if (maxerrs<=0):
                            #DEBUG("read until next frame MAX ERR COUNTS REACHED... Raising Exception")
                            raise
                self.process_current_packet()
                maxread-=1
        except Queue_Full:
            #DEBUG("/read untiil next frame : QF")
            return False
        except IOError:
            #DEBUG("/read untiil next frame : IOError")
            sys.stderr.write("IOError")
            return False
        #DEBUG("/read until next frame")
        return True


    def get_tracks(self):
        return self.tracks


    def seek_to(self, pts):
        """
          Globally seek on all the streams to a specified position.
        """
        #sys.stderr.write("Seeking to PTS=%d\n"%pts)
        cdef int ret=0
        #av_read_frame_flush(self.FormatCtx)
        #DEBUG("FLUSHED")
        ppts=pts-self.seek_before_security_interval # seek a little bit before... and then manually go direct frame
        #ppts=pts
        #print ppts, pts
        #DEBUG("CALLING AV_SEEK_FRAME")

        #try:
        #  if (pts > self.tracks[0].duration()):
        #        raise IOError,"Cannot seek after the end...\n"
        #except KeyError:
        #  pass


        ret = av_seek_frame(self.FormatCtx,-1,ppts,  AVSEEK_FLAG_BACKWARD)#|AVSEEK_FLAG_ANY)
        #DEBUG("AV_SEEK_FRAME DONE")
        if ret < 0:
            raise IOError("Unable to seek: %d" % ret)
        #if (self.io_context!=NULL):
        #    #DEBUG("using FSEEK  ")
        #    #used to have & on pb
        # url_fseek(self.FormatCtx.pb, self.FormatCtx.data_offset, SEEK_SET);
        ## ######################################
        ## Flush buffer
        ## ######################################

        #DEBUG("resetting track buffers")
        for  s in self.tracks:
            s.reset_buffers()

        ## ######################################
        ## do set up exactly all tracks
        ## ######################################

        try:
            if (self.seek_before_security_interval):
            #DEBUG("finalize seek    ")
                self.disable_observers()
                self._finalize_seek_to(pts)
                self.enable_observers()
        except KeyboardInterrupt:
            raise
        except:
            DEBUG("Exception during finalize_seek")

        ## ######################################
        ## read ahead buffers
        ## ######################################
        if self.with_readahead:
            try:
                #DEBUG("readahead")
                self.prepare_to_read_ahead()
                #DEBUG("/readahead")
            except KeyboardInterrupt:
                raise
            except:
                DEBUG("Exception during read ahead")


        #DEBUG("/seek")

    def reset_buffers(self):
        for  s in self.tracks:
            s.reset_buffers()


    def _finalize_seek_to(self, pts):
        """
            This internal function set the player in a correct state after by waiting for information that
            happen after a specified PTS to effectively occur.
        """
        while(self.tracks[0].get_cur_pts()<pts):
            #sys.stderr.write("approx PTS:" + str(self.tracks[0].get_cur_pts())+"\n")
            #print "approx pts:", self.tracks[0].get_cur_pts()
            self.step()
        sys.stderr.write("result PTS:" + str(self.tracks[0].get_cur_pts())+"\n")
        #sys.stderr.write("result PTR hex:" + hex(self.tracks[0].get_cur_pts())+"\n")

    def seek_bytes(self, byte):
        cdef int ret=0
        av_read_frame_flush(self.FormatCtx)
        ret = av_seek_frame(self.FormatCtx,-1,byte,  AVSEEK_FLAG_BACKWARD|AVSEEK_FLAG_BYTE)#|AVSEEK_FLAG_ANY)
        if ret < 0:
            raise IOError("Unable to seek: %d" % (ret,))
        if (self.io_context!=NULL):
            # used to have & here
            avio_seek(self.FormatCtx.pb, self.FormatCtx.data_offset, SEEK_SET)
        ## ######################################
        ## Flush buffer
        ## ######################################


        if (self.packet):
            av_free_packet(self.packet)
            self.packet=NULL
        self.altpacket=0
        self.prepacket=<AVPacket *>None
        self.packet=&self.packetbufa
        for  s in self.tracks:
            s.reset_buffers()

        ## ##########################################################
        ## Put the buffer in a states that would make reading easier
        ## ##########################################################
        self.prepare_to_read_ahead()


    def __getitem__(self,int pos):
        fps=self.tracks[0].get_fps()
        self.seek_to((pos/fps)*AV_TIME_BASE)
        #sys.stderr.write("Trying to get frame\n")
        ri=self.get_current_frame()
        #sys.stderr.write("Ok\n")
        #sys.stderr.write("ri=%s\n"%(repr(ri)))
        return ri

    def prepare_to_read_ahead(self):
        """ fills in all buffers in the tracks so that all necessary datas are available"""
        for  s in self.tracks:
            s.prepare_to_read_ahead()

    def step(self):
        self.tracks[0].get_next_frame()

    def run(self):
        while True:
            #DEBUG("PYFFMPEG RUN : STEP")
            self.step()

    def print_buffer_stats(self):
        c=0
        for t in self.tracks():
            print "track ",c
            try:
                t.print_buffer_stats
            except KeyboardInterrupt:
                raise
            except:
                pass
            c=c+1

    def duration(self):
        if (self.FormatCtx.duration==0x8000000000000000):
            raise KeyError
        return self.FormatCtx.duration

    def duration_time(self):
        return float(self.duration())/ (<float>AV_TIME_BASE)


#cdef class FFMpegStreamReader(FFMpegReader):
    # """
    # This contains some experimental code not meant to be used for the moment
    #"""
#    def open_url(self,  char *filename,track_selector=None):
#        cdef AVInputFormat *format
#        cdef AVProbeData probe_data
#        cdef unsigned char tbuffer[65536]
#        cdef unsigned char tbufferb[65536]

        #self.io_context=av_alloc_put_byte(tbufferb, 65536, 0,<void *>0,<void *>0,<void *>0,<void *>0)  #<ByteIOContext*>PyMem_Malloc(sizeof(ByteIOContext))
        #IOString ios
#       URL_RDONLY=0
#        if (avio_open(&self.io_context, filename,URL_RDONLY ) < 0):
#            raise IOError, "unable to open URL"
#        print "Y"

#        url_fseek(self.io_context, 0, SEEK_SET);

#        probe_data.filename = filename;
#        probe_data.buf = tbuffer;
#        probe_data.buf_size = 65536;

        #probe_data.buf_size = get_buffer(&io_context, buffer, sizeof(buffer));
        #

#        url_fseek(self.io_context, 65535, SEEK_SET);
        #
        #format = av_probe_input_format(&probe_data, 1);
        #
        #            if (not format) :
        #                url_fclose(&io_context);
        #                raise IOError, "unable to get format for URL"

#        if (av_open_input_stream(&self.FormatCtx, self.io_context, NULL, NULL, NULL)) :
#            url_fclose(self.io_context);
#            raise IOError, "unable to open input stream"
#        self.filename = filename
#        self.__finalize_open(track_selector)
#        print "Y"




##################################################################################
# Legacy support for compatibility with PyFFmpeg version 1.0
##################################################################################
class VideoStream:
    def __init__(self):
        self.vr=FFMpegReader()
    def __del__(self):
        self.close()
    def open(self, *args, ** xargs ):
        xargs["track_selector"]=TS_VIDEO_PIL
        self.vr.open(*args, **xargs)
        self.tv=self.vr.get_tracks()[0]
    def close(self):
        self.vr.close()
        self.vr=None
    def GetFramePts(self, pts):
        self.tv.seek_to_pts(pts)
        return self.tv.get_current_frame()[2]
    def GetFrameNo(self, fno):
        self.tv.seek_to_frame(fno)
        return self.tv.get_current_frame()[2]
    def GetCurrentFrame(self, fno):
        return self.tv.get_current_frame()[2]
    def GetNextFrame(self, fno):
        return self.tv.get_next_frame()


##################################################################################
# Usefull constants
##################################################################################

# TODO: Update values below

##################################################################################
# ok libavcodec   52.113. 2
# defined in libavcodec/avcodec.h for AVCodecContext.profile
class profileTypes:
    FF_PROFILE_UNKNOWN  = -99
    FF_PROFILE_RESERVED = -100

    FF_PROFILE_AAC_MAIN = 0
    FF_PROFILE_AAC_LOW  = 1
    FF_PROFILE_AAC_SSR  = 2
    FF_PROFILE_AAC_LTP  = 3

    FF_PROFILE_DTS         = 20
    FF_PROFILE_DTS_ES      = 30
    FF_PROFILE_DTS_96_24   = 40
    FF_PROFILE_DTS_HD_HRA  = 50
    FF_PROFILE_DTS_HD_MA   = 60

    FF_PROFILE_MPEG2_422    = 0
    FF_PROFILE_MPEG2_HIGH   = 1
    FF_PROFILE_MPEG2_SS     = 2
    FF_PROFILE_MPEG2_SNR_SCALABLE  = 3
    FF_PROFILE_MPEG2_MAIN   = 4
    FF_PROFILE_MPEG2_SIMPLE = 5

    FF_PROFILE_H264_CONSTRAINED = (1<<9)  # 8+1; constraint_set1_flag
    FF_PROFILE_H264_INTRA       = (1<<11) # 8+3; constraint_set3_flag

    FF_PROFILE_H264_BASELINE             = 66
    FF_PROFILE_H264_CONSTRAINED_BASELINE = (66|FF_PROFILE_H264_CONSTRAINED)
    FF_PROFILE_H264_MAIN                 = 77
    FF_PROFILE_H264_EXTENDED             = 88
    FF_PROFILE_H264_HIGH                 = 100
    FF_PROFILE_H264_HIGH_10              = 110
    FF_PROFILE_H264_HIGH_10_INTRA        = (110|FF_PROFILE_H264_INTRA)
    FF_PROFILE_H264_HIGH_422             = 122
    FF_PROFILE_H264_HIGH_422_INTRA       = (122|FF_PROFILE_H264_INTRA)
    FF_PROFILE_H264_HIGH_444             = 144
    FF_PROFILE_H264_HIGH_444_PREDICTIVE  = 244
    FF_PROFILE_H264_HIGH_444_INTRA       = (244|FF_PROFILE_H264_INTRA)
    FF_PROFILE_H264_CAVLC_444            = 44
  

##################################################################################
# ok libavcodec   52.113. 2
class CodecTypes:
    CODEC_TYPE_UNKNOWN     = -1
    CODEC_TYPE_VIDEO       = 0
    CODEC_TYPE_AUDIO       = 1
    CODEC_TYPE_DATA        = 2
    CODEC_TYPE_SUBTITLE    = 3
    CODEC_TYPE_ATTACHMENT  = 4

##################################################################################
# ok libavutil    50. 39. 0
class mbTypes:
    MB_TYPE_INTRA4x4   = 0x0001
    MB_TYPE_INTRA16x16 = 0x0002 #FIXME H.264-specific
    MB_TYPE_INTRA_PCM  = 0x0004 #FIXME H.264-specific
    MB_TYPE_16x16      = 0x0008
    MB_TYPE_16x8       = 0x0010
    MB_TYPE_8x16       = 0x0020
    MB_TYPE_8x8        = 0x0040
    MB_TYPE_INTERLACED = 0x0080
    MB_TYPE_DIRECT2    = 0x0100 #FIXME
    MB_TYPE_ACPRED     = 0x0200
    MB_TYPE_GMC        = 0x0400
    MB_TYPE_SKIP       = 0x0800
    MB_TYPE_P0L0       = 0x1000
    MB_TYPE_P1L0       = 0x2000
    MB_TYPE_P0L1       = 0x4000
    MB_TYPE_P1L1       = 0x8000
    MB_TYPE_L0         = (MB_TYPE_P0L0 | MB_TYPE_P1L0)
    MB_TYPE_L1         = (MB_TYPE_P0L1 | MB_TYPE_P1L1)
    MB_TYPE_L0L1       = (MB_TYPE_L0   | MB_TYPE_L1)
    MB_TYPE_QUANT      = 0x00010000
    MB_TYPE_CBP        = 0x00020000    

##################################################################################
# ok
class PixelFormats:
    PIX_FMT_NONE                    = -1
    PIX_FMT_YUV420P                 = 0
    PIX_FMT_YUYV422                 = 1
    PIX_FMT_RGB24                   = 2   
    PIX_FMT_BGR24                   = 3   
    PIX_FMT_YUV422P                 = 4   
    PIX_FMT_YUV444P                 = 5   
    PIX_FMT_YUV410P                 = 6   
    PIX_FMT_YUV411P                 = 7   
    PIX_FMT_GRAY8                   = 8   
    PIX_FMT_MONOWHITE               = 9 
    PIX_FMT_MONOBLACK               = 10 
    PIX_FMT_PAL8                    = 11    
    PIX_FMT_YUVJ420P                = 12 
    PIX_FMT_YUVJ422P                = 13  
    PIX_FMT_YUVJ444P                = 14  
    PIX_FMT_XVMC_MPEG2_MC           = 15
    PIX_FMT_XVMC_MPEG2_IDCT         = 16
    PIX_FMT_UYVY422                 = 17
    PIX_FMT_UYYVYY411               = 18
    PIX_FMT_BGR8                    = 19  
    PIX_FMT_BGR4                    = 20    
    PIX_FMT_BGR4_BYTE               = 21
    PIX_FMT_RGB8                    = 22     
    PIX_FMT_RGB4                    = 23     
    PIX_FMT_RGB4_BYTE               = 24
    PIX_FMT_NV12                    = 25     
    PIX_FMT_NV21                    = 26     

    PIX_FMT_ARGB                    = 27     
    PIX_FMT_RGBA                    = 28     
    PIX_FMT_ABGR                    = 29     
    PIX_FMT_BGRA                    = 30     

    PIX_FMT_GRAY16BE                = 31 
    PIX_FMT_GRAY16LE                = 32 
    PIX_FMT_YUV440P                 = 33 
    PIX_FMT_YUVJ440P                = 34 
    PIX_FMT_YUVA420P                = 35
    PIX_FMT_VDPAU_H264              = 36
    PIX_FMT_VDPAU_MPEG1             = 37
    PIX_FMT_VDPAU_MPEG2             = 38
    PIX_FMT_VDPAU_WMV3              = 39
    PIX_FMT_VDPAU_VC1               = 40
    PIX_FMT_RGB48BE                 = 41  
    PIX_FMT_RGB48LE                 = 42  

    PIX_FMT_RGB565BE                = 43 
    PIX_FMT_RGB565LE                = 44 
    PIX_FMT_RGB555BE                = 45 
    PIX_FMT_RGB555LE                = 46 

    PIX_FMT_BGR565BE                = 47 
    PIX_FMT_BGR565LE                = 48 
    PIX_FMT_BGR555BE                = 49 
    PIX_FMT_BGR555LE                = 50 

    PIX_FMT_VAAPI_MOCO              = 51
    PIX_FMT_VAAPI_IDCT              = 52
    PIX_FMT_VAAPI_VLD               = 53 

    PIX_FMT_YUV420P16LE             = 54 
    PIX_FMT_YUV420P16BE             = 55 
    PIX_FMT_YUV422P16LE             = 56 
    PIX_FMT_YUV422P16BE             = 57 
    PIX_FMT_YUV444P16LE             = 58 
    PIX_FMT_YUV444P16BE             = 59 
    PIX_FMT_VDPAU_MPEG4             = 60 
    PIX_FMT_DXVA2_VLD               = 61 

    PIX_FMT_RGB444BE                = 62
    PIX_FMT_RGB444LE                = 63 
    PIX_FMT_BGR444BE                = 64 
    PIX_FMT_BGR444LE                = 65 
    PIX_FMT_Y400A                   = 66 
