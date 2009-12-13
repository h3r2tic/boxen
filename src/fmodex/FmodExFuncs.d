module fmodex.FmodExFuncs;

private import fmodex.FmodExEnums;
private import fmodex.FmodExTypes;
private import fmodex.FmodExDefines;

private import tango.sys.SharedLib;
private import tango.io.Stdout;
private import tango.stdc.stringz;

const char[] LIBRARY = `FmodExCore.dll`;

extern (C)
{
	//void function() dupa;
	
	FMOD_RESULT function(void *poolmem, int poollen, FMOD_MEMORY_ALLOCCALLBACK useralloc,
			FMOD_MEMORY_REALLOCCALLBACK userrealloc, FMOD_MEMORY_FREECALLBACK userfree) fmodMemoryInitialize;
	FMOD_RESULT function(int *currentalloced, int *maxalloced) fmodMemoryGetStats;
	FMOD_RESULT function(FMOD_DEBUGLEVEL level) fmodDebugSetLevel;
	FMOD_RESULT function(FMOD_DEBUGLEVEL *level) fmodDebugGetLevel;
	FMOD_RESULT function(int busy) fmodFileSetDiskBusy;
	FMOD_RESULT function(int *busy) fmodFileGetDiskBusy;

	FMOD_RESULT function(FMOD_SYSTEM **system) fmodSystemCreate;
	FMOD_RESULT function(FMOD_SYSTEM *system) fmodSystemRelease;

	FMOD_RESULT function(FMOD_SYSTEM *system, FMOD_OUTPUTTYPE output) fmodSystemSetOutput;
	FMOD_RESULT function(FMOD_SYSTEM *system, FMOD_OUTPUTTYPE *output) fmodSystemGetOutput;
	FMOD_RESULT function(FMOD_SYSTEM *system, int *numdrivers) fmodSystemGetNumDrivers;
	FMOD_RESULT function(FMOD_SYSTEM *system, int id, char *name, int namelen) fmodSystemGetDriverName;
	FMOD_RESULT function(FMOD_SYSTEM *system, int id, FMOD_CAPS *caps,
		int *minfrequency, int *maxfrequency, FMOD_SPEAKERMODE *controlpanelspeakermode) fmodSystemGetDriverCaps;
	FMOD_RESULT function(FMOD_SYSTEM *system, int driver) fmodSystemSetDriver;
	FMOD_RESULT function(FMOD_SYSTEM *system, int *driver) fmodSystemGetDriver;
	FMOD_RESULT function(FMOD_SYSTEM *system, int min2d, int max2d, int min3d, int max3d) fmodSystemSetHardwareChannels;
	FMOD_RESULT function(FMOD_SYSTEM *system, int numsoftwarechannels) fmodSystemSetSoftwareChannels;
	FMOD_RESULT function(FMOD_SYSTEM *system, int *numsoftwarechannels) fmodSystemGetSoftwareChannels;
	FMOD_RESULT function(FMOD_SYSTEM *system, int samplerate, FMOD_SOUND_FORMAT format,
		int numoutputchannels, int maxinputchannels, FMOD_DSP_RESAMPLER resamplemethod) fmodSystemSetSoftwareFormat;
	FMOD_RESULT function(FMOD_SYSTEM *system, int *samplerate, FMOD_SOUND_FORMAT *format,
		int *numoutputchannels, int *maxinputchannels, FMOD_DSP_RESAMPLER *resamplemethod, int *bits) fmodSystemGetSoftwareFormat;
	FMOD_RESULT function(FMOD_SYSTEM *system, uint bufferlength, int numbuffers) fmodSystemSetDSPBufferSize;
	FMOD_RESULT function(FMOD_SYSTEM *system, uint *bufferlength, int *numbuffers) fmodSystemGetDSPBufferSize;
	FMOD_RESULT function(FMOD_SYSTEM *system, FMOD_FILE_OPENCALLBACK useropen,
		FMOD_FILE_CLOSECALLBACK userclose, FMOD_FILE_READCALLBACK userread, FMOD_FILE_SEEKCALLBACK userseek, int blocksize) fmodSystemSetFileSystem;
	FMOD_RESULT function(FMOD_SYSTEM *system, FMOD_FILE_OPENCALLBACK useropen,
		FMOD_FILE_CLOSECALLBACK userclose, FMOD_FILE_READCALLBACK userread, FMOD_FILE_SEEKCALLBACK userseek) fmodSystemAttachFileSystem;
	FMOD_RESULT function(FMOD_SYSTEM *system, FMOD_ADVANCEDSETTINGS *settings) fmodSystemSetAdvancedSettings;
	FMOD_RESULT function(FMOD_SYSTEM *system, FMOD_ADVANCEDSETTINGS *settings) fmodSystemGetAdvancedSettings;
	FMOD_RESULT function(FMOD_SYSTEM *system, FMOD_SPEAKERMODE speakermode) fmodSystemSetSpeakerMode;
	FMOD_RESULT function(FMOD_SYSTEM *system, FMOD_SPEAKERMODE *speakermode) fmodSystemGetSpeakerMode;

	/*
		 Plug-in support                       
	*/

	FMOD_RESULT function(FMOD_SYSTEM *system, char *path) fmodSystemSetPluginPath;
	FMOD_RESULT function(FMOD_SYSTEM *system, char *filename, FMOD_PLUGINTYPE *plugintype, int *index) fmodSystemLoadPlugin;
	FMOD_RESULT function(FMOD_SYSTEM *system, FMOD_PLUGINTYPE plugintype, int *numplugins) fmodSystemGetNumPlugins;
	FMOD_RESULT function(FMOD_SYSTEM *system, FMOD_PLUGINTYPE plugintype, int index, char *name,
		int namelen, uint *ver) fmodSystemGetPluginInfo;
	FMOD_RESULT function(FMOD_SYSTEM *system, FMOD_PLUGINTYPE plugintype, int index) fmodSystemUnloadPlugin;
	FMOD_RESULT function(FMOD_SYSTEM *system, int index) fmodSystemSetOutputByPlugin;
	FMOD_RESULT function(FMOD_SYSTEM *system, int *index) fmodSystemGetOutputByPlugin;
	FMOD_RESULT function(FMOD_SYSTEM *system, FMOD_CODEC_DESCRIPTION *description) fmodSystemCreateCodec;
	
	/*
		 Init/Close                            
	*/

	FMOD_RESULT function(FMOD_SYSTEM *system, int maxchannels, FMOD_INITFLAGS flags, void *extradriverdata) fmodSystemInit;
	FMOD_RESULT function(FMOD_SYSTEM *system) fmodSystemClose;

	/*
		 General post-init system functions    
	*/

	FMOD_RESULT function(FMOD_SYSTEM *system) fmodSystemUpdate;
	FMOD_RESULT function(FMOD_SYSTEM *system, float dopplerscale, float distancefactor, float rolloffscale) fmodSystemSet3DSettings;
	FMOD_RESULT function(FMOD_SYSTEM *system, float *dopplerscale, float *distancefactor, float *rolloffscale) fmodSystemGet3DSettings;
	FMOD_RESULT function(FMOD_SYSTEM *system, int numlisteners) fmodSystemSet3DNumListeners;
	FMOD_RESULT function(FMOD_SYSTEM *system, int *numlisteners) fmodSystemGet3DNumListeners;
	FMOD_RESULT function(FMOD_SYSTEM *system, int listener,  FMOD_VECTOR *pos,
		 FMOD_VECTOR *vel,  FMOD_VECTOR *forward,  FMOD_VECTOR *up) fmodSystemSet3DListenerAttributes;
	FMOD_RESULT function(FMOD_SYSTEM *system, int listener, FMOD_VECTOR *pos, FMOD_VECTOR *vel,
		FMOD_VECTOR *forward, FMOD_VECTOR *up) fmodSystemGet3DListenerAttributes;
	FMOD_RESULT function(FMOD_SYSTEM *system, FMOD_SPEAKER speaker, float x, float y) fmodSystemSetSpeakerPosition;
	FMOD_RESULT function(FMOD_SYSTEM *system, FMOD_SPEAKER speaker, float *x, float *y) fmodSystemGetSpeakerPosition;
	FMOD_RESULT function(FMOD_SYSTEM *system, uint filebuffersize, FMOD_TIMEUNIT filebuffersizetype) fmodSystemSetStreamBufferSize;
	FMOD_RESULT function(FMOD_SYSTEM *system, uint *filebuffersize, FMOD_TIMEUNIT *filebuffersizetype) fmodSystemGetStreamBufferSize;

	/*
		 System information functions.        
	*/

	FMOD_RESULT function(FMOD_SYSTEM *system, uint *ver) fmodSystemGetVersion;
	FMOD_RESULT function(FMOD_SYSTEM *system, void **handle) fmodSystemGetOutputHandle;
	FMOD_RESULT function(FMOD_SYSTEM *system, int *channels) fmodSystemGetChannelsPlaying;
	FMOD_RESULT function(FMOD_SYSTEM *system, int *num2d, int *num3d, int *total) fmodSystemGetHardwareChannels;
	FMOD_RESULT function(FMOD_SYSTEM *system, float *dsp, float *stream, float *update, float *total) fmodSystemGetCPUUsage;
	FMOD_RESULT function(FMOD_SYSTEM *system, int *currentalloced, int *maxalloced, int *total) fmodSystemGetSoundRAM;
	FMOD_RESULT function(FMOD_SYSTEM *system, int *numdrives) fmodSystemGetNumCDROMDrives;
	FMOD_RESULT function(FMOD_SYSTEM *system, int drive, char *drivename, int drivenamelen,
		char *scsiname, int scsinamelen, char *devicename, int devicenamelen) fmodSystemGetCDROMDriveName;
	FMOD_RESULT function(FMOD_SYSTEM *system, float *spectrumarray, int numvalues,
		int channeloffset, FMOD_DSP_FFT_WINDOW windowtype) fmodSystemGetSpectrum;
	FMOD_RESULT function(FMOD_SYSTEM *system, float *wavearray, int numvalues, int channeloffset) fmodSystemGetWaveData;

	/*
		 Sound/DSP/Channel/FX creation and retrieval.       
	*/

	FMOD_RESULT function(FMOD_SYSTEM *system,  char *name_or_data, FMOD_MODE mode,
		FMOD_CREATESOUNDEXINFO *exinfo, FMOD_SOUND **sound) fmodSystemCreateSound;
	FMOD_RESULT function(FMOD_SYSTEM *system,  char *name_or_data, FMOD_MODE mode,
		FMOD_CREATESOUNDEXINFO *exinfo, FMOD_SOUND **sound) fmodSystemCreateStream;
	FMOD_RESULT function(FMOD_SYSTEM *system, FMOD_DSP_DESCRIPTION *description, FMOD_DSP **dsp) fmodSystemCreateDSP;
	FMOD_RESULT function(FMOD_SYSTEM *system, FMOD_DSP_TYPE type, FMOD_DSP **dsp) fmodSystemCreateDSPByType;
	FMOD_RESULT function(FMOD_SYSTEM *system, int index, FMOD_DSP **dsp) fmodSystemCreateDSPByIndex;
	FMOD_RESULT function(FMOD_SYSTEM *system,  char *name, FMOD_CHANNELGROUP **channelgroup) fmodSystemCreateChannelGroup;
	FMOD_RESULT function(FMOD_SYSTEM *system, FMOD_CHANNELINDEX channelid, FMOD_SOUND *sound,
		FMOD_BOOL paused, FMOD_CHANNEL **channel) fmodSystemPlaySound;
	FMOD_RESULT function(FMOD_SYSTEM *system, FMOD_CHANNELINDEX channelid, FMOD_DSP *dsp,
		FMOD_BOOL paused, FMOD_CHANNEL **channel) fmodSystemPlayDSP;
	FMOD_RESULT function(FMOD_SYSTEM *system, int channelid, FMOD_CHANNEL **channel) fmodSystemGetChannel;
	FMOD_RESULT function(FMOD_SYSTEM *system, FMOD_CHANNELGROUP **channelgroup) fmodSystemGetMasterChannelGroup;

	/*
		 Reverb API                           
	*/

	FMOD_RESULT function(FMOD_SYSTEM *system,  FMOD_REVERB_PROPERTIES *prop) fmodSystemSetReverbProperties;
	FMOD_RESULT function(FMOD_SYSTEM *system, FMOD_REVERB_PROPERTIES *prop) fmodSystemGetReverbProperties;

	/*
		 System level DSP access.
	*/
 
	FMOD_RESULT function(FMOD_SYSTEM *system, FMOD_DSP **dsp) fmodSystemGetDSPHead;
	FMOD_RESULT function(FMOD_SYSTEM *system, FMOD_DSP *dsp) fmodSystemAddDSP;
	FMOD_RESULT function(FMOD_SYSTEM *system) fmodSystemLockDSP;
	FMOD_RESULT function(FMOD_SYSTEM *system) fmodSystemUnlockDSP;

	/*
		 Recording API.
	*/

	FMOD_RESULT function(FMOD_SYSTEM *system, int driver) fmodSystemSetRecordDriver;
	FMOD_RESULT function(FMOD_SYSTEM *system, int *driver) fmodSystemGetRecordDriver;
	FMOD_RESULT function(FMOD_SYSTEM *system, int *numdrivers) fmodSystemGetRecordNumDrivers;
	FMOD_RESULT function(FMOD_SYSTEM *system, int id, char *name, int namelen) fmodSystemGetRecordDriverName;
	FMOD_RESULT function(FMOD_SYSTEM *system, uint *position) fmodSystemGetRecordPosition;
	FMOD_RESULT function(FMOD_SYSTEM *system, FMOD_SOUND *sound, FMOD_BOOL loop) fmodSystemRecordStart;
	FMOD_RESULT function(FMOD_SYSTEM *system) fmodSystemRecordStop;
	FMOD_RESULT function(FMOD_SYSTEM *system, FMOD_BOOL *recording) fmodSystemIsRecording;

	/*
		 Geometry API.
	*/

	FMOD_RESULT function(FMOD_SYSTEM *system, int maxpolygons, int maxvertices, FMOD_GEOMETRY **geometry) fmodSystemCreateGeometry;
	FMOD_RESULT function(FMOD_SYSTEM *system, float maxworldsize) fmodSystemSetGeometrySettings;
	FMOD_RESULT function(FMOD_SYSTEM *system, float *maxworldsize) fmodSystemGetGeometrySettings;
	FMOD_RESULT function(FMOD_SYSTEM *system,  void *data, int datasize, FMOD_GEOMETRY **geometry) fmodSystemLoadGeometry;

	/*
		 Network functions.
	*/

	FMOD_RESULT function(FMOD_SYSTEM *system,  char *proxy) fmodSystemSetNetworkProxy;
	FMOD_RESULT function(FMOD_SYSTEM *system, char *proxy, int proxylen) fmodSystemGetNetworkProxy;
	FMOD_RESULT function(FMOD_SYSTEM *system, int timeout) fmodSystemSetNetworkTimeout;
	FMOD_RESULT function(FMOD_SYSTEM *system, int *timeout) fmodSystemGetNetworkTimeout;

	/*
		 Userdata set/get.
	*/

	FMOD_RESULT function(FMOD_SYSTEM *system, void *userdata) fmodSystemSetUserData;
	FMOD_RESULT function(FMOD_SYSTEM *system, void **userdata) fmodSystemGetUserData;
	
	/*
		'Sound' API
	*/

	FMOD_RESULT function(FMOD_SOUND *sound) fmodSoundRelease;
	FMOD_RESULT function(FMOD_SOUND *sound, FMOD_SYSTEM **system) fmodSoundGetSystemObject;

	/*
		 Standard sound manipulation functions.                                                
	*/

	FMOD_RESULT function(FMOD_SOUND *sound, uint offset, uint length, void **ptr1, void **ptr2,
		uint *len1, uint *len2) fmodSoundLock;
	FMOD_RESULT function(FMOD_SOUND *sound, void *ptr1, void *ptr2, uint len1, uint len2) fmodSoundUnlock;
	FMOD_RESULT function(FMOD_SOUND *sound, float frequency, float volume, float pan, int priority) fmodSoundSetDefaults;
	FMOD_RESULT function(FMOD_SOUND *sound, float *frequency, float *volume, float *pan, int *priority) fmodSoundGetDefaults;
	FMOD_RESULT function(FMOD_SOUND *sound, float frequencyvar, float volumevar, float panvar) fmodSoundSetVariations;
	FMOD_RESULT function(FMOD_SOUND *sound, float *frequencyvar, float *volumevar, float *panvar) fmodSoundGetVariations;
	FMOD_RESULT function(FMOD_SOUND *sound, float min, float max) fmodSoundSet3DMinMaxDistance;
	FMOD_RESULT function(FMOD_SOUND *sound, float *min, float *max) fmodSoundGet3DMinMaxDistance;
	FMOD_RESULT function(FMOD_SOUND *sound, float insideconeangle, float outsideconeangle, float outsidevolume) fmodSoundSet3DConeSettings;
	FMOD_RESULT function(FMOD_SOUND *sound, float *insideconeangle, float *outsideconeangle, float *outsidevolume) fmodSoundGet3DConeSettings;
	FMOD_RESULT function(FMOD_SOUND *sound, FMOD_VECTOR *points, int numpoints) fmodSoundSet3DCustomRolloff;
	FMOD_RESULT function(FMOD_SOUND *sound, FMOD_VECTOR **points, int *numpoints) fmodSoundGet3DCustomRolloff;
	FMOD_RESULT function(FMOD_SOUND *sound, int index, FMOD_SOUND *subsound) fmodSoundSetSubSound;
	FMOD_RESULT function(FMOD_SOUND *sound, int index, FMOD_SOUND **subsound) fmodSoundGetSubSound;
	FMOD_RESULT function(FMOD_SOUND *sound, int *subsoundlist, int numsubsounds) fmodSoundSetSubSoundSentence;
	FMOD_RESULT function(FMOD_SOUND *sound, char *name, int namelen) fmodSoundGetName;
	FMOD_RESULT function(FMOD_SOUND *sound, uint *length, FMOD_TIMEUNIT lengthtype) fmodSoundGetLength;
	FMOD_RESULT function(FMOD_SOUND *sound, FMOD_SOUND_TYPE *type,
			FMOD_SOUND_FORMAT *format, int *channels, int *bits) fmodSoundGetFormat;
	FMOD_RESULT function(FMOD_SOUND *sound, int *numsubsounds) fmodSoundGetNumSubSounds;
	FMOD_RESULT function(FMOD_SOUND *sound, int *numtags, int *numtagsupdated) fmodSoundGetNumTags;
	FMOD_RESULT function(FMOD_SOUND *sound, char *name, int index, FMOD_TAG *tag) fmodSoundGetTag;
	FMOD_RESULT function(FMOD_SOUND *sound, FMOD_OPENSTATE *openstate,
			uint *percentbuffered, FMOD_BOOL *starving) fmodSoundGetOpenState;
	FMOD_RESULT function(FMOD_SOUND *sound, void *buffer, uint lenbytes, uint *read) fmodSoundReadData;
	FMOD_RESULT function(FMOD_SOUND *sound, uint pcm) fmodSoundSeekData;

	/*
		 Synchronization point API.  These points can come from markers embedded in wav files, and can also generate channel callbacks.        
	*/

	FMOD_RESULT function(FMOD_SOUND *sound, int *numsyncpoints) fmodSoundGetNumSyncPoints;
	FMOD_RESULT function(FMOD_SOUND *sound, int index, FMOD_SYNCPOINT **point) fmodSoundGetSyncPoint;
	FMOD_RESULT function(FMOD_SOUND *sound, FMOD_SYNCPOINT *point, char *name, int namelen,
			uint *offset, FMOD_TIMEUNIT offsettype) fmodSoundGetSyncPointInfo;
	FMOD_RESULT function(FMOD_SOUND *sound, uint offset, FMOD_TIMEUNIT offsettype,
			char *name, FMOD_SYNCPOINT **point) fmodSoundAddSyncPoint;
	FMOD_RESULT function(FMOD_SOUND *sound, FMOD_SYNCPOINT *point) fmodSoundDeleteSyncPoint;
	/*
		 Functions also in Channel class but here they are the 'default' to save having to change it in Channel all the time.
	*/

	FMOD_RESULT function(FMOD_SOUND *sound, FMOD_MODE mode) fmodSoundSetMode;
	FMOD_RESULT function(FMOD_SOUND *sound, FMOD_MODE *mode) fmodSoundGetMode;
	FMOD_RESULT function(FMOD_SOUND *sound, int loopcount) fmodSoundSetLoopCount;
	FMOD_RESULT function(FMOD_SOUND *sound, int *loopcount) fmodSoundGetLoopCount;
	FMOD_RESULT function(FMOD_SOUND *sound, uint loopstart, FMOD_TIMEUNIT loopstarttype,
			uint loopend, FMOD_TIMEUNIT loopendtype) fmodSoundSetLoopPoints;
	FMOD_RESULT function(FMOD_SOUND *sound, uint *loopstart, FMOD_TIMEUNIT loopstarttype,
			uint *loopend, FMOD_TIMEUNIT loopendtype) fmodSoundGetLoopPoints;

	/*
		 Userdata set/get.
	*/

	FMOD_RESULT function(FMOD_SOUND *sound, void *userdata) fmodSoundSetUserData;
	FMOD_RESULT function(FMOD_SOUND *sound, void **userdata) fmodSoundGetUserData;
	
	/*
		'Channel' API
	*/

	FMOD_RESULT function(FMOD_CHANNEL *channel, FMOD_SYSTEM **system) fmodChannelGetSystemObject;
	FMOD_RESULT function(FMOD_CHANNEL *channel) fmodChannelStop;
	FMOD_RESULT function(FMOD_CHANNEL *channel, FMOD_BOOL paused) fmodChannelSetPaused;
	FMOD_RESULT function(FMOD_CHANNEL *channel, FMOD_BOOL *paused) fmodChannelGetPaused;
	FMOD_RESULT function(FMOD_CHANNEL *channel, float volume) fmodChannelSetVolume;
	FMOD_RESULT function(FMOD_CHANNEL *channel, float *volume) fmodChannelGetVolume;
	FMOD_RESULT function(FMOD_CHANNEL *channel, float frequency) fmodChannelSetFrequency;
	FMOD_RESULT function(FMOD_CHANNEL *channel, float *frequency) fmodChannelGetFrequency;
	FMOD_RESULT function(FMOD_CHANNEL *channel, float pan) fmodChannelSetPan;
	FMOD_RESULT function(FMOD_CHANNEL *channel, float *pan) fmodChannelGetPan;
	FMOD_RESULT function(FMOD_CHANNEL *channel, uint startdelay, uint enddelay) fmodChannelSetDelay;
	FMOD_RESULT function(FMOD_CHANNEL *channel, uint *startdelay, uint *enddelay) fmodChannelGetDelay;
	FMOD_RESULT function(FMOD_CHANNEL *channel, float frontleft, float frontright, float center, float lfe,
			float backleft, float backright, float sideleft, float sideright) fmodChannelSetSpeakerMix;
	FMOD_RESULT function(FMOD_CHANNEL *channel, float *frontleft, float *frontright, float *center, float *lfe,
			float *backleft, float *backright, float *sideleft, float *sideright) fmodChannelGetSpeakerMix;
	FMOD_RESULT function(FMOD_CHANNEL *channel, FMOD_SPEAKER speaker, float *levels, int numlevels) fmodChannelSetSpeakerLevels;
	FMOD_RESULT function(FMOD_CHANNEL *channel, FMOD_SPEAKER speaker, float *levels, int numlevels) fmodChannelGetSpeakerLevels;
	FMOD_RESULT function(FMOD_CHANNEL *channel, FMOD_BOOL mute) fmodChannelSetMute;
	FMOD_RESULT function(FMOD_CHANNEL *channel, FMOD_BOOL *mute) fmodChannelGetMute;
	FMOD_RESULT function(FMOD_CHANNEL *channel, int priority) fmodChannelSetPriority;
	FMOD_RESULT function(FMOD_CHANNEL *channel, int *priority) fmodChannelGetPriority;
	FMOD_RESULT function(FMOD_CHANNEL *channel, uint position, FMOD_TIMEUNIT postype) fmodChannelSetPosition;
	FMOD_RESULT function(FMOD_CHANNEL *channel, uint *position, FMOD_TIMEUNIT postype) fmodChannelGetPosition;
	FMOD_RESULT function(FMOD_CHANNEL *channel, FMOD_REVERB_CHANNELPROPERTIES *prop) fmodChannelSetReverbProperties;
	FMOD_RESULT function(FMOD_CHANNEL *channel, FMOD_REVERB_CHANNELPROPERTIES *prop) fmodChannelGetReverbProperties;
	FMOD_RESULT function(FMOD_CHANNEL *channel, FMOD_CHANNELGROUP *channelgroup) fmodChannelSetChannelGroup;
	FMOD_RESULT function(FMOD_CHANNEL *channel, FMOD_CHANNELGROUP **channelgroup) fmodChannelGetChannelGroup;
	FMOD_RESULT function(FMOD_CHANNEL *channel, FMOD_CHANNEL_CALLBACKTYPE type,
			FMOD_CHANNEL_CALLBACK callback, int command) fmodChannelSetCallback;

	/*
		 3D functionality.
	*/

	FMOD_RESULT function(FMOD_CHANNEL *channel, FMOD_VECTOR *pos, FMOD_VECTOR *vel) fmodChannelSet3DAttributes;
	FMOD_RESULT function(FMOD_CHANNEL *channel, FMOD_VECTOR *pos, FMOD_VECTOR *vel) fmodChannelGet3DAttributes;
	FMOD_RESULT function(FMOD_CHANNEL *channel, float mindistance, float maxdistance) fmodChannelSet3DMinMaxDistance;
	FMOD_RESULT function(FMOD_CHANNEL *channel, float *mindistance, float *maxdistance) fmodChannelGet3DMinMaxDistance;
	FMOD_RESULT function(FMOD_CHANNEL *channel, float insideconeangle, float outsideconeangle, float outsidevolume) fmodChannelSet3DConeSettings;
	FMOD_RESULT function(FMOD_CHANNEL *channel, float *insideconeangle, float *outsideconeangle, float *outsidevolume) fmodChannelGet3DConeSettings;
	FMOD_RESULT function(FMOD_CHANNEL *channel, FMOD_VECTOR *orientation) fmodChannelSet3DConeOrientation;
	FMOD_RESULT function(FMOD_CHANNEL *channel, FMOD_VECTOR *orientation) fmodChannelGet3DConeOrientation;
	FMOD_RESULT function(FMOD_CHANNEL *channel, FMOD_VECTOR *points, int numpoints) fmodChannelSet3DCustomRolloff;
	FMOD_RESULT function(FMOD_CHANNEL *channel, FMOD_VECTOR **points, int *numpoints) fmodChannelGet3DCustomRolloff;
	FMOD_RESULT function(FMOD_CHANNEL *channel, float directocclusion, float reverbocclusion) fmodChannelSet3DOcclusion;
	FMOD_RESULT function(FMOD_CHANNEL *channel, float *directocclusion, float *reverbocclusion) fmodChannelGet3DOcclusion;
	FMOD_RESULT function(FMOD_CHANNEL *channel, float angle) fmodChannelSet3DSpread;
	FMOD_RESULT function(FMOD_CHANNEL *channel, float *angle) fmodChannelGet3DSpread;
	FMOD_RESULT function(FMOD_CHANNEL *channel, float level) fmodChannelSet3DPanLevel;
	FMOD_RESULT function(FMOD_CHANNEL *channel, float *level) fmodChannelGet3DPanLevel;
	FMOD_RESULT function(FMOD_CHANNEL *channel, float level) fmodChannelSet3DDopplerLevel;
	FMOD_RESULT function(FMOD_CHANNEL *channel, float *level) fmodChannelGet3DDopplerLevel;

	/*
		 DSP functionality only for channels playing sounds created with FMOD_SOFTWARE.
	*/

	FMOD_RESULT function(FMOD_CHANNEL *channel, FMOD_DSP **dsp) fmodChannelGetDSPHead;
	FMOD_RESULT function(FMOD_CHANNEL *channel, FMOD_DSP *dsp) fmodChannelAddDSP;

	/*
		 Information only functions.
	*/

	FMOD_RESULT function(FMOD_CHANNEL *channel, FMOD_BOOL *isplaying) fmodChannelIsPlaying;
	FMOD_RESULT function(FMOD_CHANNEL *channel, FMOD_BOOL *isvirtual) fmodChannelIsVirtual;
	FMOD_RESULT function(FMOD_CHANNEL *channel, float *audibility) fmodChannelGetAudibility;
	FMOD_RESULT function(FMOD_CHANNEL *channel, FMOD_SOUND **sound) fmodChannelGetCurrentSound;
	FMOD_RESULT function(FMOD_CHANNEL *channel, float *spectrumarray, int numvalues, int channeloffset,
			FMOD_DSP_FFT_WINDOW windowtype) fmodChannelGetSpectrum;
	FMOD_RESULT function(FMOD_CHANNEL *channel, float *wavearray, int numvalues, int channeloffset) fmodChannelGetWaveData;
	FMOD_RESULT function(FMOD_CHANNEL *channel, int *index) fmodChannelGetIndex;

	/*
		 Functions also found in Sound class but here they can be set per channel.
	*/

	FMOD_RESULT function(FMOD_CHANNEL *channel, FMOD_MODE mode) fmodChannelSetMode;
	FMOD_RESULT function(FMOD_CHANNEL *channel, FMOD_MODE *mode) fmodChannelGetMode;
	FMOD_RESULT function(FMOD_CHANNEL *channel, int loopcount) fmodChannelSetLoopCount;
	FMOD_RESULT function(FMOD_CHANNEL *channel, int *loopcount) fmodChannelGetLoopCount;
	FMOD_RESULT function(FMOD_CHANNEL *channel, uint loopstart, FMOD_TIMEUNIT loopstarttype,
			uint loopend, FMOD_TIMEUNIT loopendtype) fmodChannelSetLoopPoints;
	FMOD_RESULT function(FMOD_CHANNEL *channel, uint *loopstart, FMOD_TIMEUNIT loopstarttype,
			uint *loopend, FMOD_TIMEUNIT loopendtype) fmodChannelGetLoopPoints;

	/*
		 Userdata set/get.                                                
	*/

	FMOD_RESULT function(FMOD_CHANNEL *channel, void *userdata) fmodChannelSetUserData;
	FMOD_RESULT function(FMOD_CHANNEL *channel, void **userdata) fmodChannelGetUserData;
	

	/*
		'ChannelGroup' API
	*/

	FMOD_RESULT function(FMOD_CHANNELGROUP *channelgroup) fmodChannelGroupRelease;
	FMOD_RESULT function(FMOD_CHANNELGROUP *channelgroup, FMOD_SYSTEM **system) fmodChannelGroupGetSystemObject;

	/*
		 Channelgroup scale values.  (changes attributes relative to the channels, doesn't overwrite them)
	*/

	FMOD_RESULT function(FMOD_CHANNELGROUP *channelgroup, float volume) fmodChannelGroupSetVolume;
	FMOD_RESULT function(FMOD_CHANNELGROUP *channelgroup, float *volume) fmodChannelGroupGetVolume;
	FMOD_RESULT function(FMOD_CHANNELGROUP *channelgroup, float pitch) fmodChannelGroupSetPitch;
	FMOD_RESULT function(FMOD_CHANNELGROUP *channelgroup, float *pitch) fmodChannelGroupGetPitch;

	/*
		 Channelgroup override values.  (recursively overwrites whatever settings the channels had)
	*/

	FMOD_RESULT function(FMOD_CHANNELGROUP *channelgroup) fmodChannelGroupStop;
	FMOD_RESULT function(FMOD_CHANNELGROUP *channelgroup, FMOD_BOOL paused) fmodChannelGroupOverridePaused;
	FMOD_RESULT function(FMOD_CHANNELGROUP *channelgroup, float volume) fmodChannelGroupOverrideVolume;
	FMOD_RESULT function(FMOD_CHANNELGROUP *channelgroup, float frequency) fmodChannelGroupOverrideFrequency;
	FMOD_RESULT function(FMOD_CHANNELGROUP *channelgroup, float pan) fmodChannelGroupOverridePan;
	FMOD_RESULT function(FMOD_CHANNELGROUP *channelgroup, FMOD_BOOL mute) fmodChannelGroupOverrideMute;
	FMOD_RESULT function(FMOD_CHANNELGROUP *channelgroup, FMOD_REVERB_CHANNELPROPERTIES *prop) fmodChannelGroupOverrideReverbProperties;
	FMOD_RESULT function(FMOD_CHANNELGROUP *channelgroup, FMOD_VECTOR *pos, FMOD_VECTOR *vel) fmodChannelGroupOverride3DAttributes;
	FMOD_RESULT function(FMOD_CHANNELGROUP *channelgroup, float frontleft, float frontright, float center,
			float lfe, float backleft, float backright, float sideleft, float sideright) fmodChannelGroupOverrideSpeakerMix;

	/*
		 Nested channel groups.
	*/

	FMOD_RESULT function(FMOD_CHANNELGROUP *channelgroup, FMOD_CHANNELGROUP *group) fmodChannelGroupAddGroup;
	FMOD_RESULT function(FMOD_CHANNELGROUP *channelgroup, int *numgroups) fmodChannelGroupGetNumGroups;
	FMOD_RESULT function(FMOD_CHANNELGROUP *channelgroup, int index, FMOD_CHANNELGROUP **group) fmodChannelGroupGetGroup;


	/*
		 DSP functionality only for channel groups playing sounds created with FMOD_SOFTWARE.
	*/

	FMOD_RESULT function(FMOD_CHANNELGROUP *channelgroup, FMOD_DSP **dsp) fmodChannelGroupGetDSPHead;
	FMOD_RESULT function(FMOD_CHANNELGROUP *channelgroup, FMOD_DSP *dsp) fmodChannelGroupAddDSP;

	/*
		 Information only functions.
	*/

	FMOD_RESULT function(FMOD_CHANNELGROUP *channelgroup, char *name, int namelen) fmodChannelGroupGetName;
	FMOD_RESULT function(FMOD_CHANNELGROUP *channelgroup, int *numchannels) fmodChannelGroupGetNumChannels;
	FMOD_RESULT function(FMOD_CHANNELGROUP *channelgroup, int index, FMOD_CHANNEL **channel) fmodChannelGroupGetChannels;
	FMOD_RESULT function(FMOD_CHANNELGROUP *channelgroup, float *spectrumarray, int numvalues,
			int channeloffset, FMOD_DSP_FFT_WINDOW windowtype) fmodChannelGroupGetSpectrum;
	FMOD_RESULT function(FMOD_CHANNELGROUP *channelgroup, float *wavearray, int numvalues, int channeloffset) fmodChannelGroupGetWaveData;


	/*
		 Userdata set/get.
	*/

	FMOD_RESULT function(FMOD_CHANNELGROUP *channelgroup, void *userdata) fmodChannelGroupSetUserData;
	FMOD_RESULT function(FMOD_CHANNELGROUP *channelgroup, void **userdata) fmodChannelGroupGetUserData;

	/*
		'DSP' API
	*/

	FMOD_RESULT function(FMOD_DSP *dsp) fmodDSPRelease;
	FMOD_RESULT function(FMOD_DSP *dsp, FMOD_SYSTEM **system) fmodDSPGetSystemObject;


	/*
		 Connection / disconnection / input and output enumeration.
	*/

	FMOD_RESULT function(FMOD_DSP *dsp, FMOD_DSP *target) fmodDSPAddInput;
	FMOD_RESULT function(FMOD_DSP *dsp, FMOD_DSP *target) fmodDSPDisconnectFrom;
	FMOD_RESULT function(FMOD_DSP *dsp, FMOD_BOOL inputs, FMOD_BOOL outputs) fmodDSPDisconnectAll;
	FMOD_RESULT function(FMOD_DSP *dsp) fmodDSPRemove;
	FMOD_RESULT function(FMOD_DSP *dsp, int *numinputs) fmodDSPGetNumInputs;
	FMOD_RESULT function(FMOD_DSP *dsp, int *numoutputs) fmodDSPGetNumOutputs;
	FMOD_RESULT function(FMOD_DSP *dsp, int index, FMOD_DSP **input) fmodDSPGetInput;
	FMOD_RESULT function(FMOD_DSP *dsp, int index, FMOD_DSP **output) fmodDSPGetOutput;
	FMOD_RESULT function(FMOD_DSP *dsp, int index, float volume) fmodDSPSetInputMix;
	FMOD_RESULT function(FMOD_DSP *dsp, int index, float *volume) fmodDSPGetInputMix;
	FMOD_RESULT function(FMOD_DSP *dsp, int index, FMOD_SPEAKER speaker, float *levels, int numlevels) fmodDSPSetInputLevels;
	FMOD_RESULT function(FMOD_DSP *dsp, int index, FMOD_SPEAKER speaker, float *levels, int numlevels) fmodDSPGetInputLevels;
	FMOD_RESULT function(FMOD_DSP *dsp, int index, float volume) fmodDSPSetOutputMix;
	FMOD_RESULT function(FMOD_DSP *dsp, int index, float *volume) fmodDSPGetOutputMix;
	FMOD_RESULT function(FMOD_DSP *dsp, int index, FMOD_SPEAKER speaker, float *levels, int numlevels) fmodDSPSetOutputLevels;
	FMOD_RESULT function(FMOD_DSP *dsp, int index, FMOD_SPEAKER speaker, float *levels, int numlevels) fmodDSPGetOutputLevels;

	/*
		 DSP unit control.
	*/

	FMOD_RESULT function(FMOD_DSP *dsp, FMOD_BOOL active) fmodDSPSetActive;
	FMOD_RESULT function(FMOD_DSP *dsp, FMOD_BOOL *active) fmodDSPGetActive;
	FMOD_RESULT function(FMOD_DSP *dsp, FMOD_BOOL bypass) fmodDSPSetBypass;
	FMOD_RESULT function(FMOD_DSP *dsp, FMOD_BOOL *bypass) fmodDSPGetBypass;
	FMOD_RESULT function(FMOD_DSP *dsp) fmodDSPReset;

	/*
		 DSP parameter control.
	*/

	FMOD_RESULT function(FMOD_DSP *dsp, int index, float value) fmodDSPSetParameter;
	FMOD_RESULT function(FMOD_DSP *dsp, int index, float *value, char *valuestr, int valuestrlen) fmodDSPGetParameter;
	FMOD_RESULT function(FMOD_DSP *dsp, int *numparams) fmodDSPGetNumParameters;
	FMOD_RESULT function(FMOD_DSP *dsp, int index, char *name, char *label, char *description,
			int descriptionlen, float *min, float *max) fmodDSPGetParameterInfo;
	FMOD_RESULT function(FMOD_DSP *dsp, void *hwnd, FMOD_BOOL show) fmodDSPShowConfigDialog;

	/*
		 DSP attributes.        
	*/

	FMOD_RESULT function(FMOD_DSP *dsp, char *name, uint *ver, int *channels, int *configwidth,
			int *configheight) fmodDSPGetInfo;
	FMOD_RESULT function(FMOD_DSP *dsp, FMOD_DSP_TYPE *type) fmodDSPGetType;
	FMOD_RESULT function(FMOD_DSP *dsp, float frequency, float volume, float pan, int priority) fmodDSPSetDefaults;
	FMOD_RESULT function(FMOD_DSP *dsp, float *frequency, float *volume, float *pan, int *priority) fmodDSPGetDefaults;

	/*
		 Userdata set/get.
	*/

	FMOD_RESULT function(FMOD_DSP *dsp, void *userdata) fmodDSPSetUserData;
	FMOD_RESULT function(FMOD_DSP *dsp, void **userdata) fmodDSPGetUserData;

	/*
		'Geometry' API
	*/

	FMOD_RESULT function(FMOD_GEOMETRY *geometry) fmodGeometryRelease;
	FMOD_RESULT function(FMOD_GEOMETRY *geometry, float directocclusion, float reverbocclusion,
			FMOD_BOOL doublesided, int numvertices, FMOD_VECTOR *vertices, int *polygonindex) fmodGeometryAddPolygon;
	FMOD_RESULT function(FMOD_GEOMETRY *geometry, int *numpolygons) fmodGeometryGetNumPolygons;
	FMOD_RESULT function(FMOD_GEOMETRY *geometry, int *maxpolygons, int *maxvertices) fmodGeometryGetMaxPolygons;
	FMOD_RESULT function(FMOD_GEOMETRY *geometry, int index, int *numvertices) fmodGeometryGetPolygonNumVertices;
	FMOD_RESULT function(FMOD_GEOMETRY *geometry, int index, int vertexindex, FMOD_VECTOR *vertex) fmodGeometrySetPolygonVertex;
	FMOD_RESULT function(FMOD_GEOMETRY *geometry, int index, int vertexindex, FMOD_VECTOR *vertex) fmodGeometryGetPolygonVertex;
	FMOD_RESULT function(FMOD_GEOMETRY *geometry, int index, float directocclusion, float reverbocclusion,
			FMOD_BOOL doublesided) fmodGeometrySetPolygonAttributes;
	FMOD_RESULT function(FMOD_GEOMETRY *geometry, int index, float *directocclusion, float *reverbocclusion,
			FMOD_BOOL *doublesided) fmodGeometryGetPolygonAttributes;
	FMOD_RESULT function(FMOD_GEOMETRY *geometry, FMOD_BOOL active) fmodGeometrySetActive;
	FMOD_RESULT function(FMOD_GEOMETRY *geometry, FMOD_BOOL *active) fmodGeometryGetActive;
	FMOD_RESULT function(FMOD_GEOMETRY *geometry, FMOD_VECTOR *forward, FMOD_VECTOR *up) fmodGeometrySetRotation;
	FMOD_RESULT function(FMOD_GEOMETRY *geometry, FMOD_VECTOR *forward, FMOD_VECTOR *up) fmodGeometryGetRotation;
	FMOD_RESULT function(FMOD_GEOMETRY *geometry, FMOD_VECTOR *position) fmodGeometrySetPosition;
	FMOD_RESULT function(FMOD_GEOMETRY *geometry, FMOD_VECTOR *position) fmodGeometryGetPosition;
	FMOD_RESULT function(FMOD_GEOMETRY *geometry, FMOD_VECTOR *scale) fmodGeometrySetScale;
	FMOD_RESULT function(FMOD_GEOMETRY *geometry, FMOD_VECTOR *scale) fmodGeometryGetScale;
	FMOD_RESULT function(FMOD_GEOMETRY *geometry, void *data, int *datasize) fmodGeometrySave;

	/*
		 Userdata set/get.
	*/

	FMOD_RESULT function(FMOD_GEOMETRY *geometry, void *userdata) fmodGeometrySetUserData;
	FMOD_RESULT function(FMOD_GEOMETRY *geometry, void **userdata) fmodGeometryGetUserData;
}


void loadSym(T)(inout T t, SharedLib  lib, char[] name)
{
	t = cast(T) lib.getSymbol( toStringz(name) );
	if (t is null) Stdout("could not load {}", name).newline;
}


void loadStuffFmodEx()
{
	//auto dll = ExeModule_Load(LIBRARY);
	
	auto dll = SharedLib.load(LIBRARY);
	
	loadSym(fmodMemoryInitialize, dll, `fmodMemoryInitialize`);
	loadSym(fmodMemoryGetStats, dll, `fmodMemoryGetStats`);
	loadSym(fmodDebugSetLevel, dll, `fmodDebugSetLevel`);
	loadSym(fmodDebugGetLevel, dll, `fmodDebugGetLevel`);
	loadSym(fmodFileSetDiskBusy, dll, `fmodFileSetDiskBusy`);
	loadSym(fmodFileGetDiskBusy, dll, `fmodFileGetDiskBusy`);
	
	loadSym(fmodSystemCreate, dll, `fmodSystemCreate`);
	loadSym(fmodSystemRelease, dll, `fmodSystemRelease`);
	
	loadSym(fmodSystemSetOutput, dll, `fmodSystemSetOutput`);
	loadSym(fmodSystemGetOutput, dll, `fmodSystemGetOutput`);
	loadSym(fmodSystemGetNumDrivers, dll, `fmodSystemGetNumDrivers`);
	loadSym(fmodSystemGetDriverName, dll, `fmodSystemGetDriverName`);
	loadSym(fmodSystemGetDriverCaps, dll, `fmodSystemGetDriverCaps`);
	loadSym(fmodSystemSetDriver, dll, `fmodSystemSetDriver`);
	loadSym(fmodSystemGetDriver, dll, `fmodSystemGetDriver`);	
	loadSym(fmodSystemSetHardwareChannels, dll, `fmodSystemSetHardwareChannels`);
	loadSym(fmodSystemSetSoftwareChannels, dll, `fmodSystemSetSoftwareChannels`);
	loadSym(fmodSystemGetSoftwareChannels, dll, `fmodSystemGetSoftwareChannels`);
	loadSym(fmodSystemSetSoftwareFormat, dll, `fmodSystemSetSoftwareFormat`);
	loadSym(fmodSystemGetSoftwareFormat, dll, `fmodSystemGetSoftwareFormat`);
	loadSym(fmodSystemSetDSPBufferSize, dll, `fmodSystemSetDSPBufferSize`);
	loadSym(fmodSystemGetDSPBufferSize, dll, `fmodSystemGetDSPBufferSize`);
	loadSym(fmodSystemSetFileSystem, dll, `fmodSystemSetFileSystem`);
	loadSym(fmodSystemAttachFileSystem, dll, `fmodSystemAttachFileSystem`);
	loadSym(fmodSystemSetAdvancedSettings, dll, `fmodSystemSetAdvancedSettings`);
	loadSym(fmodSystemGetAdvancedSettings, dll, `fmodSystemGetAdvancedSettings`);
	loadSym(fmodSystemSetSpeakerMode, dll, `fmodSystemSetSpeakerMode`);
	loadSym(fmodSystemGetSpeakerMode, dll, `fmodSystemGetSpeakerMode`);
	
	loadSym(fmodSystemSetPluginPath, dll, `fmodSystemSetPluginPath`);
	loadSym(fmodSystemLoadPlugin, dll, `fmodSystemLoadPlugin`);
	loadSym(fmodSystemGetNumPlugins, dll, `fmodSystemGetNumPlugins`);
	loadSym(fmodSystemGetPluginInfo, dll, `fmodSystemGetPluginInfo`);
	loadSym(fmodSystemUnloadPlugin, dll, `fmodSystemUnloadPlugin`);
	loadSym(fmodSystemSetOutputByPlugin, dll, `fmodSystemSetOutputByPlugin`);
	loadSym(fmodSystemGetOutputByPlugin, dll, `fmodSystemGetOutputByPlugin`);
	loadSym(fmodSystemCreateCodec, dll, `fmodSystemCreateCodec`);
	
	loadSym(fmodSystemInit, dll, `fmodSystemInit`);
	loadSym(fmodSystemClose, dll, `fmodSystemClose`);

	loadSym(fmodSystemUpdate, dll, `fmodSystemUpdate`);
	loadSym(fmodSystemSet3DSettings, dll, `fmodSystemSet3DSettings`);
	loadSym(fmodSystemGet3DSettings, dll, `fmodSystemGet3DSettings`);
	loadSym(fmodSystemSet3DNumListeners, dll, `fmodSystemSet3DNumListeners`);
	loadSym(fmodSystemGet3DNumListeners, dll, `fmodSystemGet3DNumListeners`);
	loadSym(fmodSystemSet3DListenerAttributes, dll, `fmodSystemSet3DListenerAttributes`);
	loadSym(fmodSystemGet3DListenerAttributes, dll, `fmodSystemGet3DListenerAttributes`);
	loadSym(fmodSystemSetSpeakerPosition, dll, `fmodSystemSetSpeakerPosition`);
	loadSym(fmodSystemGetSpeakerPosition, dll, `fmodSystemGetSpeakerPosition`);
	loadSym(fmodSystemSetStreamBufferSize, dll, `fmodSystemSetStreamBufferSize`);
	loadSym(fmodSystemGetStreamBufferSize, dll, `fmodSystemGetStreamBufferSize`);

	loadSym(fmodSystemGetVersion, dll, `fmodSystemGetVersion`);
	loadSym(fmodSystemGetOutputHandle, dll, `fmodSystemGetOutputHandle`);
	loadSym(fmodSystemGetChannelsPlaying, dll, `fmodSystemGetChannelsPlaying`);
	loadSym(fmodSystemGetHardwareChannels, dll, `fmodSystemGetHardwareChannels`);
	loadSym(fmodSystemGetCPUUsage, dll, `fmodSystemGetCPUUsage`);
	loadSym(fmodSystemGetSoundRAM, dll, `fmodSystemGetSoundRAM`);
	loadSym(fmodSystemGetNumCDROMDrives, dll, `fmodSystemGetNumCDROMDrives`);
	loadSym(fmodSystemGetCDROMDriveName, dll, `fmodSystemGetCDROMDriveName`);
	loadSym(fmodSystemGetSpectrum, dll, `fmodSystemGetSpectrum`);
	loadSym(fmodSystemGetWaveData, dll, `fmodSystemGetWaveData`);

	loadSym(fmodSystemCreateSound, dll, `fmodSystemCreateSound`);
	loadSym(fmodSystemCreateStream, dll, `fmodSystemCreateStream`);
	loadSym(fmodSystemCreateDSP, dll, `fmodSystemCreateDSP`);
	loadSym(fmodSystemCreateDSPByType, dll, `fmodSystemCreateDSPByType`);
	loadSym(fmodSystemCreateDSPByIndex, dll, `fmodSystemCreateDSPByIndex`);
	loadSym(fmodSystemCreateChannelGroup, dll, `fmodSystemCreateChannelGroup`);
	loadSym(fmodSystemPlaySound, dll, `fmodSystemPlaySound`);
	loadSym(fmodSystemPlayDSP, dll, `fmodSystemPlayDSP`);
	loadSym(fmodSystemGetChannel, dll, `fmodSystemGetChannel`);
	loadSym(fmodSystemGetMasterChannelGroup, dll, `fmodSystemGetMasterChannelGroup`);

	loadSym(fmodSystemSetReverbProperties, dll, `fmodSystemSetReverbProperties`);
	loadSym(fmodSystemGetReverbProperties, dll, `fmodSystemGetReverbProperties`);

	loadSym(fmodSystemGetDSPHead, dll, `fmodSystemGetDSPHead`);
	loadSym(fmodSystemAddDSP, dll, `fmodSystemAddDSP`);
	loadSym(fmodSystemLockDSP, dll, `fmodSystemLockDSP`);
	loadSym(fmodSystemUnlockDSP, dll, `fmodSystemUnlockDSP`);

	loadSym(fmodSystemSetRecordDriver, dll, `fmodSystemSetRecordDriver`);
	loadSym(fmodSystemGetRecordDriver, dll, `fmodSystemGetRecordDriver`);
	loadSym(fmodSystemGetRecordNumDrivers, dll, `fmodSystemGetRecordNumDrivers`);
	loadSym(fmodSystemGetRecordDriverName, dll, `fmodSystemGetRecordDriverName`);
	loadSym(fmodSystemGetRecordPosition, dll, `fmodSystemGetRecordPosition`);
	loadSym(fmodSystemRecordStart, dll, `fmodSystemRecordStart`);
	loadSym(fmodSystemRecordStop, dll, `fmodSystemRecordStop`);
	loadSym(fmodSystemIsRecording, dll, `fmodSystemIsRecording`);

	loadSym(fmodSystemCreateGeometry, dll, `fmodSystemCreateGeometry`);
	loadSym(fmodSystemSetGeometrySettings, dll, `fmodSystemSetGeometrySettings`);
	loadSym(fmodSystemGetGeometrySettings, dll, `fmodSystemGetGeometrySettings`);
	loadSym(fmodSystemLoadGeometry, dll, `fmodSystemLoadGeometry`);

	loadSym(fmodSystemSetNetworkProxy, dll, `fmodSystemSetNetworkProxy`);
	loadSym(fmodSystemGetNetworkProxy, dll, `fmodSystemGetNetworkProxy`);
	loadSym(fmodSystemSetNetworkTimeout, dll, `fmodSystemSetNetworkTimeout`);
	loadSym(fmodSystemGetNetworkTimeout, dll, `fmodSystemGetNetworkTimeout`);

	loadSym(fmodSystemSetUserData, dll, `fmodSystemSetUserData`);
	loadSym(fmodSystemGetUserData, dll, `fmodSystemGetUserData`);
	
	loadSym(fmodSoundRelease, dll, `fmodSoundRelease`);
	loadSym(fmodSoundGetSystemObject, dll, `fmodSoundGetSystemObject`);

	loadSym(fmodSoundLock, dll, `fmodSoundLock`);
	loadSym(fmodSoundUnlock, dll, `fmodSoundUnlock`);
	loadSym(fmodSoundSetDefaults, dll, `fmodSoundSetDefaults`);
	loadSym(fmodSoundGetDefaults, dll, `fmodSoundGetDefaults`);
	loadSym(fmodSoundSetVariations, dll, `fmodSoundSetVariations`);
	loadSym(fmodSoundGetVariations, dll, `fmodSoundGetVariations`);
	loadSym(fmodSoundSet3DMinMaxDistance, dll, `fmodSoundSet3DMinMaxDistance`);
	loadSym(fmodSoundGet3DMinMaxDistance, dll, `fmodSoundGet3DMinMaxDistance`);
	loadSym(fmodSoundSet3DConeSettings, dll, `fmodSoundSet3DConeSettings`);
	loadSym(fmodSoundGet3DConeSettings, dll, `fmodSoundGet3DConeSettings`);
	loadSym(fmodSoundSet3DCustomRolloff, dll, `fmodSoundSet3DCustomRolloff`);
	loadSym(fmodSoundGet3DCustomRolloff, dll, `fmodSoundGet3DCustomRolloff`);
	loadSym(fmodSoundSetSubSound, dll, `fmodSoundSetSubSound`);
	loadSym(fmodSoundGetSubSound, dll, `fmodSoundGetSubSound`);
	loadSym(fmodSoundSetSubSoundSentence, dll, `fmodSoundSetSubSoundSentence`);
	loadSym(fmodSoundGetName, dll, `fmodSoundGetName`);
	loadSym(fmodSoundGetLength, dll, `fmodSoundGetLength`);
	loadSym(fmodSoundGetFormat, dll, `fmodSoundGetFormat`);
	loadSym(fmodSoundGetNumSubSounds, dll, `fmodSoundGetNumSubSounds`);
	loadSym(fmodSoundGetNumTags, dll, `fmodSoundGetNumTags`);
	loadSym(fmodSoundGetTag, dll, `fmodSoundGetTag`);
	loadSym(fmodSoundReadData, dll, `fmodSoundReadData`);
	loadSym(fmodSoundGetOpenState, dll, `fmodSoundGetOpenState`);
	loadSym(fmodSoundSeekData, dll, `fmodSoundSeekData`);

	loadSym(fmodSoundGetNumSyncPoints, dll, `fmodSoundGetNumSyncPoints`);
	loadSym(fmodSoundGetSyncPoint, dll, `fmodSoundGetSyncPoint`);
	loadSym(fmodSoundGetSyncPointInfo, dll, `fmodSoundGetSyncPointInfo`);
	loadSym(fmodSoundAddSyncPoint, dll, `fmodSoundAddSyncPoint`);
	loadSym(fmodSoundDeleteSyncPoint, dll, `fmodSoundDeleteSyncPoint`);

	loadSym(fmodSoundSetMode, dll, `fmodSoundSetMode`);
	loadSym(fmodSoundGetMode, dll, `fmodSoundGetMode`);
	loadSym(fmodSoundSetLoopCount, dll, `fmodSoundSetLoopCount`);
	loadSym(fmodSoundGetLoopCount, dll, `fmodSoundGetLoopCount`);
	loadSym(fmodSoundSetLoopPoints, dll, `fmodSoundSetLoopPoints`);
	loadSym(fmodSoundGetLoopPoints, dll, `fmodSoundGetLoopPoints`);

	loadSym(fmodSoundSetUserData, dll, `fmodSoundSetUserData`);
	loadSym(fmodSoundGetUserData, dll, `fmodSoundGetUserData`);
	
	loadSym(fmodChannelGetSystemObject, dll, `fmodChannelGetSystemObject`);
	loadSym(fmodChannelStop, dll, `fmodChannelStop`);
	loadSym(fmodChannelSetPaused, dll, `fmodChannelSetPaused`);
	loadSym(fmodChannelGetPaused, dll, `fmodChannelGetPaused`);
	loadSym(fmodChannelSetVolume, dll, `fmodChannelSetVolume`);
	loadSym(fmodChannelGetVolume, dll, `fmodChannelGetVolume`);
	loadSym(fmodChannelSetFrequency, dll, `fmodChannelSetFrequency`);
	loadSym(fmodChannelGetFrequency, dll, `fmodChannelGetFrequency`);
	loadSym(fmodChannelSetPan, dll, `fmodChannelSetPan`);
	loadSym(fmodChannelGetPan, dll, `fmodChannelGetPan`);
	loadSym(fmodChannelSetDelay, dll, `fmodChannelSetDelay`);
	loadSym(fmodChannelGetDelay, dll, `fmodChannelGetDelay`);
	loadSym(fmodChannelSetSpeakerMix, dll, `fmodChannelSetSpeakerMix`);
	loadSym(fmodChannelGetSpeakerMix, dll, `fmodChannelGetSpeakerMix`);
	loadSym(fmodChannelSetSpeakerLevels, dll, `fmodChannelSetSpeakerLevels`);
	loadSym(fmodChannelGetSpeakerLevels, dll, `fmodChannelGetSpeakerLevels`);
	loadSym(fmodChannelSetMute, dll, `fmodChannelSetMute`);
	loadSym(fmodChannelGetMute, dll, `fmodChannelGetMute`);
	loadSym(fmodChannelSetPriority, dll, `fmodChannelSetPriority`);
	loadSym(fmodChannelGetPriority, dll, `fmodChannelGetPriority`);
	loadSym(fmodChannelSetPosition, dll, `fmodChannelSetPosition`);
	loadSym(fmodChannelGetPosition, dll, `fmodChannelGetPosition`);
	loadSym(fmodChannelSetReverbProperties, dll, `fmodChannelSetReverbProperties`);
	loadSym(fmodChannelGetReverbProperties, dll, `fmodChannelGetReverbProperties`);
	loadSym(fmodChannelSetChannelGroup, dll, `fmodChannelSetChannelGroup`);
	loadSym(fmodChannelGetChannelGroup, dll, `fmodChannelGetChannelGroup`);
	loadSym(fmodChannelSetCallback, dll, `fmodChannelSetCallback`);

	loadSym(fmodChannelSet3DAttributes, dll, `fmodChannelSet3DAttributes`);
	loadSym(fmodChannelGet3DAttributes, dll, `fmodChannelGet3DAttributes`);
	loadSym(fmodChannelSet3DMinMaxDistance, dll, `fmodChannelSet3DMinMaxDistance`);
	loadSym(fmodChannelGet3DMinMaxDistance, dll, `fmodChannelGet3DMinMaxDistance`);
	loadSym(fmodChannelSet3DConeSettings, dll, `fmodChannelSet3DConeSettings`);
	loadSym(fmodChannelGet3DConeSettings, dll, `fmodChannelGet3DConeSettings`);
	loadSym(fmodChannelSet3DConeOrientation, dll, `fmodChannelSet3DConeOrientation`);
	loadSym(fmodChannelGet3DConeOrientation, dll, `fmodChannelGet3DConeOrientation`);
	loadSym(fmodChannelSet3DCustomRolloff, dll, `fmodChannelSet3DCustomRolloff`);
	loadSym(fmodChannelGet3DCustomRolloff, dll, `fmodChannelGet3DCustomRolloff`);
	loadSym(fmodChannelSet3DOcclusion, dll, `fmodChannelSet3DOcclusion`);
	loadSym(fmodChannelGet3DOcclusion, dll, `fmodChannelGet3DOcclusion`);
	loadSym(fmodChannelSet3DSpread, dll, `fmodChannelSet3DSpread`);
	loadSym(fmodChannelGet3DSpread, dll, `fmodChannelGet3DSpread`);
	loadSym(fmodChannelSet3DPanLevel, dll, `fmodChannelSet3DPanLevel`);
	loadSym(fmodChannelGet3DPanLevel, dll, `fmodChannelGet3DPanLevel`);
	loadSym(fmodChannelSet3DDopplerLevel, dll, `fmodChannelSet3DDopplerLevel`);
	loadSym(fmodChannelGet3DDopplerLevel, dll, `fmodChannelGet3DDopplerLevel`);

	loadSym(fmodChannelGetDSPHead, dll, `fmodChannelGetDSPHead`);
	loadSym(fmodChannelAddDSP, dll, `fmodChannelAddDSP`);

	loadSym(fmodChannelIsPlaying, dll, `fmodChannelIsPlaying`);
	loadSym(fmodChannelIsVirtual, dll, `fmodChannelIsVirtual`);
	loadSym(fmodChannelGetAudibility, dll, `fmodChannelGetAudibility`);
	loadSym(fmodChannelGetCurrentSound, dll, `fmodChannelGetCurrentSound`);
	loadSym(fmodChannelGetSpectrum, dll, `fmodChannelGetSpectrum`);
	loadSym(fmodChannelGetWaveData, dll, `fmodChannelGetWaveData`);
	loadSym(fmodChannelGetIndex, dll, `fmodChannelGetIndex`);

	loadSym(fmodChannelSetMode, dll, `fmodChannelSetMode`);
	loadSym(fmodChannelGetMode, dll, `fmodChannelGetMode`);
	loadSym(fmodChannelSetLoopCount, dll, `fmodChannelSetLoopCount`);
	loadSym(fmodChannelGetLoopCount, dll, `fmodChannelGetLoopCount`);
	loadSym(fmodChannelSetLoopPoints, dll, `fmodChannelSetLoopPoints`);
	loadSym(fmodChannelGetLoopPoints, dll, `fmodChannelGetLoopPoints`);

	loadSym(fmodChannelSetUserData, dll, `fmodChannelSetUserData`);
	loadSym(fmodChannelGetUserData, dll, `fmodChannelGetUserData`);
	
	loadSym(fmodChannelGroupRelease, dll, `fmodChannelGroupRelease`);
	loadSym(fmodChannelGroupGetSystemObject, dll, `fmodChannelGroupGetSystemObject`);

	loadSym(fmodChannelGroupSetVolume, dll, `fmodChannelGroupSetVolume`);
	loadSym(fmodChannelGroupGetVolume, dll, `fmodChannelGroupGetVolume`);
	loadSym(fmodChannelGroupSetPitch, dll, `fmodChannelGroupSetPitch`);
	loadSym(fmodChannelGroupGetPitch, dll, `fmodChannelGroupGetPitch`);

	loadSym(fmodChannelGroupStop, dll, `fmodChannelGroupStop`);
	loadSym(fmodChannelGroupOverridePaused, dll, `fmodChannelGroupOverridePaused`);
	loadSym(fmodChannelGroupOverrideVolume, dll, `fmodChannelGroupOverrideVolume`);
	loadSym(fmodChannelGroupOverrideFrequency, dll, `fmodChannelGroupOverrideFrequency`);
	loadSym(fmodChannelGroupOverridePan, dll, `fmodChannelGroupOverridePan`);
	loadSym(fmodChannelGroupOverrideMute, dll, `fmodChannelGroupOverrideMute`);
	loadSym(fmodChannelGroupOverrideReverbProperties, dll, `fmodChannelGroupOverrideReverbProperties`);
	loadSym(fmodChannelGroupOverride3DAttributes, dll, `fmodChannelGroupOverride3DAttributes`);
	loadSym(fmodChannelGroupOverrideSpeakerMix, dll, `fmodChannelGroupOverrideSpeakerMix`);
	loadSym(fmodChannelGroupAddGroup, dll, `fmodChannelGroupAddGroup`);
	loadSym(fmodChannelGroupGetNumGroups, dll, `fmodChannelGroupGetNumGroups`);
	loadSym(fmodChannelGroupGetGroup, dll, `fmodChannelGroupGetGroup`);

	loadSym(fmodChannelGroupGetDSPHead, dll, `fmodChannelGroupGetDSPHead`);
	loadSym(fmodChannelGroupAddDSP, dll, `fmodChannelGroupAddDSP`);
	loadSym(fmodChannelGroupGetName, dll, `fmodChannelGroupGetName`);
	loadSym(fmodChannelGroupGetNumChannels, dll, `fmodChannelGroupGetNumChannels`);
	loadSym(fmodChannelGroupGetChannels, dll, `fmodChannelGroupGetChannels`);
	loadSym(fmodChannelGroupGetSpectrum, dll, `fmodChannelGroupGetSpectrum`);
	loadSym(fmodChannelGroupGetWaveData, dll, `fmodChannelGroupGetWaveData`);

	loadSym(fmodChannelGroupSetUserData, dll, `fmodChannelGroupSetUserData`);
	loadSym(fmodChannelGroupGetUserData, dll, `fmodChannelGroupGetUserData`);

	loadSym(fmodDSPRelease, dll, `fmodDSPRelease`);
	loadSym(fmodDSPGetSystemObject, dll, `fmodDSPGetSystemObject`);
	loadSym(fmodDSPAddInput, dll, `fmodDSPAddInput`);
	loadSym(fmodDSPDisconnectFrom, dll, `fmodDSPDisconnectFrom`);
	loadSym(fmodDSPDisconnectAll, dll, `fmodDSPDisconnectAll`);
	loadSym(fmodDSPRemove, dll, `fmodDSPRemove`);
	loadSym(fmodDSPGetNumInputs, dll, `fmodDSPGetNumInputs`);
	loadSym(fmodDSPGetNumOutputs, dll, `fmodDSPGetNumOutputs`);
	loadSym(fmodDSPGetInput, dll, `fmodDSPGetInput`);
	loadSym(fmodDSPGetOutput, dll, `fmodDSPGetOutput`);
	loadSym(fmodDSPSetInputMix, dll, `fmodDSPSetInputMix`);
	loadSym(fmodDSPGetInputMix, dll, `fmodDSPGetInputMix`);
	loadSym(fmodDSPSetInputLevels, dll, `fmodDSPSetInputLevels`);
	loadSym(fmodDSPGetInputLevels, dll, `fmodDSPGetInputLevels`);
	loadSym(fmodDSPSetOutputMix, dll, `fmodDSPSetOutputMix`);
	loadSym(fmodDSPGetOutputMix, dll, `fmodDSPGetOutputMix`);
	loadSym(fmodDSPSetOutputLevels, dll, `fmodDSPSetOutputLevels`);
	loadSym(fmodDSPGetOutputLevels, dll, `fmodDSPGetOutputLevels`);

	loadSym(fmodDSPSetActive, dll, `fmodDSPSetActive`);
	loadSym(fmodDSPGetActive, dll, `fmodDSPGetActive`);
	loadSym(fmodDSPSetBypass, dll, `fmodDSPSetBypass`);
	loadSym(fmodDSPGetBypass, dll, `fmodDSPGetBypass`);

	loadSym(fmodDSPSetParameter, dll, `fmodDSPSetParameter`);
	loadSym(fmodDSPGetParameter, dll, `fmodDSPGetParameter`);
	loadSym(fmodDSPGetNumParameters, dll, `fmodDSPGetNumParameters`);
	loadSym(fmodDSPGetParameterInfo, dll, `fmodDSPGetParameterInfo`);
	loadSym(fmodDSPShowConfigDialog, dll, `fmodDSPShowConfigDialog`);	

	loadSym(fmodDSPGetInfo, dll, `fmodDSPGetInfo`);
	loadSym(fmodDSPGetType, dll, `fmodDSPGetType`);
	loadSym(fmodDSPSetDefaults, dll, `fmodDSPSetDefaults`);
	loadSym(fmodDSPGetDefaults, dll, `fmodDSPGetDefaults`);

	loadSym(fmodDSPSetUserData, dll, `fmodDSPSetUserData`);
	loadSym(fmodDSPGetUserData, dll, `fmodDSPGetUserData`);

	loadSym(fmodGeometryRelease, dll, `fmodGeometryRelease`);
	loadSym(fmodGeometryAddPolygon, dll, `fmodGeometryAddPolygon`);
	loadSym(fmodGeometryGetNumPolygons, dll, `fmodGeometryGetNumPolygons`);
	loadSym(fmodGeometryGetMaxPolygons, dll, `fmodGeometryGetMaxPolygons`);
	loadSym(fmodGeometryGetPolygonNumVertices, dll, `fmodGeometryGetPolygonNumVertices`);
	loadSym(fmodGeometrySetPolygonVertex, dll, `fmodGeometrySetPolygonVertex`);
	loadSym(fmodGeometryGetPolygonVertex, dll, `fmodGeometryGetPolygonVertex`);
	loadSym(fmodGeometrySetPolygonAttributes, dll, `fmodGeometrySetPolygonAttributes`);
	loadSym(fmodGeometryGetPolygonAttributes, dll, `fmodGeometryGetPolygonAttributes`);
	loadSym(fmodGeometrySetActive, dll, `fmodGeometrySetActive`);
	loadSym(fmodGeometryGetActive, dll, `fmodGeometryGetActive`);
	loadSym(fmodGeometrySetRotation, dll, `fmodGeometrySetRotation`);
	loadSym(fmodGeometryGetRotation, dll, `fmodGeometryGetRotation`);
	loadSym(fmodGeometrySetPosition, dll, `fmodGeometrySetPosition`);
	loadSym(fmodGeometryGetPosition, dll, `fmodGeometryGetPosition`);
	loadSym(fmodGeometrySetScale, dll, `fmodGeometrySetScale`);
	loadSym(fmodGeometryGetScale, dll, `fmodGeometryGetScale`);
	loadSym(fmodGeometrySave, dll, `fmodGeometrySave`);

	loadSym(fmodGeometrySetUserData, dll, `fmodGeometrySetUserData`);
	loadSym(fmodGeometryGetUserData, dll, `fmodGeometryGetUserData`);
}


char[] fmodErrorString(FMOD_RESULT errcode)
{
    switch(errcode)
    {
        case FMOD_RESULT.FMOD_ERR_ALREADYLOCKED:          return "Tried to call lock a second time before unlock was called. ";
        case FMOD_RESULT.FMOD_ERR_BADCOMMAND:             return "Tried to call a function on a data type that does not allow this type of functionality (ie calling Sound::lock on a streaming sound). ";
        case FMOD_RESULT.FMOD_ERR_CDDA_DRIVERS:           return "Neither NTSCSI nor ASPI could be initialised. ";
        case FMOD_RESULT.FMOD_ERR_CDDA_INIT:              return "An error occurred while initialising the CDDA subsystem. ";
        case FMOD_RESULT.FMOD_ERR_CDDA_INVALID_DEVICE:    return "Couldn't find the specified device. ";
        case FMOD_RESULT.FMOD_ERR_CDDA_NOAUDIO:           return "No audio tracks on the specified disc. ";
        case FMOD_RESULT.FMOD_ERR_CDDA_NODEVICES:         return "No CD/DVD devices were found. ";
        case FMOD_RESULT.FMOD_ERR_CDDA_NODISC:            return "No disc present in the specified drive. ";
        case FMOD_RESULT.FMOD_ERR_CDDA_READ:              return "A CDDA read error occurred. ";
        case FMOD_RESULT.FMOD_ERR_CHANNEL_ALLOC:          return "Error trying to allocate a channel. ";
        case FMOD_RESULT.FMOD_ERR_CHANNEL_STOLEN:         return "The specified channel has been reused to play another sound. ";
        case FMOD_RESULT.FMOD_ERR_COM:                    return "A Win32 COM related error occured. COM failed to initialize or a QueryInterface failed meaning a Windows codec or driver was not installed properly. ";
        case FMOD_RESULT.FMOD_ERR_DMA:                    return "DMA Failure.  See debug output for more information. ";
        case FMOD_RESULT.FMOD_ERR_DSP_CONNECTION:         return "DSP connection error.  Connection possibly caused a cyclic dependancy. ";
        case FMOD_RESULT.FMOD_ERR_DSP_FORMAT:             return "DSP Format error.  A DSP unit may have attempted to connect to this network with the wrong format. ";
        case FMOD_RESULT.FMOD_ERR_DSP_NOTFOUND:           return "DSP connection error.  Couldn't find the DSP unit specified. ";
        case FMOD_RESULT.FMOD_ERR_DSP_RUNNING:            return "DSP error.  Cannot perform this operation while the network is in the middle of running.  This will most likely happen if a connection or disconnection is attempted in a DSP callback. ";
        case FMOD_RESULT.FMOD_ERR_DSP_TOOMANYCONNECTIONS: return "DSP connection error.  The unit being connected to or disconnected should only have 1 input or output. ";
        case FMOD_RESULT.FMOD_ERR_EVENT_FAILED:           return "An Event failed to be retrieved, most likely due to 'just fail' being specified as the max playbacks behaviour. ";
        case FMOD_RESULT.FMOD_ERR_EVENT_INFOONLY:         return "Can't execute this command on an EVENT_INFOONLY event. ";
        case FMOD_RESULT.FMOD_ERR_EVENT_INTERNAL:         return "An error occured that wasn't supposed to.  See debug log for reason. ";
        case FMOD_RESULT.FMOD_ERR_EVENT_NAMECONFLICT:     return "A category with the same name already exists. ";
        case FMOD_RESULT.FMOD_ERR_EVENT_NOTFOUND:         return "The requested event, event group, event category or event property could not be found. ";
        case FMOD_RESULT.FMOD_ERR_FILE_BAD:               return "Error loading file. ";
        case FMOD_RESULT.FMOD_ERR_FILE_COULDNOTSEEK:      return "Couldn't perform seek operation.  This is a limitation of the medium (ie netstreams) or the file format. ";
        case FMOD_RESULT.FMOD_ERR_FILE_EOF:               return "End of file unexpectedly reached while trying to read essential data (truncated data?). ";
        case FMOD_RESULT.FMOD_ERR_FILE_NOTFOUND:          return "File not found. ";
        case FMOD_RESULT.FMOD_ERR_FILE_UNWANTED:          return "Unwanted file access occured. ";
        case FMOD_RESULT.FMOD_ERR_FORMAT:                 return "Unsupported file or audio format. ";
        case FMOD_RESULT.FMOD_ERR_HTTP:                   return "A HTTP error occurred. This is a catch-all for HTTP errors not listed elsewhere. ";
        case FMOD_RESULT.FMOD_ERR_HTTP_ACCESS:            return "The specified resource requires authentication or is forbidden. ";
        case FMOD_RESULT.FMOD_ERR_HTTP_PROXY_AUTH:        return "Proxy authentication is required to access the specified resource. ";
        case FMOD_RESULT.FMOD_ERR_HTTP_SERVER_ERROR:      return "A HTTP server error occurred. ";
        case FMOD_RESULT.FMOD_ERR_HTTP_TIMEOUT:           return "The HTTP request timed out. ";
        case FMOD_RESULT.FMOD_ERR_INITIALIZATION:         return "FMOD was not initialized correctly to support this function. ";
        case FMOD_RESULT.FMOD_ERR_INITIALIZED:            return "Cannot call this command after System::init. ";
        case FMOD_RESULT.FMOD_ERR_INTERNAL:               return "An error occured that wasn't supposed to.  Contact support. ";
        case FMOD_RESULT.FMOD_ERR_INVALID_ADDRESS:        return "On Xbox 360, this memory address passed to FMOD must be physical, (ie allocated with XPhysicalAlloc.) ";
        case FMOD_RESULT.FMOD_ERR_INVALID_FLOAT:          return "Value passed in was a NaN, Inf or denormalized float. ";
        case FMOD_RESULT.FMOD_ERR_INVALID_HANDLE:         return "An invalid object handle was used. ";
        case FMOD_RESULT.FMOD_ERR_INVALID_PARAM:          return "An invalid parameter was passed to this function. ";
        case FMOD_RESULT.FMOD_ERR_INVALID_SPEAKER:        return "An invalid speaker was passed to this function based on the current speaker mode. ";
        case FMOD_RESULT.FMOD_ERR_INVALID_VECTOR:         return "The vectors passed in are not unit length, or perpendicular. ";
        case FMOD_RESULT.FMOD_ERR_IRX:                    return "PS2 only.  fmodex.irx failed to initialize.  This is most likely because you forgot to load it. ";
        case FMOD_RESULT.FMOD_ERR_MEMORY:                 return "Not enough memory or resources. ";
        case FMOD_RESULT.FMOD_ERR_MEMORY_CANTPOINT:       return "Can't use FMOD_OPENMEMORY_POINT on non PCM source data, or non mp3/xma/adpcm data if FMOD_CREATECOMPRESSEDSAMPLE was used. ";
        case FMOD_RESULT.FMOD_ERR_MEMORY_IOP:             return "PS2 only.  Not enough memory or resources on PlayStation 2 IOP ram. ";
        case FMOD_RESULT.FMOD_ERR_MEMORY_SRAM:            return "Not enough memory or resources on console sound ram. ";
        case FMOD_RESULT.FMOD_ERR_NEEDS2D:                return "Tried to call a command on a 3d sound when the command was meant for 2d sound. ";
        case FMOD_RESULT.FMOD_ERR_NEEDS3D:                return "Tried to call a command on a 2d sound when the command was meant for 3d sound. ";
        case FMOD_RESULT.FMOD_ERR_NEEDSHARDWARE:          return "Tried to use a feature that requires hardware support.  (ie trying to play a VAG compressed sound in software on PS2). ";
        case FMOD_RESULT.FMOD_ERR_NEEDSSOFTWARE:          return "Tried to use a feature that requires the software engine.  Software engine has either been turned off, or command was executed on a hardware channel which does not support this feature. ";
        case FMOD_RESULT.FMOD_ERR_NET_CONNECT:            return "Couldn't connect to the specified host. ";
        case FMOD_RESULT.FMOD_ERR_NET_SOCKET_ERROR:       return "A socket error occurred.  This is a catch-all for socket-related errors not listed elsewhere. ";
        case FMOD_RESULT.FMOD_ERR_NET_URL:                return "The specified URL couldn't be resolved. ";
        case FMOD_RESULT.FMOD_ERR_NOTREADY:               return "Operation could not be performed because specified sound is not ready. ";
        case FMOD_RESULT.FMOD_ERR_OUTPUT_ALLOCATED:       return "Error initializing output device, but more specifically, the output device is already in use and cannot be reused. ";
        case FMOD_RESULT.FMOD_ERR_OUTPUT_CREATEBUFFER:    return "Error creating hardware sound buffer. ";
        case FMOD_RESULT.FMOD_ERR_OUTPUT_DRIVERCALL:      return "A call to a standard soundcard driver failed, which could possibly mean a bug in the driver or resources were missing or exhausted. ";
        case FMOD_RESULT.FMOD_ERR_OUTPUT_FORMAT:          return "Soundcard does not support the minimum features needed for this soundsystem (16bit stereo output). ";
        case FMOD_RESULT.FMOD_ERR_OUTPUT_INIT:            return "Error initializing output device. ";
        case FMOD_RESULT.FMOD_ERR_OUTPUT_NOHARDWARE:      return "FMOD_HARDWARE was specified but the sound card does not have the resources nescessary to play it. ";
        case FMOD_RESULT.FMOD_ERR_OUTPUT_NOSOFTWARE:      return "Attempted to create a software sound but no software channels were specified in System::init. ";
        case FMOD_RESULT.FMOD_ERR_PAN:                    return "Panning only works with mono or stereo sound sources. ";
        case FMOD_RESULT.FMOD_ERR_PLUGIN:                 return "An unspecified error has been returned from a 3rd party plugin. ";
        case FMOD_RESULT.FMOD_ERR_PLUGIN_MISSING:         return "A requested output, dsp unit type or codec was not available. ";
        case FMOD_RESULT.FMOD_ERR_PLUGIN_RESOURCE:        return "A resource that the plugin requires cannot be found. (ie the DLS file for MIDI playback) ";
        case FMOD_RESULT.FMOD_ERR_RECORD:                 return "An error occured trying to initialize the recording device. ";
        case FMOD_RESULT.FMOD_ERR_REVERB_INSTANCE:        return "Specified Instance in FMOD_REVERB_PROPERTIES couldn't be set. Most likely because another application has locked the EAX4 FX slot. ";
        case FMOD_RESULT.FMOD_ERR_SUBSOUNDS:              return "The error occured because the sound referenced contains subsounds.  (ie you cannot play the parent sound as a static sample, only its subsounds.) ";
        case FMOD_RESULT.FMOD_ERR_SUBSOUND_ALLOCATED:     return "This subsound is already being used by another sound, you cannot have more than one parent to a sound.  Null out the other parent's entry first. ";
        case FMOD_RESULT.FMOD_ERR_TAGNOTFOUND:            return "The specified tag could not be found or there are no tags. ";
        case FMOD_RESULT.FMOD_ERR_TOOMANYCHANNELS:        return "The sound created exceeds the allowable input channel count.  This can be increased using the maxinputchannels parameter in System::setSoftwareFormat. ";
        case FMOD_RESULT.FMOD_ERR_UNIMPLEMENTED:          return "Something in FMOD hasn't been implemented when it should be! contact support! ";
        case FMOD_RESULT.FMOD_ERR_UNINITIALIZED:          return "This command failed because System::init or System::setDriver was not called. ";
        case FMOD_RESULT.FMOD_ERR_UNSUPPORTED:            return "A command issued was not supported by this object.  Possibly a plugin without certain callbacks specified. ";
        case FMOD_RESULT.FMOD_ERR_UPDATE:                 return "An error caused by System::update occured. ";
        case FMOD_RESULT.FMOD_ERR_VERSION:                return "The version number of this file format is not supported. ";
        case FMOD_RESULT.FMOD_OK:                         return "No errors.";
        default :                             return "Unknown error.";
    };
}
