module fmodex.FmodExEnums;


/*  === FROM: fmod.h === */

/// Error codes.  Returned from every function.
enum FMOD_RESULT
{
    FMOD_OK,                        /* No errors. */
    FMOD_ERR_ALREADYLOCKED,         /* Tried to call lock a second time before unlock was called. */
    FMOD_ERR_BADCOMMAND,            /* Tried to call a function on a data type that does not allow this type of functionality (ie calling Sound::lock on a streaming sound). */
    FMOD_ERR_CDDA_DRIVERS,          /* Neither NTSCSI nor ASPI could be initialised. */
    FMOD_ERR_CDDA_INIT,             /* An error occurred while initialising the CDDA subsystem. */
    FMOD_ERR_CDDA_INVALID_DEVICE,   /* Couldn't find the specified device. */
    FMOD_ERR_CDDA_NOAUDIO,          /* No audio tracks on the specified disc. */
    FMOD_ERR_CDDA_NODEVICES,        /* No CD/DVD devices were found. */ 
    FMOD_ERR_CDDA_NODISC,           /* No disc present in the specified drive. */
    FMOD_ERR_CDDA_READ,             /* A CDDA read error occurred. */
    FMOD_ERR_CHANNEL_ALLOC,         /* Error trying to allocate a channel. */
    FMOD_ERR_CHANNEL_STOLEN,        /* The specified channel has been reused to play another sound. */
    FMOD_ERR_COM,                   /* A Win32 COM related error occured. COM failed to initialize or a QueryInterface failed meaning a Windows codec or driver was not installed properly. */
    FMOD_ERR_DMA,                   /* DMA Failure.  See debug output for more information. */
    FMOD_ERR_DSP_CONNECTION,        /* DSP connection error.  Connection possibly caused a cyclic dependancy. */
    FMOD_ERR_DSP_FORMAT,            /* DSP Format error.  A DSP unit may have attempted to connect to this network with the wrong format. */
    FMOD_ERR_DSP_NOTFOUND,          /* DSP connection error.  Couldn't find the DSP unit specified. */
    FMOD_ERR_DSP_RUNNING,           /* DSP error.  Cannot perform this operation while the network is in the middle of running.  This will most likely happen if a connection or disconnection is attempted in a DSP callback. */
    FMOD_ERR_DSP_TOOMANYCONNECTIONS,/* DSP connection error.  The unit being connected to or disconnected should only have 1 input or output. */
    FMOD_ERR_FILE_BAD,              /* Error loading file. */
    FMOD_ERR_FILE_COULDNOTSEEK,     /* Couldn't perform seek operation.  This is a limitation of the medium (ie netstreams) or the file format. */
    FMOD_ERR_FILE_EOF,              /* End of file unexpectedly reached while trying to read essential data (truncated data?). */
    FMOD_ERR_FILE_NOTFOUND,         /* File not found. */
    FMOD_ERR_FILE_UNWANTED,         /* Unwanted file access occured. */
    FMOD_ERR_FORMAT,                /* Unsupported file or audio format. */
    FMOD_ERR_HTTP,                  /* A HTTP error occurred. This is a catch-all for HTTP errors not listed elsewhere. */
    FMOD_ERR_HTTP_ACCESS,           /* The specified resource requires authentication or is forbidden. */
    FMOD_ERR_HTTP_PROXY_AUTH,       /* Proxy authentication is required to access the specified resource. */
    FMOD_ERR_HTTP_SERVER_ERROR,     /* A HTTP server error occurred. */
    FMOD_ERR_HTTP_TIMEOUT,          /* The HTTP request timed out. */
    FMOD_ERR_INITIALIZATION,        /* FMOD was not initialized correctly to support this function. */
    FMOD_ERR_INITIALIZED,           /* Cannot call this command after System::init. */
    FMOD_ERR_INTERNAL,              /* An error occured that wasn't supposed to.  Contact support. */
    FMOD_ERR_INVALID_ADDRESS,       /* On Xbox 360, this memory address passed to FMOD must be physical, (ie allocated with XPhysicalAlloc.) */
    FMOD_ERR_INVALID_FLOAT,         /* Value passed in was a NaN, Inf or denormalized float. */
    FMOD_ERR_INVALID_HANDLE,        /* An invalid object handle was used. */
    FMOD_ERR_INVALID_PARAM,         /* An invalid parameter was passed to this function. */
    FMOD_ERR_INVALID_SPEAKER,       /* An invalid speaker was passed to this function based on the current speaker mode. */
    FMOD_ERR_INVALID_VECTOR,        /* The vectors passed in are not unit length, or perpendicular. */
    FMOD_ERR_IRX,                   /* PS2 only.  fmodex.irx failed to initialize.  This is most likely because you forgot to load it. */
    FMOD_ERR_MEMORY,                /* Not enough memory or resources. */
    FMOD_ERR_MEMORY_IOP,            /* PS2 only.  Not enough memory or resources on PlayStation 2 IOP ram. */
    FMOD_ERR_MEMORY_SRAM,           /* Not enough memory or resources on console sound ram. */
    FMOD_ERR_MEMORY_CANTPOINT,      /* Can't use FMOD_OPENMEMORY_POINT on non PCM source data, or non mp3/xma/adpcm data if FMOD_CREATECOMPRESSEDSAMPLE was used. */
    FMOD_ERR_NEEDS2D,               /* Tried to call a command on a 3d sound when the command was meant for 2d sound. */
    FMOD_ERR_NEEDS3D,               /* Tried to call a command on a 2d sound when the command was meant for 3d sound. */
    FMOD_ERR_NEEDSHARDWARE,         /* Tried to use a feature that requires hardware support.  (ie trying to play a VAG compressed sound in software on PS2). */
    FMOD_ERR_NEEDSSOFTWARE,         /* Tried to use a feature that requires the software engine.  Software engine has either been turned off, or command was executed on a hardware channel which does not support this feature. */
    FMOD_ERR_NET_CONNECT,           /* Couldn't connect to the specified host. */
    FMOD_ERR_NET_SOCKET_ERROR,      /* A socket error occurred.  This is a catch-all for socket-related errors not listed elsewhere. */
    FMOD_ERR_NET_URL,               /* The specified URL couldn't be resolved. */
    FMOD_ERR_NOTREADY,              /* Operation could not be performed because specified sound is not ready. */
    FMOD_ERR_OUTPUT_ALLOCATED,      /* Error initializing output device, but more specifically, the output device is already in use and cannot be reused. */
    FMOD_ERR_OUTPUT_CREATEBUFFER,   /* Error creating hardware sound buffer. */
    FMOD_ERR_OUTPUT_DRIVERCALL,     /* A call to a standard soundcard driver failed, which could possibly mean a bug in the driver or resources were missing or exhausted. */
    FMOD_ERR_OUTPUT_FORMAT,         /* Soundcard does not support the minimum features needed for this soundsystem (16bit stereo output). */
    FMOD_ERR_OUTPUT_INIT,           /* Error initializing output device. */
    FMOD_ERR_OUTPUT_NOHARDWARE,     /* FMOD_HARDWARE was specified but the sound card does not have the resources nescessary to play it. */
    FMOD_ERR_OUTPUT_NOSOFTWARE,     /* Attempted to create a software sound but no software channels were specified in System::init. */
    FMOD_ERR_PAN,                   /* Panning only works with mono or stereo sound sources. */
    FMOD_ERR_PLUGIN,                /* An unspecified error has been returned from a 3rd party plugin. */
    FMOD_ERR_PLUGIN_MISSING,        /* A requested output, dsp unit type or codec was not available. */
    FMOD_ERR_PLUGIN_RESOURCE,       /* A resource that the plugin requires cannot be found. (ie the DLS file for MIDI playback) */
    FMOD_ERR_RECORD,                /* An error occured trying to initialize the recording device. */
    FMOD_ERR_REVERB_INSTANCE,       /* Specified Instance in FMOD_REVERB_PROPERTIES couldn't be set. Most likely because another application has locked the EAX4 FX slot. */
    FMOD_ERR_SUBSOUNDS,             /* The error occured because the sound referenced contains subsounds.  (ie you cannot play the parent sound as a static sample, only its subsounds.) */
    FMOD_ERR_SUBSOUND_ALLOCATED,    /* This subsound is already being used by another sound, you cannot have more than one parent to a sound.  Null out the other parent's entry first. */
    FMOD_ERR_TAGNOTFOUND,           /* The specified tag could not be found or there are no tags. */
    FMOD_ERR_TOOMANYCHANNELS,       /* The sound created exceeds the allowable input channel count.  This can be increased using the maxinputchannels parameter in System::setSoftwareFormat. */
    FMOD_ERR_UNIMPLEMENTED,         /* Something in FMOD hasn't been implemented when it should be! contact support! */
    FMOD_ERR_UNINITIALIZED,         /* This command failed because System::init or System::setDriver was not called. */
    FMOD_ERR_UNSUPPORTED,           /* A command issued was not supported by this object.  Possibly a plugin without certain callbacks specified. */
    FMOD_ERR_UPDATE,                /* An error caused by System::update occured. */
    FMOD_ERR_VERSION,               /* The version number of this file format is not supported. */

    FMOD_ERR_EVENT_FAILED,          /* An Event failed to be retrieved, most likely due to 'just fail' being specified as the max playbacks behaviour. */
    FMOD_ERR_EVENT_INTERNAL,        /* An error occured that wasn't supposed to.  See debug log for reason. */
    FMOD_ERR_EVENT_INFOONLY,        /* Can't execute this command on an EVENT_INFOONLY event. */
    FMOD_ERR_EVENT_NAMECONFLICT,    /* A category with the same name already exists. */
    FMOD_ERR_EVENT_NOTFOUND,        /* The requested event, event group, event category or event property could not be found. */

    FMOD_RESULT_FORCEINT = 65536    /* Makes sure this enum is signed 32bit. */
}


/// These output types are used with System::setOutput/System::getOutput, to choose which output method to use.
enum FMOD_OUTPUTTYPE
{
    FMOD_OUTPUTTYPE_AUTODETECT,      /* Picks the best output mode for the platform.  This is the default. */
                                     
    FMOD_OUTPUTTYPE_UNKNOWN,         /* All         - 3rd party plugin, unknown.  This is for use with System::getOutput only. */
    FMOD_OUTPUTTYPE_NOSOUND,         /* All         - All calls in this mode succeed but make no sound. */
    FMOD_OUTPUTTYPE_WAVWRITER,       /* All         - Writes output to fmodoutput.wav by default.  Use the 'extradriverdata' parameter in System::init, by simply passing the filename as a string, to set the wav filename. */
    FMOD_OUTPUTTYPE_NOSOUND_NRT,     /* All         - Non-realtime version of FMOD_OUTPUTTYPE_NOSOUND.  User can drive mixer with System::update at whatever rate they want. */
    FMOD_OUTPUTTYPE_WAVWRITER_NRT,   /* All         - Non-realtime version of FMOD_OUTPUTTYPE_WAVWRITER.  User can drive mixer with System::update at whatever rate they want. */
                                     
    FMOD_OUTPUTTYPE_DSOUND,          /* Win32/Win64 - DirectSound output.  Use this to get hardware accelerated 3d audio and EAX Reverb support. (Default on Windows) */
    FMOD_OUTPUTTYPE_WINMM,           /* Win32/Win64 - Windows Multimedia output. */
    FMOD_OUTPUTTYPE_ASIO,            /* Win32       - Low latency ASIO driver. */
    FMOD_OUTPUTTYPE_OSS,             /* Linux       - Open Sound System output. (Default on Linux) */
    FMOD_OUTPUTTYPE_ALSA,            /* Linux       - Advanced Linux Sound Architecture output. */
    FMOD_OUTPUTTYPE_ESD,             /* Linux       - Enlightment Sound Daemon output. */
    FMOD_OUTPUTTYPE_SOUNDMANAGER,    /* Mac         - Macintosh SoundManager output.  (Default on Mac carbon library)*/
    FMOD_OUTPUTTYPE_COREAUDIO,       /* Mac         - Macintosh CoreAudio output.  (Default on Mac OSX library) */
    FMOD_OUTPUTTYPE_XBOX,            /* Xbox        - Native hardware output. (Default on Xbox) */
    FMOD_OUTPUTTYPE_PS2,             /* PS2         - Native hardware output. (Default on PS2) */
    FMOD_OUTPUTTYPE_PS3,             /* PS3         - Native hardware output. (Default on PS3) */
    FMOD_OUTPUTTYPE_GC,              /* GameCube    - Native hardware output. (Default on GameCube) */
    FMOD_OUTPUTTYPE_XBOX360,         /* Xbox 360    - Native hardware output. (Default on Xbox 360) */
    FMOD_OUTPUTTYPE_PSP,             /* PSP         - Native hardware output. (Default on PSP) */
	FMOD_OUTPUTTYPE_WII,			 /* Wii			- Native hardware output. (Default on Wii) */

    FMOD_OUTPUTTYPE_MAX,             /* Maximum number of output types supported. */
    FMOD_OUTPUTTYPE_FORCEINT = 65536 /* Makes sure this enum is signed 32bit. */
}


/// These are speaker types defined for use with the System::setSpeakerMode or System::getSpeakerMode command.
enum FMOD_SPEAKERMODE
{
    FMOD_SPEAKERMODE_RAW,              /* There is no specific speakermode.  Sound channels are mapped in order of input to output.  Use System::setSoftwareFormat to specify speaker count. See remarks for more information. */
    FMOD_SPEAKERMODE_MONO,             /* The speakers are monaural. */
    FMOD_SPEAKERMODE_STEREO,           /* The speakers are stereo (DEFAULT). */
    FMOD_SPEAKERMODE_QUAD,             /* 4 speaker setup.  This includes front left, front right, rear left, rear right.  */
    FMOD_SPEAKERMODE_SURROUND,         /* 4 speaker setup.  This includes front left, front right, center, rear center (rear left/rear right are averaged). */
    FMOD_SPEAKERMODE_5POINT1,          /* 5.1 speaker setup.  This includes front left, front right, center, rear left, rear right and a subwoofer. */
    FMOD_SPEAKERMODE_7POINT1,          /* 7.1 speaker setup.  This includes front left, front right, center, rear left, rear right, side left, side right and a subwoofer. */
    FMOD_SPEAKERMODE_PROLOGIC,         /* Stereo output, but data is encoded in a way that is picked up by a Prologic/Prologic2 decoder and split into a 5.1 speaker setup. */

    FMOD_SPEAKERMODE_MAX,              /* Maximum number of speaker modes supported. */
    FMOD_SPEAKERMODE_FORCEINT = 65536  /* Makes sure this enum is signed 32bit. */
}


/**
    These are speaker types defined for use with the Channel::setSpeakerLevels command.
    It can also be used for speaker placement in the System::setSpeakerPosition command.
*/
enum FMOD_SPEAKER
{
    FMOD_SPEAKER_FRONT_LEFT,
    FMOD_SPEAKER_FRONT_RIGHT,
    FMOD_SPEAKER_FRONT_CENTER,
    FMOD_SPEAKER_LOW_FREQUENCY,
    FMOD_SPEAKER_BACK_LEFT,
    FMOD_SPEAKER_BACK_RIGHT,
    FMOD_SPEAKER_SIDE_LEFT,
    FMOD_SPEAKER_SIDE_RIGHT,
    
    FMOD_SPEAKER_MAX,                                       /* Maximum number of speaker types supported. */
    FMOD_SPEAKER_MONO        = FMOD_SPEAKER_FRONT_LEFT,     /* For use with FMOD_SPEAKERMODE_MONO and Channel::SetSpeakerLevels.  Mapped to same value as FMOD_SPEAKER_FRONT_LEFT. */
    FMOD_SPEAKER_BACK_CENTER = FMOD_SPEAKER_LOW_FREQUENCY,  /* For use with FMOD_SPEAKERMODE_SURROUND and Channel::SetSpeakerLevels only.  Mapped to same value as FMOD_SPEAKER_LOW_FREQUENCY. */
    FMOD_SPEAKER_FORCEINT    = 65536                        /* Makes sure this enum is signed 32bit. */
}


/**
    These are plugin types defined for use with the System::getNumPlugins, 
    System::getPluginInfo and System::unloadPlugin functions.
*/
enum FMOD_PLUGINTYPE
{
    FMOD_PLUGINTYPE_OUTPUT,          /* The plugin type is an output module.  FMOD mixed audio will play through one of these devices */
    FMOD_PLUGINTYPE_CODEC,           /* The plugin type is a file format codec.  FMOD will use these codecs to load file formats for playback. */
    FMOD_PLUGINTYPE_DSP,             /* The plugin type is a DSP unit.  FMOD will use these plugins as part of its DSP network to apply effects to output or generate sound in realtime. */

    FMOD_PLUGINTYPE_MAX,             /* Maximum number of plugin types supported. */
    FMOD_PLUGINTYPE_FORCEINT = 65536 /* Makes sure this enum is signed 32bit. */
}


/**
	These definitions describe the type of song being played.
*/
enum FMOD_SOUND_TYPE
{
    FMOD_SOUND_TYPE_UNKNOWN,         /* 3rd party / unknown plugin format. */
    FMOD_SOUND_TYPE_AAC,             /* AAC.  Currently unsupported. */
    FMOD_SOUND_TYPE_AIFF,            /* AIFF. */
    FMOD_SOUND_TYPE_ASF,             /* Microsoft Advanced Systems Format (ie WMA/ASF/WMV). */
    FMOD_SOUND_TYPE_AT3,             /* Sony ATRAC 3 format */
    FMOD_SOUND_TYPE_CDDA,            /* Digital CD audio. */
    FMOD_SOUND_TYPE_DLS,             /* Sound font / downloadable sound bank. */
    FMOD_SOUND_TYPE_FLAC,            /* FLAC lossless codec. */
    FMOD_SOUND_TYPE_FSB,             /* FMOD Sample Bank. */
    FMOD_SOUND_TYPE_GCADPCM,         /* GameCube ADPCM */
    FMOD_SOUND_TYPE_IT,              /* Impulse Tracker. */
    FMOD_SOUND_TYPE_MIDI,            /* MIDI. */
    FMOD_SOUND_TYPE_MOD,             /* Protracker / Fasttracker MOD. */
    FMOD_SOUND_TYPE_MPEG,            /* MP2/MP3 MPEG. */
    FMOD_SOUND_TYPE_OGGVORBIS,       /* Ogg vorbis. */
    FMOD_SOUND_TYPE_PLAYLIST,        /* Information only from ASX/PLS/M3U/WAX playlists */
    FMOD_SOUND_TYPE_RAW,             /* Raw PCM data. */
    FMOD_SOUND_TYPE_S3M,             /* ScreamTracker 3. */
    FMOD_SOUND_TYPE_SF2,             /* Sound font 2 format. */
    FMOD_SOUND_TYPE_USER,            /* User created sound. */
    FMOD_SOUND_TYPE_WAV,             /* Microsoft WAV. */
    FMOD_SOUND_TYPE_XM,              /* FastTracker 2 XM. */
    FMOD_SOUND_TYPE_XMA,             /* Xbox360 XMA */
    FMOD_SOUND_TYPE_VAG,             /* PlayStation 2 / PlayStation Portable adpcm VAG format. */

    FMOD_SOUND_TYPE_MAX,             /* Maximum number of sound types supported. */
    FMOD_SOUND_TYPE_FORCEINT = 65536 /* Makes sure this enum is signed 32bit. */
}


/// These definitions describe the native format of the hardware or software buffer that will be used.
enum FMOD_SOUND_FORMAT
{
    FMOD_SOUND_FORMAT_NONE,             /* Unitialized / unknown. */
    FMOD_SOUND_FORMAT_PCM8,             /* 8bit integer PCM data. */
    FMOD_SOUND_FORMAT_PCM16,            /* 16bit integer PCM data.  */
    FMOD_SOUND_FORMAT_PCM24,            /* 24bit integer PCM data.  */
    FMOD_SOUND_FORMAT_PCM32,            /* 32bit integer PCM data.  */
    FMOD_SOUND_FORMAT_PCMFLOAT,         /* 32bit floating point PCM data.  */
    FMOD_SOUND_FORMAT_GCADPCM,          /* Compressed GameCube DSP data. */
    FMOD_SOUND_FORMAT_IMAADPCM,         /* Compressed IMA ADPCM / Xbox ADPCM data. */
    FMOD_SOUND_FORMAT_VAG,              /* Compressed PlayStation 2 / PlayStation Portable ADPCM data. */
    FMOD_SOUND_FORMAT_XMA,              /* Compressed Xbox360 data. */
    FMOD_SOUND_FORMAT_MPEG,             /* Compressed MPEG layer 2 or 3 data. */

    FMOD_SOUND_FORMAT_MAX,              /* Maximum number of sound formats supported. */   
    FMOD_SOUND_FORMAT_FORCEINT = 65536  /* Makes sure this enum is signed 32bit. */
}


/// These values describe what state a sound is in after FMOD_NONBLOCKING has been used to open it.
enum FMOD_OPENSTATE
{
    FMOD_OPENSTATE_READY = 0,       /* Opened and ready to play. */
    FMOD_OPENSTATE_LOADING,         /* Initial load in progress. */
    FMOD_OPENSTATE_ERROR,           /* Failed to open - file not found, out of memory etc.  See return value of Sound::getOpenState for what happened. */
    FMOD_OPENSTATE_CONNECTING,      /* Connecting to remote host (internet sounds only). */
    FMOD_OPENSTATE_BUFFERING,       /* Buffering data. */
    FMOD_OPENSTATE_SEEKING,         /* Seeking to subsound and re-flushing stream buffer. */

    FMOD_OPENSTATE_MAX,             /* Maximum number of open state types. */
    FMOD_OPENSTATE_FORCEINT = 65536 /* Makes sure this enum is signed 32bit. */
}


/// These callback types are used with Channel::setCallback.
enum FMOD_CHANNEL_CALLBACKTYPE
{
    FMOD_CHANNEL_CALLBACKTYPE_END,                  /* Called when a sound ends. */
    FMOD_CHANNEL_CALLBACKTYPE_VIRTUALVOICE,         /* Called when a voice is swapped out or swapped in. */
    FMOD_CHANNEL_CALLBACKTYPE_SYNCPOINT,            /* Called when a syncpoint is encountered.  Can be from wav file markers. */

    FMOD_CHANNEL_CALLBACKTYPE_MAX,                  /* Maximum number of callback types supported. */
    FMOD_CHANNEL_CALLBACKTYPE_FORCEINT = 65536      /* Makes sure this enum is signed 32bit. */
}


/**
    List of windowing methods used in spectrum analysis to reduce leakage / transient signals intefering with the analysis.
    This is a problem with analysis of continuous signals that only have a small portion of the signal sample (the fft window size).
    Windowing the signal with a curve or triangle tapers the sides of the fft window to help alleviate this problem.
*/
enum FMOD_DSP_FFT_WINDOW
{
    FMOD_DSP_FFT_WINDOW_RECT,            /* w[n] = 1.0                                                                                            */
    FMOD_DSP_FFT_WINDOW_TRIANGLE,        /* w[n] = TRI(2n/N)                                                                                      */
    FMOD_DSP_FFT_WINDOW_HAMMING,         /* w[n] = 0.54 - (0.46 * COS(n/N) )                                                                      */
    FMOD_DSP_FFT_WINDOW_HANNING,         /* w[n] = 0.5 *  (1.0  - COS(n/N) )                                                                      */
    FMOD_DSP_FFT_WINDOW_BLACKMAN,        /* w[n] = 0.42 - (0.5  * COS(n/N) ) + (0.08 * COS(2.0 * n/N) )                                           */
    FMOD_DSP_FFT_WINDOW_BLACKMANHARRIS,  /* w[n] = 0.35875 - (0.48829 * COS(1.0 * n/N)) + (0.14128 * COS(2.0 * n/N)) - (0.01168 * COS(3.0 * n/N)) */
    
    FMOD_DSP_FFT_WINDOW_MAX,             /* Maximum number of FFT window types supported. */
    FMOD_DSP_FFT_WINDOW_FORCEINT = 65536 /* Makes sure this enum is signed 32bit. */
}


/// List of interpolation types that the FMOD Ex software mixer supports. 
enum FMOD_DSP_RESAMPLER
{
    FMOD_DSP_RESAMPLER_NOINTERP,        /* No interpolation.  High frequency aliasing hiss will be audible depending on the sample rate of the sound. */
    FMOD_DSP_RESAMPLER_LINEAR,          /* Linear interpolation (default method).  Fast and good quality, causes very slight lowpass effect on low frequency sounds. */
    FMOD_DSP_RESAMPLER_CUBIC,           /* Cubic interoplation.  Slower than linear interpolation but better quality. */
    FMOD_DSP_RESAMPLER_SPLINE,          /* 5 point spline interoplation.  Slowest resampling method but best quality. */

    FMOD_DSP_RESAMPLER_MAX,             /* Maximum number of resample methods supported. */
    FMOD_DSP_RESAMPLER_FORCEINT = 65536 /* Makes sure this enum is signed 32bit. */
}


/// List of tag types that could be stored within a sound.  These include id3 tags, metadata from netstreams and vorbis/asf data.
enum FMOD_TAGTYPE
{
    FMOD_TAGTYPE_UNKNOWN = 0,
    FMOD_TAGTYPE_ID3V1,
    FMOD_TAGTYPE_ID3V2,
    FMOD_TAGTYPE_VORBISCOMMENT,
    FMOD_TAGTYPE_SHOUTCAST,
    FMOD_TAGTYPE_ICECAST,
    FMOD_TAGTYPE_ASF,
    FMOD_TAGTYPE_MIDI,
    FMOD_TAGTYPE_PLAYLIST,
    FMOD_TAGTYPE_FMOD,
    FMOD_TAGTYPE_USER,

    FMOD_TAGTYPE_MAX,               /* Maximum number of tag types supported. */
    FMOD_TAGTYPE_FORCEINT = 65536   /* Makes sure this enum is signed 32bit. */
}


/// List of data types that can be returned by Sound::getTag.
enum FMOD_TAGDATATYPE
{
    FMOD_TAGDATATYPE_BINARY = 0,
    FMOD_TAGDATATYPE_INT,
    FMOD_TAGDATATYPE_FLOAT,
    FMOD_TAGDATATYPE_STRING,
    FMOD_TAGDATATYPE_STRING_UTF16,
    FMOD_TAGDATATYPE_STRING_UTF16BE,
    FMOD_TAGDATATYPE_STRING_UTF8,
    FMOD_TAGDATATYPE_CDTOC,

    FMOD_TAGDATATYPE_MAX,               /* Maximum number of tag datatypes supported. */
    FMOD_TAGDATATYPE_FORCEINT = 65536   /* Makes sure this enum is signed 32bit. */
}


/// Special channel index values for FMOD functions.
enum FMOD_CHANNELINDEX
{
    FMOD_CHANNEL_FREE  = -1,      /* For a channel index, FMOD chooses a free voice using the priority system. */
    FMOD_CHANNEL_REUSE = -2       /* For a channel index, re-use the channel handle that was passed in. */
}



/*  === FROM: fmod_dsp.h === */

/// These definitions can be used for creating FMOD defined special effects or DSP units.
enum FMOD_DSP_TYPE
{
    FMOD_DSP_TYPE_UNKNOWN,            /* This unit was created via a non FMOD plugin so has an unknown purpose. */
    FMOD_DSP_TYPE_MIXER,              /* This unit does nothing but take inputs and mix them together then feed the result to the soundcard unit. */
    FMOD_DSP_TYPE_OSCILLATOR,         /* This unit generates sine/square/saw/triangle or noise tones. */
    FMOD_DSP_TYPE_LOWPASS,            /* This unit filters sound using a high quality, resonant lowpass filter algorithm but consumes more CPU time. */
    FMOD_DSP_TYPE_ITLOWPASS,          /* This unit filters sound using a resonant lowpass filter algorithm that is used in Impulse Tracker, but with limited cutoff range (0 to 8060hz). */
    FMOD_DSP_TYPE_HIGHPASS,           /* This unit filters sound using a resonant highpass filter algorithm. */
    FMOD_DSP_TYPE_ECHO,               /* This unit produces an echo on the sound and fades out at the desired rate. */
    FMOD_DSP_TYPE_FLANGE,             /* This unit produces a flange effect on the sound. */
    FMOD_DSP_TYPE_DISTORTION,         /* This unit distorts the sound. */
    FMOD_DSP_TYPE_NORMALIZE,          /* This unit normalizes or amplifies the sound to a certain level. */
    FMOD_DSP_TYPE_PARAMEQ,            /* This unit attenuates or amplifies a selected frequency range. */
    FMOD_DSP_TYPE_PITCHSHIFT,         /* This unit bends the pitch of a sound without changing the speed of playback. */
    FMOD_DSP_TYPE_CHORUS,             /* This unit produces a chorus effect on the sound. */
    FMOD_DSP_TYPE_REVERB,             /* This unit produces a reverb effect on the sound. */
    FMOD_DSP_TYPE_VSTPLUGIN,          /* This unit allows the use of Steinberg VST plugins */
    FMOD_DSP_TYPE_WINAMPPLUGIN,       /* This unit allows the use of Nullsoft Winamp plugins */
    FMOD_DSP_TYPE_ITECHO,             /* This unit produces an echo on the sound and fades out at the desired rate as is used in Impulse Tracker. */
    FMOD_DSP_TYPE_COMPRESSOR,         /* This unit implements dynamic compression (linked multichannel, wideband) */
    FMOD_DSP_TYPE_SFXREVERB,          /* This unit implements SFX reverb */
    FMOD_DSP_TYPE_LOWPASS_SIMPLE,     /* This unit filters sound using a simple lowpass with no resonance, but has flexible cutoff and is fast. */
    FMOD_DSP_TYPE_FORCEINT = 65536    /* Makes sure this enum is signed 32bit. */
}


/// Parameter types for the FMOD_DSP_TYPE_OSCILLATOR filter.
enum FMOD_DSP_OSCILLATOR
{
    FMOD_DSP_OSCILLATOR_TYPE,   /* Waveform type.  0 = sine.  1 = square. 2 = sawup. 3 = sawdown. 4 = triangle. 5 = noise.  */
    FMOD_DSP_OSCILLATOR_RATE    /* Frequency of the sinewave in hz.  1.0 to 22000.0.  Default = 220.0. */
}


/// Parameter types for the FMOD_DSP_TYPE_LOWPASS filter.
enum FMOD_DSP_LOWPASS
{
    FMOD_DSP_LOWPASS_CUTOFF,    /* Lowpass cutoff frequency in hz.   10.0 to 22000.0.  Default = 5000.0. */
    FMOD_DSP_LOWPASS_RESONANCE  /* Lowpass resonance Q value. 1.0 to 10.0.  Default = 1.0. */
}


/**
    Parameter types for the FMOD_DSP_TYPE_ITLOWPASS filter.
    This is different to the default FMOD_DSP_TYPE_ITLOWPASS filter in that it uses a different quality algorithm and is 
    the filter used to produce the correct sounding playback in .IT files. 
    FMOD Ex's .IT playback uses this filter.
*/
enum FMOD_DSP_ITLOWPASS
{
    FMOD_DSP_ITLOWPASS_CUTOFF,    /* Lowpass cutoff frequency in hz.  1.0 to 22000.0.  Default = 5000.0/ */
    FMOD_DSP_ITLOWPASS_RESONANCE  /* Lowpass resonance Q value.  0.0 to 127.0.  Default = 1.0. */
}


/// Parameter types for the FMOD_DSP_TYPE_HIGHPASS filter.
enum FMOD_DSP_HIGHPASS
{
    FMOD_DSP_HIGHPASS_CUTOFF,    /* Highpass cutoff frequency in hz.  10.0 to output 22000.0.  Default = 5000.0. */
    FMOD_DSP_HIGHPASS_RESONANCE  /* Highpass resonance Q value.  1.0 to 10.0.  Default = 1.0. */
}


/// Parameter types for the FMOD_DSP_TYPE_ECHO filter.
enum FMOD_DSP_ECHO
{
    FMOD_DSP_ECHO_DELAY,       /* Echo delay in ms.  10  to 5000.  Default = 500. */
    FMOD_DSP_ECHO_DECAYRATIO,  /* Echo decay per delay.  0 to 1.  1.0 = No decay, 0.0 = total decay (ie simple 1 line delay).  Default = 0.5. */
    FMOD_DSP_ECHO_MAXCHANNELS, /* Maximum channels supported.  0 to 16.  0 = same as fmod's default output polyphony, 1 = mono, 2 = stereo etc.  See remarks for more.  Default = 0.  It is suggested to leave at 0! */
    FMOD_DSP_ECHO_DRYMIX,      /* Volume of original signal to pass to output.  0.0 to 1.0. Default = 1.0. */
    FMOD_DSP_ECHO_WETMIX       /* Volume of echo signal to pass to output.  0.0 to 1.0. Default = 1.0. */
}


/// Parameter types for the FMOD_DSP_TYPE_FLANGE filter.
enum FMOD_DSP_FLANGE
{
    FMOD_DSP_FLANGE_DRYMIX,      /* Volume of original signal to pass to output.  0.0 to 1.0. Default = 0.45. */
    FMOD_DSP_FLANGE_WETMIX,      /* Volume of flange signal to pass to output.  0.0 to 1.0. Default = 0.55. */
    FMOD_DSP_FLANGE_DEPTH,       /* Flange depth.  0.01 to 1.0.  Default = 1.0. */
    FMOD_DSP_FLANGE_RATE         /* Flange speed in hz.  0.0 to 20.0.  Default = 0.1. */
}


/// Parameter types for the FMOD_DSP_TYPE_DISTORTION filter.
enum FMOD_DSP_DISTORTION
{
    FMOD_DSP_DISTORTION_LEVEL    /* Distortion value.  0.0 to 1.0.  Default = 0.5. */
}


/// Parameter types for the FMOD_DSP_TYPE_NORMALIZE filter.
enum FMOD_DSP_NORMALIZE
{
    FMOD_DSP_NORMALIZE_FADETIME,    /* Time to ramp the silence to full in ms.  0.0 to 20000.0. Default = 5000.0. */
    FMOD_DSP_NORMALIZE_THRESHHOLD,  /* Lower volume range threshold to ignore.  0.0 to 1.0.  Default = 0.1.  Raise higher to stop amplification of very quiet signals. */
    FMOD_DSP_NORMALIZE_MAXAMP       /* Maximum amplification allowed.  1.0 to 100000.0.  Default = 20.0.  1.0 = no amplifaction, higher values allow more boost. */
}


/// Parameter types for the FMOD_DSP_TYPE_PARAMEQ filter.
enum FMOD_DSP_PARAMEQ
{
    FMOD_DSP_PARAMEQ_CENTER,     /* Frequency center.  20.0 to 22000.0.  Default = 8000.0. */
    FMOD_DSP_PARAMEQ_BANDWIDTH,  /* Octave range around the center frequency to filter.  0.2 to 5.0.  Default = 1.0. */
    FMOD_DSP_PARAMEQ_GAIN        /* Frequency Gain.  0.05 to 3.0.  Default = 1.0.  */
}


/// Parameter types for the FMOD_DSP_TYPE_PITCHSHIFT filter.
enum FMOD_DSP_PITCHSHIFT
{
    FMOD_DSP_PITCHSHIFT_PITCH,       /* Pitch value.  0.5 to 2.0.  Default = 1.0. 0.5 = one octave down, 2.0 = one octave up.  1.0 does not change the pitch. */
    FMOD_DSP_PITCHSHIFT_FFTSIZE,     /* FFT window size.  256, 512, 1024, 2048, 4096.  Default = 1024.  Increase this to reduce 'smearing'.  This effect is a warbling sound similar to when an mp3 is encoded at very low bitrates. */
    FMOD_DSP_PITCHSHIFT_OVERLAP,     /* Removed.  Do not use.  FMOD now uses 4 overlaps and cannot be changed. */
    FMOD_DSP_PITCHSHIFT_MAXCHANNELS  /* Maximum channels supported.  0 to 16.  0 = same as fmod's default output polyphony, 1 = mono, 2 = stereo etc.  See remarks for more.  Default = 0.  It is suggested to leave at 0! */
}


/// Parameter types for the FMOD_DSP_TYPE_CHORUS filter.
enum FMOD_DSP_CHORUS
{
    FMOD_DSP_CHORUS_DRYMIX,   /* Volume of original signal to pass to output.  0.0 to 1.0. Default = 0.5. */
    FMOD_DSP_CHORUS_WETMIX1,  /* Volume of 1st chorus tap.  0.0 to 1.0.  Default = 0.5. */
    FMOD_DSP_CHORUS_WETMIX2,  /* Volume of 2nd chorus tap. This tap is 90 degrees out of phase of the first tap.  0.0 to 1.0.  Default = 0.5. */
    FMOD_DSP_CHORUS_WETMIX3,  /* Volume of 3rd chorus tap. This tap is 90 degrees out of phase of the second tap.  0.0 to 1.0.  Default = 0.5. */
    FMOD_DSP_CHORUS_DELAY,    /* Chorus delay in ms.  0.1 to 100.0.  Default = 40.0 ms. */
    FMOD_DSP_CHORUS_RATE,     /* Chorus modulation rate in hz.  0.0 to 20.0.  Default = 0.8 hz. */
    FMOD_DSP_CHORUS_DEPTH,    /* Chorus modulation depth.  0.0 to 1.0.  Default = 0.03. */
    FMOD_DSP_CHORUS_FEEDBACK  /* Chorus feedback.  Controls how much of the wet signal gets fed back into the chorus buffer.  0.0 to 1.0.  Default = 0.0. */
}


/// Parameter types for the FMOD_DSP_TYPE_REVERB filter.
enum FMOD_DSP_REVERB
{
    FMOD_DSP_REVERB_ROOMSIZE, /* Roomsize. 0.0 to 1.0.  Default = 0.5 */
    FMOD_DSP_REVERB_DAMP,     /* Damp.     0.0 to 1.0.  Default = 0.5 */
    FMOD_DSP_REVERB_WETMIX,   /* Wet mix.  0.0 to 1.0.  Default = 0.33 */
    FMOD_DSP_REVERB_DRYMIX,   /* Dry mix.  0.0 to 1.0.  Default = 0.66 */
    FMOD_DSP_REVERB_WIDTH,    /* Stereo width. 0.0 to 1.0.  Default = 1.0 */
    FMOD_DSP_REVERB_MODE      /* Mode.     0 (normal), 1 (freeze).  Default = 0 */
}


/**
    Parameter types for the FMOD_DSP_TYPE_ITECHO filter.
    This is effectively a software based echo filter that emulates the DirectX DMO echo effect.
	Impulse tracker files can support this, and FMOD will produce the effect on ANY platform,
	not just those that support DirectX effects!
*/
enum FMOD_DSP_ITECHO
{
    FMOD_DSP_ITECHO_WETDRYMIX,      /* Ratio of wet (processed) signal to dry (unprocessed) signal. Must be in the range from 0.0 through 100.0 (all wet). The default value is 50. */
    FMOD_DSP_ITECHO_FEEDBACK,       /* Percentage of output fed back into input, in the range from 0.0 through 100.0. The default value is 50. */
    FMOD_DSP_ITECHO_LEFTDELAY,      /* Delay for left channel, in milliseconds, in the range from 1.0 through 2000.0. The default value is 500 ms. */
    FMOD_DSP_ITECHO_RIGHTDELAY,     /* Delay for right channel, in milliseconds, in the range from 1.0 through 2000.0. The default value is 500 ms. */
    FMOD_DSP_ITECHO_PANDELAY        /* Value that specifies whether to swap left and right delays with each successive echo. The default value is zero, meaning no swap. Possible values are defined as 0.0 (equivalent to FALSE) and 1.0 (equivalent to TRUE).  CURRENTLY NOT SUPPORTED. */
}


/**
    Parameter types for the FMOD_DSP_TYPE_COMPRESSOR unit.
    This is a simple linked multichannel software limiter that is uniform across the whole spectrum.
*/
enum FMOD_DSP_COMPRESSOR
{
    FMOD_DSP_COMPRESSOR_THRESHOLD,  /* Threshold level (dB) in the range from -60 through 0. The default value is 0. */ 
    FMOD_DSP_COMPRESSOR_ATTACK,     /* Gain reduction attack time (milliseconds), in the range from 10 through 200. The default value is 50. */
    FMOD_DSP_COMPRESSOR_RELEASE,    /* Gain reduction release time (milliseconds), in the range from 20 through 1000. The default value is 50. */
    FMOD_DSP_COMPRESSOR_GAINMAKEUP  /* Make-up gain (dB) applied after limiting, in the range from 0 through 30. The default value is 0. */
}


/// Parameter types for the FMOD_DSP_TYPE_SFXREVERB unit.
enum FMOD_DSP_SFXREVERB
{
    FMOD_DSP_SFXREVERB_DRYLEVEL,            /* Dry Level      : Mix level of dry signal in output in mB.  Ranges from -10000.0 to 0.0.  Default is 0. */
    FMOD_DSP_SFXREVERB_ROOM,                /* Room           : Room effect level at low frequencies in mB.  Ranges from -10000.0 to 0.0.  Default is 0.0. */
    FMOD_DSP_SFXREVERB_ROOMHF,              /* Room HF        : Room effect high-frequency level re. low frequency level in mB.  Ranges from -10000.0 to 0.0.  Default is 0.0. */
    FMOD_DSP_SFXREVERB_ROOMROLLOFFFACTOR,   /* Room Rolloff   : Like DS3D flRolloffFactor but for room effect.  Ranges from 0.0 to 10.0. Default is 10.0 */
    FMOD_DSP_SFXREVERB_DECAYTIME,           /* Decay Time     : Reverberation decay time at low-frequencies in seconds.  Ranges from 0.1 to 20.0. Default is 1.0. */
    FMOD_DSP_SFXREVERB_DECAYHFRATIO,        /* Decay HF Ratio : High-frequency to low-frequency decay time ratio.  Ranges from 0.1 to 2.0. Default is 0.5. */
    FMOD_DSP_SFXREVERB_REFLECTIONSLEVEL,    /* Reflections    : Early reflections level relative to room effect in mB.  Ranges from -10000.0 to 1000.0.  Default is -10000.0. */
    FMOD_DSP_SFXREVERB_REFLECTIONSDELAY,    /* Reflect Delay  : Delay time of first reflection in seconds.  Ranges from 0.0 to 0.3.  Default is 0.02. */
    FMOD_DSP_SFXREVERB_REVERBLEVEL,         /* Reverb         : Late reverberation level relative to room effect in mB.  Ranges from -10000.0 to 2000.0.  Default is 0.0. */
    FMOD_DSP_SFXREVERB_REVERBDELAY,         /* Reverb Delay   : Late reverberation delay time relative to first reflection in seconds.  Ranges from 0.0 to 0.1.  Default is 0.04. */
    FMOD_DSP_SFXREVERB_DIFFUSION,           /* Diffusion      : Reverberation diffusion (echo density) in percent.  Ranges from 0.0 to 100.0.  Default is 100.0. */
    FMOD_DSP_SFXREVERB_DENSITY,             /* Density        : Reverberation density (modal density) in percent.  Ranges from 0.0 to 100.0.  Default is 100.0. */
    FMOD_DSP_SFXREVERB_HFREFERENCE          /* HF Reference   : Reference high frequency in Hz.  Ranges from 20.0 to 20000.0. Default is 5000.0. */
}


/**
    Parameter types for the FMOD_DSP_TYPE_LOWPASS_SIMPLE filter.
    This is a very simple low pass filter, based on two single-pole RC time-constant modules.
    The emphasis is on speed rather than accuracy, so this should not be used for task requiring critical filtering. 
*/
enum FMOD_DSP_LOWPASS_SIMPLE
{
    FMOD_DSP_LOWPASS_SIMPLE_CUTOFF     /* Lowpass cutoff frequency in hz.  10.0 to 22000.0.  Default = 5000.0 */
}
