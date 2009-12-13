module fmodex.FmodExDefines;

private import fmodex.FmodExTypes;
private import fmodex.FmodExEnums;


const uint FMOD_VERSION = 0x00040612;


/// Bit fields to use with System::getDriverCaps to determine the capabilities of a card / output device.
const uint FMOD_CAPS_NONE = 0x00000000;  /* Device has no special capabilities. */
const uint FMOD_CAPS_HARDWARE = 0x00000001;  /* Device supports hardware mixing. */
const uint FMOD_CAPS_HARDWARE_EMULATED = 0x00000002;  /* Device supports FMOD_HARDWARE but it will be mixed on the CPU by the kernel (not FMOD's software mixer). */
const uint FMOD_CAPS_OUTPUT_MULTICHANNEL = 0x00000004;  /* Device can do multichannel output, ie greater than 2 channels. */
const uint FMOD_CAPS_OUTPUT_FORMAT_PCM8 = 0x00000008;  /* Device can output to 8bit integer PCM. */
const uint FMOD_CAPS_OUTPUT_FORMAT_PCM16 = 0x00000010;  /* Device can output to 16bit integer PCM. */
const uint FMOD_CAPS_OUTPUT_FORMAT_PCM24 = 0x00000020;  /* Device can output to 24bit integer PCM. */
const uint FMOD_CAPS_OUTPUT_FORMAT_PCM32 = 0x00000040;  /* Device can output to 32bit integer PCM. */
const uint FMOD_CAPS_OUTPUT_FORMAT_PCMFLOAT = 0x00000080;  /* Device can output to 32bit floating point PCM. */
const uint FMOD_CAPS_REVERB_EAX2 = 0x00000100;  /* Device supports EAX2 reverb. */
const uint FMOD_CAPS_REVERB_EAX3 = 0x00000200;  /* Device supports EAX3 reverb. */
const uint FMOD_CAPS_REVERB_EAX4 = 0x00000400;  /* Device supports EAX4 reverb  */
const uint FMOD_CAPS_REVERB_I3DL2 = 0x00000800;  /* Device supports I3DL2 reverb. */
const uint FMOD_CAPS_REVERB_LIMITED = 0x00001000;  /* Device supports some form of limited hardware reverb, maybe parameterless and only selectable by environment. */


/**
	Bit fields to use with FMOD::Debug_SetLevel / FMOD::Debug_GetLevel to control the level of tty
	debug output with logging versions of FMOD (fmodL).
*/
const uint FMOD_DEBUG_LEVEL_NONE = 0x00000000;
const uint FMOD_DEBUG_LEVEL_LOG = 0x00000001;
const uint FMOD_DEBUG_LEVEL_ERROR = 0x00000002;
const uint FMOD_DEBUG_LEVEL_WARNING = 0x00000004;
const uint FMOD_DEBUG_LEVEL_HINT = 0x00000008;
const uint FMOD_DEBUG_LEVEL_ALL = 0x000000FF;
const uint FMOD_DEBUG_TYPE_MEMORY = 0x00000100;
const uint FMOD_DEBUG_TYPE_THREAD = 0x00000200;
const uint FMOD_DEBUG_TYPE_FILE = 0x00000400;
const uint FMOD_DEBUG_TYPE_NET = 0x00000800;
const uint FMOD_DEBUG_TYPE_EVENT = 0x00001000;
const uint FMOD_DEBUG_TYPE_ALL = 0x0000FFFF;
const uint FMOD_DEBUG_DISPLAY_TIMESTAMPS = 0x01000000;
const uint FMOD_DEBUG_DISPLAY_LINENUMBERS = 0x02000000;
const uint FMOD_DEBUG_DISPLAY_COMPRESS = 0x04000000;
const uint FMOD_DEBUG_DISPLAY_ALL = 0x0F000000;
const uint FMOD_DEBUG_ALL = 0xFFFFFFFF;


/// Bit fields for memory allocation type being passed into FMOD memory callbacks.
const uint FMOD_MEMORY_NORMAL = 0x00000000;       /* Standard memory. */
const uint FMOD_MEMORY_XBOX360_PHYSICAL = 0x00100000;       /* Requires XPhysicalAlloc / XPhysicalFree. */


/// Initialization flags.  Use them with System::init in the flags parameter to change various behaviour.
const uint FMOD_INIT_NORMAL = 0x00000000; /* All platforms - Initialize normally */
const uint FMOD_INIT_STREAM_FROM_UPDATE = 0x00000001; /* All platforms - No stream thread is created internally.  Streams are driven from System::update.  Mainly used with non-realtime outputs. */
const uint FMOD_INIT_3D_RIGHTHANDED = 0x00000002; /* All platforms - FMOD will treat +X as left, +Y as up and +Z as forwards. */
const uint FMOD_INIT_DISABLESOFTWARE = 0x00000004; /* All platforms - Disable software mixer to save memory.  Anything created with FMOD_SOFTWARE will fail and DSP will not work. */
const uint FMOD_INIT_OCCLUSION_LOWPASS = 0x00000008; /* All platforms - All FMOD_SOFTWARE with FMOD_3D based voices will add a software lowpass filter effect into the DSP chain which is automatically used when Channel::set3DOcclusion is used or the geometry API. */
const uint FMOD_INIT_DSOUND_HRTFNONE = 0x00000200; /* Win32 only - for DirectSound output - FMOD_HARDWARE | FMOD_3D buffers use simple stereo panning/doppler/attenuation when 3D hardware acceleration is not present. */
const uint FMOD_INIT_DSOUND_HRTFLIGHT = 0x00000400; /* Win32 only - for DirectSound output - FMOD_HARDWARE | FMOD_3D buffers use a slightly higher quality algorithm when 3D hardware acceleration is not present. */
const uint FMOD_INIT_DSOUND_HRTFFULL = 0x00000800; /* Win32 only - for DirectSound output - FMOD_HARDWARE | FMOD_3D buffers use full quality 3D playback when 3d hardware acceleration is not present. */
const uint FMOD_INIT_PS2_DISABLECORE0REVERB = 0x00010000; /* PS2 only - Disable reverb on CORE 0 to regain 256k SRAM. */
const uint FMOD_INIT_PS2_DISABLECORE1REVERB = 0x00020000; /* PS2 only - Disable reverb on CORE 1 to regain 256k SRAM. */
const uint FMOD_INIT_PS2_DONTUSESCRATCHPAD = 0x00040000; /* PS2 only - Disable FMOD's usage of the scratchpad. */
const uint FMOD_INIT_PS2_SWAPDMACHANNELS = 0x00080000; /* PS2 only - Changes FMOD from using SPU DMA channel 0 for software mixing, and 1 for sound data upload/file streaming, to 1 and 0 respectively. */
const uint FMOD_INIT_XBOX_REMOVEHEADROOM = 0x00100000; /* Xbox only - By default DirectSound attenuates all sound by 6db to avoid clipping/distortion.  CAUTION.  If you use this flag you are responsible for the final mix to make sure clipping / distortion doesn't happen. */
const uint FMOD_INIT_360_MUSICMUTENOTPAUSE = 0x00200000; /* Xbox 360 only - The "music" channelgroup which by default pauses when custom 360 dashboard music is played, can be changed to mute (therefore continues playing) instead of pausing, by using this flag. */


/// Sound description bitfields, bitwise OR them together for loading and describing sounds.
const uint FMOD_DEFAULT = 0x00000000;  /* FMOD_DEFAULT is a default sound type.  Equivalent to all the defaults listed below.  FMOD_LOOP_OFF, FMOD_2D, FMOD_HARDWARE. */
const uint FMOD_LOOP_OFF = 0x00000001;  /* For non looping sounds. (DEFAULT).  Overrides FMOD_LOOP_NORMAL / FMOD_LOOP_BIDI. */
const uint FMOD_LOOP_NORMAL = 0x00000002;  /* For forward looping sounds. */
const uint FMOD_LOOP_BIDI = 0x00000004;  /* For bidirectional looping sounds. (only works on software mixed static sounds). */
const uint FMOD_2D = 0x00000008;  /* Ignores any 3d processing. (DEFAULT). */
const uint FMOD_3D = 0x00000010;  /* Makes the sound positionable in 3D.  Overrides FMOD_2D. */
const uint FMOD_HARDWARE = 0x00000020;  /* Attempts to make sounds use hardware acceleration. (DEFAULT). */
const uint FMOD_SOFTWARE= 0x00000040;  /* Makes the sound be mixed by the FMOD CPU based software mixer.  Overrides FMOD_HARDWARE.  Use this for FFT, DSP, compressed sample support, 2D multi-speaker support and other software related features. */
const uint FMOD_CREATESTREAM = 0x00000080;  /* Decompress at runtime, streaming from the source provided (ie from disk).  Overrides FMOD_CREATESAMPLE and FMOD_CREATECOMPRESSEDSAMPLE.  Note a stream can only be played once at a time due to a stream only having 1 stream buffer and file handle.  Open multiple streams to have them play concurrently. */
const uint FMOD_CREATESAMPLE = 0x00000100;  /* Decompress at loadtime, decompressing or decoding whole file into memory as the target sample format (ie PCM).  Fastest for playback and most flexible.  */
const uint FMOD_CREATECOMPRESSEDSAMPLE = 0x00000200;  /* Load MP2, MP3, IMAADPCM or XMA into memory and leave it compressed.  During playback the FMOD software mixer will decode it in realtime as a 'compressed sample'.  Can only be used in combination with FMOD_SOFTWARE.  Overrides FMOD_CREATESAMPLE.  If the sound data is not ADPCM, MPEG or XMA it will behave as if it was created with FMOD_CREATESAMPLE and decode the sound into PCM. */
const uint FMOD_OPENUSER = 0x00000400;  /* Opens a user created static sample or stream. Use FMOD_CREATESOUNDEXINFO to specify format and/or read callbacks.  If a user created 'sample' is created with no read callback, the sample will be empty.  Use Sound::lock and Sound::unlock to place sound data into the sound if this is the case. */
const uint FMOD_OPENMEMORY = 0x00000800;  /* "name_or_data" will be interpreted as a pointer to memory instead of filename for creating sounds.  Use FMOD_CREATESOUNDEXINFO to specify length.  FMOD duplicates the memory into its own buffers.  Can be freed after open. */
const uint FMOD_OPENMEMORY_POINT = 0x10000000;  /* "name_or_data" will be interpreted as a pointer to memory instead of filename for creating sounds.  Use FMOD_CREATESOUNDEXINFO to specify length.  This differs to FMOD_OPENMEMORY in that it uses the memory as is, without duplicating the memory into its own buffers.  FMOD_SOFTWARE only.  Doesn't work with FMOD_HARDWARE, as sound hardware cannot access main ram on a lot of platforms.  Cannot be freed after open, only after Sound::release.   Will not work if the data is compressed and FMOD_CREATECOMPRESSEDSAMPLE is not used. */
const uint FMOD_OPENRAW = 0x00001000;  /* Will ignore file format and treat as raw pcm.  Use FMOD_CREATESOUNDEXINFO to specify format.  Requires at least defaultfrequency, numchannels and format to be specified before it will open.  Must be little endian data. */
const uint FMOD_OPENONLY = 0x00002000;  /* Just open the file, dont prebuffer or read.  Good for fast opens for info, or when sound::readData is to be used. */
const uint FMOD_ACCURATETIME = 0x00004000;  /* For System::createSound - for accurate Sound::getLength/Channel::setPosition on VBR MP3, and MOD/S3M/XM/IT/MIDI files.  Scans file first, so takes longer to open. FMOD_OPENONLY does not affect this. */
const uint FMOD_MPEGSEARCH = 0x00008000;  /* For corrupted / bad MP3 files.  This will search all the way through the file until it hits a valid MPEG header.  Normally only searches for 4k. */
const uint FMOD_NONBLOCKING = 0x00010000;  /* For opening sounds and getting streamed subsounds (seeking) asyncronously.  Use Sound::getOpenState to poll the state of the sound as it opens or retrieves the subsound in the background. */
const uint FMOD_UNIQUE = 0x00020000;  /* Unique sound, can only be played one at a time */
const uint FMOD_3D_HEADRELATIVE = 0x00040000;  /* Make the sound's position, velocity and orientation relative to the listener. */
const uint FMOD_3D_WORLDRELATIVE = 0x00080000;  /* Make the sound's position, velocity and orientation absolute (relative to the world). (DEFAULT) */
const uint FMOD_3D_LOGROLLOFF = 0x00100000;  /* This sound will follow the standard logarithmic rolloff model where mindistance = full volume, maxdistance = where sound stops attenuating, and rolloff is fixed according to the global rolloff factor.  (DEFAULT) */
const uint FMOD_3D_LINEARROLLOFF = 0x00200000;  /* This sound will follow a linear rolloff model where mindistance = full volume, maxdistance = silence.  Rolloffscale is ignored. */
const uint FMOD_3D_CUSTOMROLLOFF = 0x04000000;  /* This sound will follow a rolloff model defined by Sound::set3DCustomRolloff / Channel::set3DCustomRolloff.  */
const uint FMOD_3D_IGNOREGEOMETRY = 0x40000000;  /* Is not affect by geometry occlusion.  If not specified in Sound::setMode, or Channel::setMode, the flag is cleared and it is affected by geometry again. */
const uint FMOD_CDDA_FORCEASPI = 0x00400000;  /* For CDDA sounds only - use ASPI instead of NTSCSI to access the specified CD/DVD device. */
const uint FMOD_CDDA_JITTERCORRECT = 0x00800000;  /* For CDDA sounds only - perform jitter correction. Jitter correction helps produce a more accurate CDDA stream at the cost of more CPU time. */
const uint FMOD_UNICODE = 0x01000000;  /* Filename is double-byte unicode. */
const uint FMOD_IGNORETAGS = 0x02000000;  /* Skips id3v2/asf/etc tag checks when opening a sound, to reduce seek/read overhead when opening files (helps with CD performance). */
const uint FMOD_LOWMEM = 0x08000000;  /* Removes some features from samples to give a lower memory overhead, like Sound::getName.  See remarks. */
const uint FMOD_LOADSECONDARYRAM = 0x20000000;  /* Load sound into the secondary RAM of supported platform.  On PS3, sounds will be loaded into RSX/VRAM. */


/// List of time types that can be returned by Sound::getLength and used with Channel::setPosition or Channel::getPosition.
const uint FMOD_TIMEUNIT_MS = 0x00000001;  /* Milliseconds. */
const uint FMOD_TIMEUNIT_PCM = 0x00000002;  /* PCM Samples, related to milliseconds * samplerate / 1000. */
const uint FMOD_TIMEUNIT_PCMBYTES = 0x00000004;  /* Bytes, related to PCM samples * channels * datawidth (ie 16bit = 2 bytes). */
const uint FMOD_TIMEUNIT_RAWBYTES = 0x00000008;  /* Raw file bytes of (compressed) sound data (does not include headers).  Only used by Sound::getLength and Channel::getPosition. */
const uint FMOD_TIMEUNIT_MODORDER = 0x00000100;  /* MOD/S3M/XM/IT.  Order in a sequenced module format.  Use Sound::getFormat to determine the PCM format being decoded to. */
const uint FMOD_TIMEUNIT_MODROW = 0x00000200;  /* MOD/S3M/XM/IT.  Current row in a sequenced module format.  Sound::getLength will return the number of rows in the currently playing or seeked to pattern. */
const uint FMOD_TIMEUNIT_MODPATTERN = 0x00000400;  /* MOD/S3M/XM/IT.  Current pattern in a sequenced module format.  Sound::getLength will return the number of patterns in the song and Channel::getPosition will return the currently playing pattern. */
const uint FMOD_TIMEUNIT_SENTENCE_MS = 0x00010000;  /* Currently playing subsound in a sentence time in milliseconds. */
const uint FMOD_TIMEUNIT_SENTENCE_PCM = 0x00020000;  /* Currently playing subsound in a sentence time in PCM Samples, related to milliseconds * samplerate / 1000. */
const uint FMOD_TIMEUNIT_SENTENCE_PCMBYTES = 0x00040000;  /* Currently playing subsound in a sentence time in bytes, related to PCM samples * channels * datawidth (ie 16bit = 2 bytes). */
const uint FMOD_TIMEUNIT_SENTENCE = 0x00080000;  /* Currently playing sentence index according to the channel. */
const uint FMOD_TIMEUNIT_SENTENCE_SUBSOUND = 0x00100000;  /* Currently playing subsound index in a sentence. */
const uint FMOD_TIMEUNIT_BUFFERED = 0x10000000;  /* Time value as seen by buffered stream.  This is always ahead of audible time, and is only used for processing. */


/// Values for the Flags member of the FMOD_REVERB_PROPERTIES structure.
const uint FMOD_REVERB_FLAGS_DECAYTIMESCALE = 0x00000001; /* 'EnvSize' affects reverberation decay time */
const uint FMOD_REVERB_FLAGS_REFLECTIONSSCALE = 0x00000002; /* 'EnvSize' affects reflection level */
const uint FMOD_REVERB_FLAGS_REFLECTIONSDELAYSCALE = 0x00000004; /* 'EnvSize' affects initial reflection delay time */
const uint FMOD_REVERB_FLAGS_REVERBSCALE = 0x00000008; /* 'EnvSize' affects reflections level */
const uint FMOD_REVERB_FLAGS_REVERBDELAYSCALE = 0x00000010; /* 'EnvSize' affects late reverberation delay time */
const uint FMOD_REVERB_FLAGS_DECAYHFLIMIT = 0x00000020; /* AirAbsorptionHF affects DecayHFRatio */
const uint FMOD_REVERB_FLAGS_ECHOTIMESCALE = 0x00000040; /* 'EnvSize' affects echo time */
const uint FMOD_REVERB_FLAGS_MODULATIONTIMESCALE = 0x00000080; /* 'EnvSize' affects modulation time */
const uint FMOD_REVERB_FLAGS_CORE0 = 0x00000100; /* PS2 Only - Reverb is applied to CORE0 (hw voices 0-23) */
const uint FMOD_REVERB_FLAGS_CORE1 = 0x00000200; /* PS2 Only - Reverb is applied to CORE1 (hw voices 24-47) */
const uint FMOD_REVERB_FLAGS_HIGHQUALITYREVERB = 0x00000400; /* GameCube/Wii. Use high quality reverb */
const uint FMOD_REVERB_FLAGS_HIGHQUALITYDPL2REVERB = 0x00000800; /* GameCube/Wii. Use high quality DPL2 reverb */

const uint FMOD_REVERB_FLAGS_DEFAULT = (FMOD_REVERB_FLAGS_DECAYTIMESCALE | FMOD_REVERB_FLAGS_REFLECTIONSSCALE |
                                                FMOD_REVERB_FLAGS_REFLECTIONSDELAYSCALE | FMOD_REVERB_FLAGS_REVERBSCALE |
                                                FMOD_REVERB_FLAGS_REVERBDELAYSCALE | FMOD_REVERB_FLAGS_DECAYHFLIMIT |
                                                FMOD_REVERB_FLAGS_CORE0 | FMOD_REVERB_FLAGS_CORE1);
												
												

/**											
	A set of predefined environment PARAMETERS, created by Creative Labs
    These are used to initialize an FMOD_REVERB_PROPERTIES structure statically.
    ie 
    FMOD_REVERB_PROPERTIES prop = FMOD_PRESET_GENERIC;
*/
const FMOD_REVERB_PROPERTIES FMOD_PRESET_OFF = {  0, -1,  7.5f,   1.00f, -10000, -10000, 0,   1.00f,  1.00f, 1.0f,  -2602, 0.007f, [ 0.0f,0.0f,0.0f ],   200, 0.011f, [ 0.0f,0.0f,0.0f ], 0.250f, 0.00f, 0.25f, 0.000f, -5.0f, 5000.0f, 250.0f, 0.0f,   0.0f,   0.0f, 0x33f };
const FMOD_REVERB_PROPERTIES FMOD_PRESET_GENERIC = {  0,  0,  7.5f,   1.00f, -1000,  -100,   0,   1.49f,  0.83f, 1.0f,  -2602, 0.007f, [ 0.0f,0.0f,0.0f ],   200, 0.011f, [ 0.0f,0.0f,0.0f ], 0.250f, 0.00f, 0.25f, 0.000f, -5.0f, 5000.0f, 250.0f, 0.0f, 100.0f, 100.0f, 0x3f };
const FMOD_REVERB_PROPERTIES FMOD_PRESET_PADDEDCELL = {  0,  1,  1.4f,   1.00f, -1000,  -6000,  0,   0.17f,  0.10f, 1.0f,  -1204, 0.001f, [ 0.0f,0.0f,0.0f ],   207, 0.002f, [ 0.0f,0.0f,0.0f ], 0.250f, 0.00f, 0.25f, 0.000f, -5.0f, 5000.0f, 250.0f, 0.0f, 100.0f, 100.0f, 0x3f };
const FMOD_REVERB_PROPERTIES FMOD_PRESET_ROOM = {  0,  2,  1.9f,   1.00f, -1000,  -454,   0,   0.40f,  0.83f, 1.0f,  -1646, 0.002f, [ 0.0f,0.0f,0.0f ],    53, 0.003f, [ 0.0f,0.0f,0.0f ], 0.250f, 0.00f, 0.25f, 0.000f, -5.0f, 5000.0f, 250.0f, 0.0f, 100.0f, 100.0f, 0x3f };
const FMOD_REVERB_PROPERTIES FMOD_PRESET_BATHROOM = {  0,  3,  1.4f,   1.00f, -1000,  -1200,  0,   1.49f,  0.54f, 1.0f,   -370, 0.007f, [ 0.0f,0.0f,0.0f ],  1030, 0.011f, [ 0.0f,0.0f,0.0f ], 0.250f, 0.00f, 0.25f, 0.000f, -5.0f, 5000.0f, 250.0f, 0.0f, 100.0f,  60.0f, 0x3f };
const FMOD_REVERB_PROPERTIES FMOD_PRESET_LIVINGROOM = {  0,  4,  2.5f,   1.00f, -1000,  -6000,  0,   0.50f,  0.10f, 1.0f,  -1376, 0.003f, [ 0.0f,0.0f,0.0f ], -1104, 0.004f, [ 0.0f,0.0f,0.0f ], 0.250f, 0.00f, 0.25f, 0.000f, -5.0f, 5000.0f, 250.0f, 0.0f, 100.0f, 100.0f, 0x3f };
const FMOD_REVERB_PROPERTIES FMOD_PRESET_STONEROOM = {  0,  5,  11.6f,  1.00f, -1000,  -300,   0,   2.31f,  0.64f, 1.0f,   -711, 0.012f, [ 0.0f,0.0f,0.0f ],    83, 0.017f, [ 0.0f,0.0f,0.0f ], 0.250f, 0.00f, 0.25f, 0.000f, -5.0f, 5000.0f, 250.0f, 0.0f, 100.0f, 100.0f, 0x3f };
const FMOD_REVERB_PROPERTIES FMOD_PRESET_AUDITORIUM = {  0,  6,  21.6f,  1.00f, -1000,  -476,   0,   4.32f,  0.59f, 1.0f,   -789, 0.020f, [ 0.0f,0.0f,0.0f ],  -289, 0.030f, [ 0.0f,0.0f,0.0f ], 0.250f, 0.00f, 0.25f, 0.000f, -5.0f, 5000.0f, 250.0f, 0.0f, 100.0f, 100.0f, 0x3f };
const FMOD_REVERB_PROPERTIES FMOD_PRESET_CONCERTHALL = {  0,  7,  19.6f,  1.00f, -1000,  -500,   0,   3.92f,  0.70f, 1.0f,  -1230, 0.020f, [ 0.0f,0.0f,0.0f ],    -2, 0.029f, [ 0.0f,0.0f,0.0f ], 0.250f, 0.00f, 0.25f, 0.000f, -5.0f, 5000.0f, 250.0f, 0.0f, 100.0f, 100.0f, 0x3f };
const FMOD_REVERB_PROPERTIES FMOD_PRESET_CAVE = {  0,  8,  14.6f,  1.00f, -1000,  0,      0,   2.91f,  1.30f, 1.0f,   -602, 0.015f, [ 0.0f,0.0f,0.0f ],  -302, 0.022f, [ 0.0f,0.0f,0.0f ], 0.250f, 0.00f, 0.25f, 0.000f, -5.0f, 5000.0f, 250.0f, 0.0f, 100.0f, 100.0f, 0x1f };
const FMOD_REVERB_PROPERTIES FMOD_PRESET_ARENA = {  0,  9,  36.2f,  1.00f, -1000,  -698,   0,   7.24f,  0.33f, 1.0f,  -1166, 0.020f, [ 0.0f,0.0f,0.0f ],    16, 0.030f, [ 0.0f,0.0f,0.0f ], 0.250f, 0.00f, 0.25f, 0.000f, -5.0f, 5000.0f, 250.0f, 0.0f, 100.0f, 100.0f, 0x3f };
const FMOD_REVERB_PROPERTIES FMOD_PRESET_HANGAR = {  0,  10, 50.3f,  1.00f, -1000,  -1000,  0,   10.05f, 0.23f, 1.0f,   -602, 0.020f, [ 0.0f,0.0f,0.0f ],   198, 0.030f, [ 0.0f,0.0f,0.0f ], 0.250f, 0.00f, 0.25f, 0.000f, -5.0f, 5000.0f, 250.0f, 0.0f, 100.0f, 100.0f, 0x3f };
const FMOD_REVERB_PROPERTIES FMOD_PRESET_CARPETTEDHALLWAY = {  0,  11, 1.9f,   1.00f, -1000,  -4000,  0,   0.30f,  0.10f, 1.0f,  -1831, 0.002f, [ 0.0f,0.0f,0.0f ], -1630, 0.030f, [ 0.0f,0.0f,0.0f ], 0.250f, 0.00f, 0.25f, 0.000f, -5.0f, 5000.0f, 250.0f, 0.0f, 100.0f, 100.0f, 0x3f };
const FMOD_REVERB_PROPERTIES FMOD_PRESET_HALLWAY = {  0,  12, 1.8f,   1.00f, -1000,  -300,   0,   1.49f,  0.59f, 1.0f,  -1219, 0.007f, [ 0.0f,0.0f,0.0f ],   441, 0.011f, [ 0.0f,0.0f,0.0f ], 0.250f, 0.00f, 0.25f, 0.000f, -5.0f, 5000.0f, 250.0f, 0.0f, 100.0f, 100.0f, 0x3f };
const FMOD_REVERB_PROPERTIES FMOD_PRESET_STONECORRIDOR = {  0,  13, 13.5f,  1.00f, -1000,  -237,   0,   2.70f,  0.79f, 1.0f,  -1214, 0.013f, [ 0.0f,0.0f,0.0f ],   395, 0.020f, [ 0.0f,0.0f,0.0f ], 0.250f, 0.00f, 0.25f, 0.000f, -5.0f, 5000.0f, 250.0f, 0.0f, 100.0f, 100.0f, 0x3f };
const FMOD_REVERB_PROPERTIES FMOD_PRESET_ALLEY = {  0,  14, 7.5f,   0.30f, -1000,  -270,   0,   1.49f,  0.86f, 1.0f,  -1204, 0.007f, [ 0.0f,0.0f,0.0f ],    -4, 0.011f, [ 0.0f,0.0f,0.0f ], 0.125f, 0.95f, 0.25f, 0.000f, -5.0f, 5000.0f, 250.0f, 0.0f, 100.0f, 100.0f, 0x3f };
const FMOD_REVERB_PROPERTIES FMOD_PRESET_FOREST = {  0,  15, 38.0f,  0.30f, -1000,  -3300,  0,   1.49f,  0.54f, 1.0f,  -2560, 0.162f, [ 0.0f,0.0f,0.0f ],  -229, 0.088f, [ 0.0f,0.0f,0.0f ], 0.125f, 1.00f, 0.25f, 0.000f, -5.0f, 5000.0f, 250.0f, 0.0f,  79.0f, 100.0f, 0x3f };
const FMOD_REVERB_PROPERTIES FMOD_PRESET_CITY = {  0,  16, 7.5f,   0.50f, -1000,  -800,   0,   1.49f,  0.67f, 1.0f,  -2273, 0.007f, [ 0.0f,0.0f,0.0f ], -1691, 0.011f, [ 0.0f,0.0f,0.0f ], 0.250f, 0.00f, 0.25f, 0.000f, -5.0f, 5000.0f, 250.0f, 0.0f,  50.0f, 100.0f, 0x3f };
const FMOD_REVERB_PROPERTIES FMOD_PRESET_MOUNTAINS = {  0,  17, 100.0f, 0.27f, -1000,  -2500,  0,   1.49f,  0.21f, 1.0f,  -2780, 0.300f, [ 0.0f,0.0f,0.0f ], -1434, 0.100f, [ 0.0f,0.0f,0.0f ], 0.250f, 1.00f, 0.25f, 0.000f, -5.0f, 5000.0f, 250.0f, 0.0f,  27.0f, 100.0f, 0x1f };
const FMOD_REVERB_PROPERTIES FMOD_PRESET_QUARRY = {  0,  18, 17.5f,  1.00f, -1000,  -1000,  0,   1.49f,  0.83f, 1.0f, -10000, 0.061f, [ 0.0f,0.0f,0.0f ],   500, 0.025f, [ 0.0f,0.0f,0.0f ], 0.125f, 0.70f, 0.25f, 0.000f, -5.0f, 5000.0f, 250.0f, 0.0f, 100.0f, 100.0f, 0x3f };
const FMOD_REVERB_PROPERTIES FMOD_PRESET_PLAIN = {  0,  19, 42.5f,  0.21f, -1000,  -2000,  0,   1.49f,  0.50f, 1.0f,  -2466, 0.179f, [ 0.0f,0.0f,0.0f ], -1926, 0.100f, [ 0.0f,0.0f,0.0f ], 0.250f, 1.00f, 0.25f, 0.000f, -5.0f, 5000.0f, 250.0f, 0.0f,  21.0f, 100.0f, 0x3f };
const FMOD_REVERB_PROPERTIES FMOD_PRESET_PARKINGLOT = {  0,  20, 8.3f,   1.00f, -1000,  0,      0,   1.65f,  1.50f, 1.0f,  -1363, 0.008f, [ 0.0f,0.0f,0.0f ], -1153, 0.012f, [ 0.0f,0.0f,0.0f ], 0.250f, 0.00f, 0.25f, 0.000f, -5.0f, 5000.0f, 250.0f, 0.0f, 100.0f, 100.0f, 0x1f };
const FMOD_REVERB_PROPERTIES FMOD_PRESET_SEWERPIPE = {  0,  21, 1.7f,   0.80f, -1000,  -1000,  0,   2.81f,  0.14f, 1.0f,    429, 0.014f, [ 0.0f,0.0f,0.0f ],  1023, 0.021f, [ 0.0f,0.0f,0.0f ], 0.250f, 0.00f, 0.25f, 0.000f, -5.0f, 5000.0f, 250.0f, 0.0f,  80.0f,  60.0f, 0x3f };
const FMOD_REVERB_PROPERTIES FMOD_PRESET_UNDERWATER = {  0,  22, 1.8f,   1.00f, -1000,  -4000,  0,   1.49f,  0.10f, 1.0f,   -449, 0.007f, [ 0.0f,0.0f,0.0f ],  1700, 0.011f, [ 0.0f,0.0f,0.0f ], 0.250f, 0.00f, 1.18f, 0.348f, -5.0f, 5000.0f, 250.0f, 0.0f, 100.0f, 100.0f, 0x3f };

/* Non I3DL2 presets */

const FMOD_REVERB_PROPERTIES FMOD_PRESET_DRUGGED = {  0,  23, 1.9f,   0.50f, -1000,  0,      0,   8.39f,  1.39f, 1.0f,  -115,  0.002f, [ 0.0f,0.0f,0.0f ],   985, 0.030f, [ 0.0f,0.0f,0.0f ], 0.250f, 0.00f, 0.25f, 1.000f, -5.0f, 5000.0f, 250.0f, 0.0f, 100.0f, 100.0f, 0x1f };
const FMOD_REVERB_PROPERTIES FMOD_PRESET_DIZZY = {  0,  24, 1.8f,   0.60f, -1000,  -400,   0,   17.23f, 0.56f, 1.0f,  -1713, 0.020f, [ 0.0f,0.0f,0.0f ],  -613, 0.030f, [ 0.0f,0.0f,0.0f ], 0.250f, 1.00f, 0.81f, 0.310f, -5.0f, 5000.0f, 250.0f, 0.0f, 100.0f, 100.0f, 0x1f };
const FMOD_REVERB_PROPERTIES FMOD_PRESET_PSYCHOTIC = {  0,  25, 1.0f,   0.50f, -1000,  -151,   0,   7.56f,  0.91f, 1.0f,  -626,  0.020f, [ 0.0f,0.0f,0.0f ],   774, 0.030f, [ 0.0f,0.0f,0.0f ], 0.250f, 0.00f, 4.00f, 1.000f, -5.0f, 5000.0f, 250.0f, 0.0f, 100.0f, 100.0f, 0x1f };


/// Values for the Flags member of the FMOD_REVERB_CHANNELPROPERTIES structure.
const uint FMOD_REVERB_CHANNELFLAGS_DIRECTHFAUTO = 0x00000001; /* Automatic setting of 'Direct'  due to distance from listener */
const uint FMOD_REVERB_CHANNELFLAGS_ROOMAUTO = 0x00000002; /* Automatic setting of 'Room'  due to distance from listener */
const uint FMOD_REVERB_CHANNELFLAGS_ROOMHFAUTO = 0x00000004; /* Automatic setting of 'RoomHF' due to distance from listener */
const uint FMOD_REVERB_CHANNELFLAGS_ENVIRONMENT0 = 0x00000008; /* EAX4/GameCube/Wii. Specify channel to target reverb instance 0. */
const uint FMOD_REVERB_CHANNELFLAGS_ENVIRONMENT1 = 0x00000010; /* EAX4/GameCube/Wii. Specify channel to target reverb instance 1. */
const uint FMOD_REVERB_CHANNELFLAGS_ENVIRONMENT2 = 0x00000020; /* EAX4/GameCube/Wii. Specify channel to target reverb instance 2. */

const uint FMOD_REVERB_CHANNELFLAGS_DEFAULT = (FMOD_REVERB_CHANNELFLAGS_DIRECTHFAUTO |
                                                FMOD_REVERB_CHANNELFLAGS_ROOMAUTO|
                                                FMOD_REVERB_CHANNELFLAGS_ROOMHFAUTO| FMOD_REVERB_CHANNELFLAGS_ENVIRONMENT0);
