module fmodex.FmodExTypes;

private import fmodex.FmodExEnums;
private import xf.omg.core.LinearAlgebra;


/*  === FROM: fmod.h === */

alias int FMOD_BOOL;
alias uint FMOD_MODE;
alias uint FMOD_TIMEUNIT;
alias uint FMOD_INITFLAGS;
alias uint FMOD_CAPS;
alias uint FMOD_DEBUGLEVEL;
alias uint FMOD_MEMORY_TYPE;

/+
typedef struct FMOD_SYSTEM       FMOD_SYSTEM;
typedef struct FMOD_SOUND        FMOD_SOUND;
typedef struct FMOD_CHANNEL      FMOD_CHANNEL;
typedef struct FMOD_CHANNELGROUP FMOD_CHANNELGROUP;
typedef struct FMOD_REVERB       FMOD_REVERB;
typedef struct FMOD_DSP          FMOD_DSP;
typedef struct FMOD_POLYGON		 FMOD_POLYGON;
typedef struct FMOD_GEOMETRY	 FMOD_GEOMETRY;
typedef struct FMOD_SYNCPOINT	 FMOD_SYNCPOINT;
+/
typedef void* FMOD_SYSTEM;
typedef void* FMOD_SOUND;
typedef void* FMOD_CHANNEL;
typedef void* FMOD_CHANNELGROUP;
typedef void* FMOD_REVERB;
typedef void* FMOD_DSP;
typedef void* FMOD_POLYGON;
typedef void* FMOD_GEOMETRY;
typedef void* FMOD_SYNCPOINT;


alias vec3 FMOD_VECTOR;



/+/// Structure describing a point in 3D space.
struct FMOD_VECTOR
{
	float x;        /* X co-ordinate in 3D space. */
    float y;        /* Y co-ordinate in 3D space. */
    float z;        /* Z co-ordinate in 3D space. */
}+/


/// Structure describing a piece of tag data.
struct FMOD_TAG
{
    FMOD_TAGTYPE      type;         /* [out] The type of this tag. */
    FMOD_TAGDATATYPE  datatype;     /* [out] The type of data that this tag contains */
    char             *name;         /* [out] The name of this tag i.e. "TITLE", "ARTIST" etc. */
    void             *data;         /* [out] Pointer to the tag data - its format is determined by the datatype member */
    uint      datalen;      /* [out] Length of the data contained in this tag */
    FMOD_BOOL         updated;      /* [out] True if this tag has been updated since last being accessed with Sound::getTag */
}


/// Structure describing a CD/DVD table of contents.
struct FMOD_CDTOC
{
    int numtracks;                  /* [out] The number of tracks on the CD */
    int min[100];                   /* [out] The start offset of each track in minutes */
    int sec[100];                   /* [out] The start offset of each track in seconds */
    int frame[100];                 /* [out] The start offset of each track in frames */
}


/**
    Use this structure with System::createSound when more control is needed over loading.
    The possible reasons to use this with System::createSound are:
    - Loading a file from memory.
    - Loading a file from within another larger (possibly wad/pak) file, by giving the loader an offset and length.
    - To create a user created / non file based sound.
    - To specify a starting subsound to seek to within a multi-sample sounds (ie FSB/DLS/SF2) when created as a stream.
    - To specify which subsounds to load for multi-sample sounds (ie FSB/DLS/SF2) so that memory is saved and only a subset is actually loaded/read from disk.
    - To specify 'piggyback' read and seek callbacks for capture of sound data as fmod reads and decodes it.  Useful for ripping decoded PCM data from sounds as they are loaded / played.
    - To specify a MIDI DLS/SF2 sample set file to load when opening a MIDI file.
    See below on what members to fill for each of the above types of sound you want to create.
*/
struct FMOD_CREATESOUNDEXINFO
{
    int                            cbsize;             /* [in] Size of this structure.  This is used so the structure can be expanded in the future and still work on older versions of FMOD Ex. */
    uint                   length;             /* [in] Optional. Specify 0 to ignore. Size in bytes of file to load, or sound to create (in this case only if FMOD_OPENUSER is used).  Required if loading from memory.  If 0 is specified, then it will use the size of the file (unless loading from memory then an error will be returned). */
    uint                   fileoffset;         /* [in] Optional. Specify 0 to ignore. Offset from start of the file to start loading from.  This is useful for loading files from inside big data files. */
    int                            numchannels;        /* [in] Optional. Specify 0 to ignore. Number of channels in a sound mandatory if FMOD_OPENUSER or FMOD_OPENRAW is used. */
    int                            defaultfrequency;   /* [in] Optional. Specify 0 to ignore. Default frequency of sound in a sound mandatory if FMOD_OPENUSER or FMOD_OPENRAW is used.  Other formats use the frequency determined by the file format. */
    FMOD_SOUND_FORMAT              format;             /* [in] Optional. Specify 0 or FMOD_SOUND_FORMAT_NONE to ignore. Format of the sound mandatory if FMOD_OPENUSER or FMOD_OPENRAW is used.  Other formats use the format determined by the file format.   */
    uint                   decodebuffersize;   /* [in] Optional. Specify 0 to ignore. For streams.  This determines the size of the double buffer (in PCM samples) that a stream uses.  Use this for user created streams if you want to determine the size of the callback buffer passed to you.  Specify 0 to use FMOD's default size which is currently equivalent to 400ms of the sound format created/loaded. */
    int                            initialsubsound;    /* [in] Optional. Specify 0 to ignore. In a multi-sample file format such as .FSB/.DLS/.SF2, specify the initial subsound to seek to, only if FMOD_CREATESTREAM is used. */
    int                            numsubsounds;       /* [in] Optional. Specify 0 to ignore or have no subsounds.  In a user created multi-sample sound, specify the number of subsounds within the sound that are accessable with Sound::getSubSound. */
    int                           *inclusionlist;      /* [in] Optional. Specify 0 to ignore. In a multi-sample format such as .FSB/.DLS/.SF2 it may be desirable to specify only a subset of sounds to be loaded out of the whole file.  This is an array of subsound indices to load into memory when created. */
    int                            inclusionlistnum;   /* [in] Optional. Specify 0 to ignore. This is the number of integers contained within the inclusionlist array. */
    FMOD_SOUND_PCMREADCALLBACK     pcmreadcallback;    /* [in] Optional. Specify 0 to ignore. Callback to 'piggyback' on FMOD's read functions and accept or even write PCM data while FMOD is opening the sound.  Used for user sounds created with FMOD_OPENUSER or for capturing decoded data as FMOD reads it. */
    FMOD_SOUND_PCMSETPOSCALLBACK   pcmsetposcallback;  /* [in] Optional. Specify 0 to ignore. Callback for when the user calls a seeking function such as Channel::setTime or Channel::setPosition within a multi-sample sound, and for when it is opened.*/
    FMOD_SOUND_NONBLOCKCALLBACK    nonblockcallback;   /* [in] Optional. Specify 0 to ignore. Callback for successful completion, or error while loading a sound that used the FMOD_NONBLOCKING flag.*/
    const char                    *dlsname;            /* [in] Optional. Specify 0 to ignore. Filename for a DLS or SF2 sample set when loading a MIDI file.   If not specified, on windows it will attempt to open /windows/system32/drivers/gm.dls, otherwise the MIDI will fail to open.  */
    const char                    *encryptionkey;      /* [in] Optional. Specify 0 to ignore. Key for encrypted FSB file.  Without this key an encrypted FSB file will not load. */
    int                            maxpolyphony;       /* [in] Optional. Specify 0 to ignore. For sequenced formats with dynamic channel allocation such as .MID and .IT, this specifies the maximum voice count allowed while playing.  .IT defaults to 64.  .MID defaults to 32. */
    void                          *userdata;           /* [in] Optional. Specify 0 to ignore. This is user data to be attached to the sound during creation.  Access via Sound::getUserData. */
    FMOD_SOUND_TYPE                suggestedsoundtype; /* [in] Optional. Specify 0 or FMOD_SOUND_TYPE_UNKNOWN to ignore.  Instead of scanning all codec types, use this to speed up loading by making it jump straight to this codec. */
    FMOD_FILE_OPENCALLBACK         useropen;           /* [in] Optional. Specify 0 to ignore. Callback for opening this file. */
    FMOD_FILE_CLOSECALLBACK        userclose;          /* [in] Optional. Specify 0 to ignore. Callback for closing this file. */
    FMOD_FILE_READCALLBACK         userread;           /* [in] Optional. Specify 0 to ignore. Callback for reading from this file. */
    FMOD_FILE_SEEKCALLBACK         userseek;           /* [in] Optional. Specify 0 to ignore. Callback for seeking within this file. */
}


/**
    Structure defining a reverb environment.
    
    For more indepth descriptions of the reverb properties under win32, please see the EAX2 and EAX3
    documentation at http://developer.creative.com/ under the 'downloads' section.
    If they do not have the EAX3 documentation, then most information can be attained from
    the EAX2 documentation, as EAX3 only adds some more parameters and functionality on top of 
    EAX2.
*/
struct FMOD_REVERB_PROPERTIES
{                                   /*          MIN     MAX     DEFAULT  DESCRIPTION */
    int          Instance;          /* [in]     0     , 2     , 0      , EAX4/GameCube/Wii only. Environment Instance. 3 (2 for GameCube/Wii) seperate reverbs simultaneously are possible. This specifies which one to set. (win32/GameCube/Wii) */
    int          Environment;       /* [in/out] -1    , 25    , -1     , sets all listener properties.  -1 = OFF. (win32/ps2) */
    float        EnvSize;           /* [in/out] 1.0   , 100.0 , 7.5    , environment size in meters (win32 only) */
    float        EnvDiffusion;      /* [in/out] 0.0   , 1.0   , 1.0    , environment diffusion (win32/Xbox/GameCube) */
    int          Room;              /* [in/out] -10000, 0     , -1000  , room effect level (at mid frequencies) (win32/Xbox/Xbox 360/GameCube/software) */
    int          RoomHF;            /* [in/out] -10000, 0     , -100   , relative room effect level at high frequencies (win32/Xbox/Xbox 360) */
    int          RoomLF;            /* [in/out] -10000, 0     , 0      , relative room effect level at low frequencies (win32 only) */
    float        DecayTime;         /* [in/out] 0.1   , 20.0  , 1.49   , reverberation decay time at mid frequencies (win32/Xbox/Xbox 360/GameCube) */
    float        DecayHFRatio;      /* [in/out] 0.1   , 2.0   , 0.83   , high-frequency to mid-frequency decay time ratio (win32/Xbox/Xbox 360) */
    float        DecayLFRatio;      /* [in/out] 0.1   , 2.0   , 1.0    , low-frequency to mid-frequency decay time ratio (win32 only) */
    int          Reflections;       /* [in/out] -10000, 1000  , -2602  , early reflections level relative to room effect (win32/Xbox/Xbox 360/GameCube) */
    float        ReflectionsDelay;  /* [in/out] 0.0   , 0.3   , 0.007  , initial reflection delay time (win32/Xbox/Xbox 360) */
    float        ReflectionsPan[3]; /* [in/out]       ,       , [0,0,0], early reflections panning vector (win32 only) */
    int          Reverb;            /* [in/out] -10000, 2000  , 200    , late reverberation level relative to room effect (win32/Xbox/Xbox 360) */
    float        ReverbDelay;       /* [in/out] 0.0   , 0.1   , 0.011  , late reverberation delay time relative to initial reflection (win32/Xbox/Xbox 360/GameCube) */
    float        ReverbPan[3];      /* [in/out]       ,       , [0,0,0], late reverberation panning vector (win32 only) */
    float        EchoTime;          /* [in/out] .075  , 0.25  , 0.25   , echo time (win32 or ps2 FMOD_PRESET_PS2_ECHO/FMOD_PRESET_PS2_DELAY only) */
    float        EchoDepth;         /* [in/out] 0.0   , 1.0   , 0.0    , echo depth (win32 or ps2 FMOD_PRESET_PS2_ECHO only) */
    float        ModulationTime;    /* [in/out] 0.04  , 4.0   , 0.25   , modulation time (win32 only) */
    float        ModulationDepth;   /* [in/out] 0.0   , 1.0   , 0.0    , modulation depth (win32/GameCube) */
    float        AirAbsorptionHF;   /* [in/out] -100  , 0.0   , -5.0   , change in level per meter at high frequencies (win32 only) */
    float        HFReference;       /* [in/out] 1000.0, 20000 , 5000.0 , reference high frequency (hz) (win32/Xbox/Xbox 360) */
    float        LFReference;       /* [in/out] 20.0  , 1000.0, 250.0  , reference low frequency (hz) (win32 only) */
    float        RoomRolloffFactor; /* [in/out] 0.0   , 10.0  , 0.0    , like rolloffscale in System::set3DSettings but for reverb room size effect (win32/Xbox/Xbox 360) */
    float        Diffusion;         /* [in/out] 0.0   , 100.0 , 100.0  , Value that controls the echo density in the late reverberation decay. (Xbox/Xbox 360) */
    float        Density;           /* [in/out] 0.0   , 100.0 , 100.0  , Value that controls the modal density in the late reverberation decay (Xbox/Xbox 360) */
    uint Flags;             /* [in/out] FMOD_REVERB_FLAGS - modifies the behavior of above properties (win32/ps2/GameCube/Wii) */
}


/**
    Structure defining the properties for a reverb source, related to a FMOD channel.
    
    For more indepth descriptions of the reverb properties under win32, please see the EAX3
    documentation at http://developer.creative.com/ under the 'downloads' section.
    If they do not have the EAX3 documentation, then most information can be attained from
    the EAX2 documentation, as EAX3 only adds some more parameters and functionality on top of 
    EAX2.
    
    Note the default reverb properties are the same as the FMOD_PRESET_GENERIC preset.
    Note that integer values that typically range from -10,000 to 1000 are represented in 
    decibels, and are of a logarithmic scale, not linear, wheras float values are typically linear.
    PORTABILITY: Each member has the platform it supports in braces ie (win32/Xbox).
    Some reverb parameters are only supported in win32 and some only on Xbox. If all parameters are set then
    the reverb should product a similar effect on either platform.
    
    The numerical values listed below are the maximum, minimum and default values for each variable respectively.
*/
struct FMOD_REVERB_CHANNELPROPERTIES  
{                                      /*          MIN     MAX    DEFAULT  DESCRIPTION */
    int          Direct;               /* [in/out] -10000, 1000,  0,       direct path level (at low and mid frequencies) (win32/Xbox) */
    int          DirectHF;             /* [in/out] -10000, 0,     0,       relative direct path level at high frequencies (win32/Xbox) */
    int          Room;                 /* [in/out] -10000, 1000,  0,       room effect level (at low and mid frequencies) (win32/Xbox/Gamecube/Xbox360) */
    int          RoomHF;               /* [in/out] -10000, 0,     0,       relative room effect level at high frequencies (win32/Xbox) */
    int          Obstruction;          /* [in/out] -10000, 0,     0,       main obstruction control (attenuation at high frequencies)  (win32/Xbox) */
    float        ObstructionLFRatio;   /* [in/out] 0.0,    1.0,   0.0,     obstruction low-frequency level re. main control (win32/Xbox) */
    int          Occlusion;            /* [in/out] -10000, 0,     0,       main occlusion control (attenuation at high frequencies) (win32/Xbox) */
    float        OcclusionLFRatio;     /* [in/out] 0.0,    1.0,   0.25,    occlusion low-frequency level re. main control (win32/Xbox) */
    float        OcclusionRoomRatio;   /* [in/out] 0.0,    10.0,  1.5,     relative occlusion control for room effect (win32) */
    float        OcclusionDirectRatio; /* [in/out] 0.0,    10.0,  1.0,     relative occlusion control for direct path (win32) */
    int          Exclusion;            /* [in/out] -10000, 0,     0,       main exlusion control (attenuation at high frequencies) (win32) */
    float        ExclusionLFRatio;     /* [in/out] 0.0,    1.0,   1.0,     exclusion low-frequency level re. main control (win32) */
    int          OutsideVolumeHF;      /* [in/out] -10000, 0,     0,       outside sound cone level at high frequencies (win32) */
    float        DopplerFactor;        /* [in/out] 0.0,    10.0,  0.0,     like DS3D flDopplerFactor but per source (win32) */
    float        RolloffFactor;        /* [in/out] 0.0,    10.0,  0.0,     like DS3D flRolloffFactor but per source (win32) */
    float        RoomRolloffFactor;    /* [in/out] 0.0,    10.0,  0.0,     like DS3D flRolloffFactor but for room effect (win32/Xbox) */
    float        AirAbsorptionFactor;  /* [in/out] 0.0,    10.0,  1.0,     multiplies AirAbsorptionHF member of FMOD_REVERB_PROPERTIES (win32) */
    uint Flags;                /* [in/out] FMOD_REVERB_CHANNELFLAGS - modifies the behavior of properties (win32) */
}


/// Settings for advanced features like configuring memory and cpu usage for the FMOD_CREATECOMPRESSEDSAMPLE feature.
struct FMOD_ADVANCEDSETTINGS
{                       
    int     cbsize;             /* [in]     Size of this structure.  Use sizeof(FMOD_ADVANCEDSETTINGS)  NOTE: This must be set before calling System::getAdvancedSettings! */
    int     maxMPEGcodecs;      /* [in/out] For use with FMOD_CREATECOMPRESSEDSAMPLE only.  Mpeg  codecs consume 29,424 bytes per instance and this number will determine how many mpeg channels can be played simultaneously.  Default = 16. */
    int     maxADPCMcodecs;     /* [in/out] For use with FMOD_CREATECOMPRESSEDSAMPLE only.  ADPCM codecs consume 2,136 bytes per instance (based on FSB encoded ADPCM block size - see remarks) and this number will determine how many ADPCM channels can be played simultaneously.  Default = 32. */
    int     maxXMAcodecs;       /* [in/out] For use with FMOD_CREATECOMPRESSEDSAMPLE only.  XMA   codecs consume 20,512 bytes per instance and this number will determine how many XMA channels can be played simultaneously.  Default = 32.  */
    int     ASIONumChannels;    /* [in/out] */
    char  **ASIOChannelList;    /* [in/out] */
}



/*  === FROM: fmod_codec.h === */

/**
	When creating a codec, declare one of these and provide the relevant callbacks and name
	for FMOD to use when it opens and reads a file.
*/
struct FMOD_CODEC_DESCRIPTION
{
    const char                     *name;            /* [in] Name of the codec. */
    uint                    ver /+sion+/;         /* [in] Plugin writer's version number. */
    int                             defaultasstream; /* [in] Tells FMOD to open the file as a stream when calling System::createSound, and not a static sample.  Should normally be 0 (FALSE), because generally the user wants to decode the file into memory when using System::createSound.   Mainly used for formats that decode for a very long time, or could use large amounts of memory when decoded.  Usually sequenced formats such as mod/s3m/xm/it/midi fall into this category.   It is mainly to stop users that don't know what they're doing from getting FMOD_ERR_MEMORY returned from createSound when they should have in fact called System::createStream or used FMOD_CREATESTREAM in System::createSound. */
    FMOD_TIMEUNIT                   timeunits;       /* [in] When setposition codec is called, only these time formats will be passed to the codec. Use bitwise OR to accumulate different types. */
    FMOD_CODEC_OPENCALLBACK         open;            /* [in] Open callback for the codec for when FMOD tries to open a sound using this codec. */
    FMOD_CODEC_CLOSECALLBACK        close;           /* [in] Close callback for the codec for when FMOD tries to close a sound using this codec.  */
    FMOD_CODEC_READCALLBACK         read;            /* [in] Read callback for the codec for when FMOD tries to read some data from the file to the destination format (specified in the open callback). */
    FMOD_CODEC_GETLENGTHCALLBACK    getlength;       /* [in] Callback to return the length of the song in whatever format required when Sound::getLength is called. */
    FMOD_CODEC_SETPOSITIONCALLBACK  setposition;     /* [in] Seek callback for the codec for when FMOD tries to seek within the file with Channel::setPosition. */
    FMOD_CODEC_GETPOSITIONCALLBACK  getposition;     /* [in] Tell callback for the codec for when FMOD tries to get the current position within the with Channel::getPosition. */
    FMOD_CODEC_SOUNDCREATECALLBACK  soundcreate;     /* [in] Sound creation callback for the codec when FMOD finishes creating the sound.  (So the codec can set more parameters for the related created sound, ie loop points/mode or 3D attributes etc). */
    FMOD_CODEC_GETWAVEFORMAT        getwaveformat;   /* [in] Callback to tell FMOD about the waveformat of a particular subsound.  This is to save memory, rather than saving 1000 FMOD_CODEC_WAVEFORMAT structures in the codec, the codec might have a more optimal way of storing this information. */
}


/**
    Set these values marked 'in' to tell fmod what sort of sound to create.
    The format, channels and frequency tell FMOD what sort of hardware buffer to create when you initialize your code.
	So if you wrote an MP3 codec that decoded to stereo 16bit integer PCM, you would specify
	FMOD_SOUND_FORMAT_PCM16, and channels would be equal to 2.
    Members marked as 'out' are set by fmod.  Do not modify these.  Simply specify 0 for these values when
	declaring the structure, FMOD will fill in the values for you after creation with the correct function pointers.
*/
struct FMOD_CODEC_WAVEFORMAT
{
    char               name[256];     /* [in] Name of sound.*/
    FMOD_SOUND_FORMAT  format;        /* [in] Format for (decompressed) codec output, ie FMOD_SOUND_FORMAT_PCM8, FMOD_SOUND_FORMAT_PCM16.*/
    int                channels;      /* [in] Number of channels used by codec, ie mono = 1, stereo = 2. */
    int                frequency;     /* [in] Default frequency in hz of the codec, ie 44100. */
    uint       lengthbytes;   /* [in] Length in bytes of the source data. */
    uint       lengthpcm;     /* [in] Length in decompressed, PCM samples of the file, ie length in seconds * frequency.  Used for Sound::getLength and for memory allocation of static decompressed sample data. */
    int                blockalign;    /* [in] Blockalign in decompressed, PCM samples of the optimal decode chunk size for this format.  The codec read callback will be called in multiples of this value. */
    int                loopstart;     /* [in] Loopstart in decompressed, PCM samples of file. */
    int                loopend;       /* [in] Loopend in decompressed, PCM samples of file. */
    FMOD_MODE          mode;          /* [in] Mode to determine whether the sound should by default load as looping, non looping, 2d or 3d. */
    uint       channelmask;   /* [in] Microsoft speaker channel mask, as defined for WAVEFORMATEXTENSIBLE and is found in ksmedia.h.  Leave at 0 to play in natural speaker order. */
}


/**
    Codec plugin structure that is passed into each callback.    
    Set these numsubsounds and waveformat members when called in FMOD_CODEC_OPENCALLBACK to tell fmod
	what sort of sound to create.    
    The format, channels and frequency tell FMOD what sort of hardware buffer to create when you initialize your code.
	So if you wrote an MP3 codec that decoded to stereo 16bit integer PCM, you would specify
	FMOD_SOUND_FORMAT_PCM16, and channels would be equal to 2.
*/
struct FMOD_CODEC_STATE
{
    int                         numsubsounds;  /* [in] Number of 'subsounds' in this sound.  Anything other than 0 makes it a 'container' format (ie CDDA/DLS/FSB etc which contain 1 or more su bsounds).  For most normal, single sound codec such as WAV/AIFF/MP3, this should be 0 as they are not a container for subsounds, they are the sound by itself. */
    FMOD_CODEC_WAVEFORMAT      *waveformat;    /* [in] Pointer to an array of format structures containing information about each sample.  Can be 0 or NULL if FMOD_CODEC_GETWAVEFORMAT callback is preferred.  The number of entries here must equal the number of subsounds defined in the subsound parameter. If numsubsounds = 0 then there should be 1 instance of this structure. */
    void                       *plugindata;    /* [in] Plugin writer created data the codec author wants to attach to this object. */
                                               
    void                       *filehandle;    /* [out] This will return an internal FMOD file handle to use with the callbacks provided.  */
    uint                filesize;      /* [out] This will contain the size of the file in bytes. */
    FMOD_FILE_READCALLBACK      fileread;      /* [out] This will return a callable FMOD file function to use from codec. */
    FMOD_FILE_SEEKCALLBACK      fileseek;      /* [out] This will return a callable FMOD file function to use from codec.  */
    FMOD_CODEC_METADATACALLBACK metadata;      /* [out] This will return a callable FMOD metadata function to use from codec.  */
}



/*  === FROM: fmod_dsp.h === */

/// Structure to define a parameter for a DSP unit.
struct FMOD_DSP_PARAMETERDESC
{
    float       min;                                /* [in] Minimum value of the parameter (ie 100.0). */
    float       max;                                /* [in] Maximum value of the parameter (ie 22050.0). */
    float       defaultval;                         /* [in] Default value of parameter. */
    char        name[16];                           /* [in] Name of the parameter to be displayed (ie "Cutoff frequency"). */
    char        label[16];                          /* [in] Short string to be put next to value to denote the unit type (ie "hz"). */
    const char *description;                        /* [in] Description of the parameter to be displayed as a help item / tooltip for this parameter. */
}


/**
	When creating a DSP unit, declare one of these and provide the relevant callbacks and name for FMOD to use
	when it creates and uses a DSP unit of this type.
*/
struct FMOD_DSP_DESCRIPTION
{
    char                         name[32];           /* [in] Name of the unit to be displayed in the network. */
    uint                 ver /+sion+/;            /* [in] Plugin writer's version number. */
    int                          channels;           /* [in] Number of channels.  Use 0 to process whatever number of channels is currently in the network.  >0 would be mostly used if the unit is a unit that only generates sound. */
    FMOD_DSP_CREATECALLBACK      create;             /* [in] Create callback.  This is called when DSP unit is created.  Can be null. */
    FMOD_DSP_RELEASECALLBACK     release;            /* [in] Release callback.  This is called just before the unit is freed so the user can do any cleanup needed for the unit.  Can be null. */
    FMOD_DSP_RESETCALLBACK       reset;              /* [in] Reset callback.  This is called by the user to reset any history buffers that may need resetting for a filter, when it is to be used or re-used for the first time to its initial clean state.  Use to avoid clicks or artifacts. */
    FMOD_DSP_READCALLBACK        read;               /* [in] Read callback.  Processing is done here.  Can be null. */
    FMOD_DSP_SETPOSITIONCALLBACK setposition;        /* [in] Set position callback.  This is called if the unit wants to update its position info but not process data, or reset a cursor position internally if it is reading data from a certain source.  Can be null. */

    int                          numparameters;      /* [in] Number of parameters used in this filter.  The user finds this with DSP::getNumParameters */
    FMOD_DSP_PARAMETERDESC      *paramdesc;          /* [in] Variable number of parameter structures. */
    FMOD_DSP_SETPARAMCALLBACK    setparameter;       /* [in] This is called when the user calls DSP::setParameter.  Can be null. */
    FMOD_DSP_GETPARAMCALLBACK    getparameter;       /* [in] This is called when the user calls DSP::getParameter.  Can be null. */
    FMOD_DSP_DIALOGCALLBACK      config;             /* [in] This is called when the user calls DSP::showConfigDialog.  Can be used to display a dialog to configure the filter.  Can be null. */
    int                          configwidth;        /* [in] Width of config dialog graphic if there is one.  0 otherwise.*/
    int                          configheight;       /* [in] Height of config dialog graphic if there is one.  0 otherwise.*/
    void                        *userdata;           /* [in] Optional. Specify 0 to ignore. This is user data to be attached to the DSP unit during creation.  Access via DSP::getUserData. */
}


/// DSP plugin structure that is passed into each callback.
struct FMOD_DSP_STATE
{
    FMOD_DSP    *instance;      /* [out] Handle to the DSP hand the user created.  Not to be modified.  C++ users cast to FMOD::DSP to use.  */
    void        *plugindata;    /* [in] Plugin writer created data the output author wants to attach to this object. */
}



/*  === FROM: fmod_output.h === */

/**
	When creating an output, declare one of these and provide the relevant callbacks and name for FMOD to use
	when it opens and reads a file of this type.
*/
 struct FMOD_OUTPUT_DESCRIPTION
{
    const char                        *name;                  /* [in] Name of the output. */
    uint                       ver /+sion+/;               /* [in] Plugin writer's version number. */
    int                                polling;               /* [in] If TRUE (non zero), this tells FMOD to start a thread and call getposition / lock / unlock for feeding data.  If 0, the output is probably callback based, so all the plugin needs to do is call readfrommixer to the appropriate pointer. */ 
    FMOD_OUTPUT_GETNUMDRIVERSCALLBACK  getnumdrivers;         /* [in] For sound device enumeration.  This callback is to give System::getNumDrivers somthing to return. */
    FMOD_OUTPUT_GETDRIVERNAMECALLBACK  getdrivername;         /* [in] For sound device enumeration.  This callback is to give System::getDriverName somthing to return. */
    FMOD_OUTPUT_GETDRIVERCAPSCALLBACK  getdrivercaps;         /* [in] For sound device enumeration.  This callback is to give System::getDriverCaps somthing to return. */
    FMOD_OUTPUT_INITCALLBACK           init;                  /* [in] Initialization function for the output device.  This is called from System::init. */
    FMOD_OUTPUT_CLOSECALLBACK          close;                 /* [in] Cleanup / close down function for the output device.  This is called from System::close. */
    FMOD_OUTPUT_UPDATECALLBACK         update;                /* [in] Update function that is called once a frame by the user.  This is called from System::update. */
    FMOD_OUTPUT_GETHANDLECALLBACK      gethandle;             /* [in] This is called from System::getOutputHandle.  This is just to return a pointer to the internal system device object that the system may be using.*/
    FMOD_OUTPUT_GETPOSITIONCALLBACK    getposition;           /* [in] This is called from the FMOD software mixer thread if 'polling' = true.  This returns a position value in samples so that FMOD knows where and when to fill its buffer. */
    FMOD_OUTPUT_LOCKCALLBACK           lock;                  /* [in] This is called from the FMOD software mixer thread if 'polling' = true.  This function provides a pointer to data that FMOD can write to when software mixing. */
    FMOD_OUTPUT_UNLOCKCALLBACK         unlock;                /* [in] This is called from the FMOD software mixer thread if 'polling' = true.  This optional function accepts the data that has been mixed and copies it or does whatever it needs to before sending it to the hardware. */
}


/// Output plugin structure that is passed into each callback.
struct FMOD_OUTPUT_STATE
{
    void                      *plugindata;      /* [in] Plugin writer created data the output author wants to attach to this object. */
    FMOD_OUTPUT_READFROMMIXER  readfrommixer;   /* [out] Function to update mixer and write the result to the provided pointer.  Used from callback based output only.  Polling based output uses lock/unlock/getposition. */
}



/* === CALLBACKS === */

//typedef FMOD_RESULT (*FMOD_CHANNEL_CALLBACK)      (FMOD_CHANNEL *channel, FMOD_CHANNEL_CALLBACKTYPE type, int command, uint commanddata1, uint commanddata2);
alias FMOD_RESULT function(FMOD_CHANNEL *channel, FMOD_CHANNEL_CALLBACKTYPE type, int command, uint commanddata1, uint commanddata2) FMOD_CHANNEL_CALLBACK;

//typedef FMOD_RESULT (*FMOD_SOUND_NONBLOCKCALLBACK)(FMOD_SOUND *sound, FMOD_RESULT result);
alias FMOD_RESULT function(FMOD_SOUND *sound, FMOD_RESULT result) FMOD_SOUND_NONBLOCKCALLBACK;

//typedef FMOD_RESULT (*FMOD_SOUND_PCMREADCALLBACK)(FMOD_SOUND *sound, void *data, uint datalen);
alias FMOD_RESULT function(FMOD_SOUND *sound, void *data, uint datalen) FMOD_SOUND_PCMREADCALLBACK;

//typedef FMOD_RESULT (*FMOD_SOUND_PCMSETPOSCALLBACK)(FMOD_SOUND *sound, int subsound, uint position, FMOD_TIMEUNIT postype);
alias FMOD_RESULT function(FMOD_SOUND *sound, int subsound, uint position, FMOD_TIMEUNIT postype) FMOD_SOUND_PCMSETPOSCALLBACK;

/*
typedef FMOD_RESULT (*FMOD_FILE_OPENCALLBACK)     (char *name, int unicode, uint *filesize, void **handle, void **userdata);
typedef FMOD_RESULT (*FMOD_FILE_CLOSECALLBACK)    (void *handle, void *userdata);
typedef FMOD_RESULT (*FMOD_FILE_READCALLBACK)     (void *handle, void *buffer, uint sizebytes, uint *bytesread, void *userdata);
typedef FMOD_RESULT (*FMOD_FILE_SEEKCALLBACK)     (void *handle, uint pos, void *userdata);
*/
alias FMOD_RESULT function(char *name, int unicode, uint *filesize, void **handle, void **userdata) FMOD_FILE_OPENCALLBACK;
alias FMOD_RESULT function(void *handle, void *userdata) FMOD_FILE_CLOSECALLBACK;
alias FMOD_RESULT function(void *handle, void *buffer, uint sizebytes, uint *bytesread, void *userdata) FMOD_FILE_READCALLBACK;
alias FMOD_RESULT function(void *handle, uint pos, void *userdata) FMOD_FILE_SEEKCALLBACK;
/*
typedef void *      (*FMOD_MEMORY_ALLOCCALLBACK)  (uint size, FMOD_MEMORY_TYPE type);
typedef void *      (*FMOD_MEMORY_REALLOCCALLBACK)(void *ptr, uint size, FMOD_MEMORY_TYPE type);
typedef void        (*FMOD_MEMORY_FREECALLBACK)   (void *ptr, FMOD_MEMORY_TYPE type);
*/
alias void * function(uint size, FMOD_MEMORY_TYPE type) FMOD_MEMORY_ALLOCCALLBACK;
alias void * function(void *ptr, uint size, FMOD_MEMORY_TYPE type) FMOD_MEMORY_REALLOCCALLBACK;
alias void function(void *ptr, FMOD_MEMORY_TYPE type) FMOD_MEMORY_FREECALLBACK;

/*
typedef FMOD_RESULT (*FMOD_DSP_CREATECALLBACK)     (FMOD_DSP_STATE *dsp_state);
typedef FMOD_RESULT (*FMOD_DSP_RELEASECALLBACK)    (FMOD_DSP_STATE *dsp_state);
typedef FMOD_RESULT (*FMOD_DSP_RESETCALLBACK)      (FMOD_DSP_STATE *dsp_state);
typedef FMOD_RESULT (*FMOD_DSP_READCALLBACK)       (FMOD_DSP_STATE *dsp_state, float *inbuffer, float *outbuffer, uint length, int inchannels, int outchannels);
typedef FMOD_RESULT (*FMOD_DSP_SETPOSITIONCALLBACK)(FMOD_DSP_STATE *dsp_state, uint pos);
typedef FMOD_RESULT (*FMOD_DSP_SETPARAMCALLBACK)   (FMOD_DSP_STATE *dsp_state, int index, float value);
typedef FMOD_RESULT (*FMOD_DSP_GETPARAMCALLBACK)   (FMOD_DSP_STATE *dsp_state, int index, float *value, char *valuestr);
typedef FMOD_RESULT (*FMOD_DSP_DIALOGCALLBACK)     (FMOD_DSP_STATE *dsp_state, void *hwnd, int show);
*/
alias FMOD_RESULT function(FMOD_DSP_STATE *dsp_state) FMOD_DSP_CREATECALLBACK;
alias FMOD_RESULT function(FMOD_DSP_STATE *dsp_state) FMOD_DSP_RELEASECALLBACK;
alias FMOD_RESULT function(FMOD_DSP_STATE *dsp_state) FMOD_DSP_RESETCALLBACK;
alias FMOD_RESULT function(FMOD_DSP_STATE *dsp_state, float *inbuffer, float *outbuffer, uint length, int inchannels, int outchannels) FMOD_DSP_READCALLBACK;
alias FMOD_RESULT function(FMOD_DSP_STATE *dsp_state, uint pos) FMOD_DSP_SETPOSITIONCALLBACK;
alias FMOD_RESULT function(FMOD_DSP_STATE *dsp_state, int index, float value) FMOD_DSP_SETPARAMCALLBACK;
alias FMOD_RESULT function(FMOD_DSP_STATE *dsp_state, int index, float *value, char *valuestr) FMOD_DSP_GETPARAMCALLBACK;
alias FMOD_RESULT function(FMOD_DSP_STATE *dsp_state, void *hwnd, int show) FMOD_DSP_DIALOGCALLBACK;


/*
typedef FMOD_RESULT (*FMOD_CODEC_OPENCALLBACK)        (FMOD_CODEC_STATE *codec_state, FMOD_MODE usermode, FMOD_CREATESOUNDEXINFO *userexinfo);
typedef FMOD_RESULT (*FMOD_CODEC_CLOSECALLBACK)       (FMOD_CODEC_STATE *codec_state);
typedef FMOD_RESULT (*FMOD_CODEC_READCALLBACK)        (FMOD_CODEC_STATE *codec_state, void *buffer, uint sizebytes, uint *bytesread);
typedef FMOD_RESULT (*FMOD_CODEC_GETLENGTHCALLBACK)   (FMOD_CODEC_STATE *codec_state, uint *length, FMOD_TIMEUNIT lengthtype);
typedef FMOD_RESULT (*FMOD_CODEC_SETPOSITIONCALLBACK) (FMOD_CODEC_STATE *codec_state, int subsound, uint position, FMOD_TIMEUNIT postype);
typedef FMOD_RESULT (*FMOD_CODEC_GETPOSITIONCALLBACK) (FMOD_CODEC_STATE *codec_state, uint *position, FMOD_TIMEUNIT postype);
typedef FMOD_RESULT (*FMOD_CODEC_SOUNDCREATECALLBACK) (FMOD_CODEC_STATE *codec_state, int subsound, FMOD_SOUND *sound);
typedef FMOD_RESULT (*FMOD_CODEC_METADATACALLBACK)    (FMOD_CODEC_STATE *codec_state, FMOD_TAGTYPE tagtype, char *name, void *data, uint datalen, FMOD_TAGDATATYPE datatype, int unique);
typedef FMOD_RESULT (*FMOD_CODEC_GETWAVEFORMAT)       (FMOD_CODEC_STATE *codec_state, int index, FMOD_CODEC_WAVEFORMAT *waveformat);
*/
alias FMOD_RESULT function(FMOD_CODEC_STATE *codec_state, FMOD_MODE usermode, FMOD_CREATESOUNDEXINFO *userexinfo) FMOD_CODEC_OPENCALLBACK;
alias FMOD_RESULT function(FMOD_CODEC_STATE *codec_state) FMOD_CODEC_CLOSECALLBACK;
alias FMOD_RESULT function(FMOD_CODEC_STATE *codec_state, void *buffer, uint sizebytes, uint *bytesread) FMOD_CODEC_READCALLBACK;
alias FMOD_RESULT function(FMOD_CODEC_STATE *codec_state, uint *length, FMOD_TIMEUNIT lengthtype) FMOD_CODEC_GETLENGTHCALLBACK;
alias FMOD_RESULT function(FMOD_CODEC_STATE *codec_state, int subsound, uint position, FMOD_TIMEUNIT postype) FMOD_CODEC_SETPOSITIONCALLBACK;
alias FMOD_RESULT function(FMOD_CODEC_STATE *codec_state, uint *position, FMOD_TIMEUNIT postype) FMOD_CODEC_GETPOSITIONCALLBACK;
alias FMOD_RESULT function(FMOD_CODEC_STATE *codec_state, int subsound, FMOD_SOUND *sound) FMOD_CODEC_SOUNDCREATECALLBACK;
alias FMOD_RESULT function(FMOD_CODEC_STATE *codec_state, FMOD_TAGTYPE tagtype, char *name, void *data, uint datalen, FMOD_TAGDATATYPE datatype, int unique) FMOD_CODEC_METADATACALLBACK;
alias FMOD_RESULT function(FMOD_CODEC_STATE *codec_state, int index, FMOD_CODEC_WAVEFORMAT *waveformat) FMOD_CODEC_GETWAVEFORMAT;


/*
typedef FMOD_RESULT (*FMOD_OUTPUT_GETNUMDRIVERSCALLBACK)(FMOD_OUTPUT_STATE *output_state, int *numdrivers);
typedef FMOD_RESULT (*FMOD_OUTPUT_GETDRIVERNAMECALLBACK)(FMOD_OUTPUT_STATE *output_state, int id, char *name, int namelen);
typedef FMOD_RESULT (*FMOD_OUTPUT_GETDRIVERCAPSCALLBACK)(FMOD_OUTPUT_STATE *output_state, int id, FMOD_CAPS *caps);
typedef FMOD_RESULT (*FMOD_OUTPUT_INITCALLBACK)         (FMOD_OUTPUT_STATE *output_state, int selecteddriver, FMOD_INITFLAGS flags, int *outputrate, int outputchannels, FMOD_SOUND_FORMAT *outputformat, int dspbufferlength, int dspnumbuffers, void *extradriverdata);
typedef FMOD_RESULT (*FMOD_OUTPUT_CLOSECALLBACK)        (FMOD_OUTPUT_STATE *output_state);
typedef FMOD_RESULT (*FMOD_OUTPUT_UPDATECALLBACK)       (FMOD_OUTPUT_STATE *output_state);
typedef FMOD_RESULT (*FMOD_OUTPUT_GETHANDLECALLBACK)    (FMOD_OUTPUT_STATE *output_state, void **handle);
typedef FMOD_RESULT (*FMOD_OUTPUT_GETPOSITIONCALLBACK)  (FMOD_OUTPUT_STATE *output_state, uint *pcm);
typedef FMOD_RESULT (*FMOD_OUTPUT_LOCKCALLBACK)         (FMOD_OUTPUT_STATE *output_state, uint offset, uint length, void **ptr1, void **ptr2, uint *len1, uint *len2);
typedef FMOD_RESULT (*FMOD_OUTPUT_UNLOCKCALLBACK)       (FMOD_OUTPUT_STATE *output_state, void *ptr1, void *ptr2, uint len1, uint len2);
typedef FMOD_RESULT (*FMOD_OUTPUT_READFROMMIXER)        (FMOD_OUTPUT_STATE *output_state, void *buffer, uint length);
*/
alias FMOD_RESULT function(FMOD_OUTPUT_STATE *output_state, int *numdrivers) FMOD_OUTPUT_GETNUMDRIVERSCALLBACK;
alias FMOD_RESULT function(FMOD_OUTPUT_STATE *output_state, int id, char *name, int namelen) FMOD_OUTPUT_GETDRIVERNAMECALLBACK;
alias FMOD_RESULT function(FMOD_OUTPUT_STATE *output_state, int id, FMOD_CAPS *caps) FMOD_OUTPUT_GETDRIVERCAPSCALLBACK;
alias FMOD_RESULT function(FMOD_OUTPUT_STATE *output_state, int selecteddriver, FMOD_INITFLAGS flags, int *outputrate, int outputchannels, FMOD_SOUND_FORMAT *outputformat, int dspbufferlength, int dspnumbuffers, void *extradriverdata) FMOD_OUTPUT_INITCALLBACK;
alias FMOD_RESULT function(FMOD_OUTPUT_STATE *output_state) FMOD_OUTPUT_CLOSECALLBACK;
alias FMOD_RESULT function(FMOD_OUTPUT_STATE *output_state) FMOD_OUTPUT_UPDATECALLBACK;
alias FMOD_RESULT function(FMOD_OUTPUT_STATE *output_state, void **handle) FMOD_OUTPUT_GETHANDLECALLBACK;
alias FMOD_RESULT function(FMOD_OUTPUT_STATE *output_state, uint *pcm) FMOD_OUTPUT_GETPOSITIONCALLBACK;
alias FMOD_RESULT function(FMOD_OUTPUT_STATE *output_state, uint offset, uint length, void **ptr1, void **ptr2, uint *len1, uint *len2) FMOD_OUTPUT_LOCKCALLBACK;
alias FMOD_RESULT function(FMOD_OUTPUT_STATE *output_state, void *ptr1, void *ptr2, uint len1, uint len2) FMOD_OUTPUT_UNLOCKCALLBACK;
alias FMOD_RESULT function(FMOD_OUTPUT_STATE *output_state, void *buffer, uint length) FMOD_OUTPUT_READFROMMIXER;
