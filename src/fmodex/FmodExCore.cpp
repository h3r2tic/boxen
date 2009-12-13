#include "fmod.h"
#include <cstdio>

extern "C"
{
	__declspec(dllexport) void dupa()
	{
		printf("dupa\n");
	}

	/*
		FMOD global system functions (optional).
	*/

	__declspec(dllexport) FMOD_RESULT fmodMemoryInitialize(void *poolmem, int poollen, FMOD_MEMORY_ALLOCCALLBACK useralloc,
			FMOD_MEMORY_REALLOCCALLBACK userrealloc, FMOD_MEMORY_FREECALLBACK userfree)
	{
		return FMOD_Memory_Initialize(poolmem, poollen, useralloc, userrealloc, userfree);
	}

	__declspec(dllexport) FMOD_RESULT fmodMemoryGetStats(int *currentalloced, int *maxalloced)
	{
		return FMOD_Memory_GetStats(currentalloced, maxalloced);
	}

	__declspec(dllexport) FMOD_RESULT fmodDebugSetLevel(FMOD_DEBUGLEVEL level)
	{
		return FMOD_Debug_SetLevel(level);
	}

	__declspec(dllexport) FMOD_RESULT fmodDebugGetLevel(FMOD_DEBUGLEVEL *level)
	{
		return FMOD_Debug_GetLevel(level);
	}

	__declspec(dllexport) FMOD_RESULT fmodFileSetDiskBusy(int busy)
	{
		return FMOD_File_SetDiskBusy(busy);
	}

	__declspec(dllexport) FMOD_RESULT fmodFileGetDiskBusy(int *busy)
	{
		return FMOD_File_GetDiskBusy(busy);
	}

	/*
		FMOD System factory functions.  Use this to create an FMOD System Instance.  below you will see FMOD_System_Init/Close to get started.
	*/

	__declspec(dllexport) FMOD_RESULT fmodSystemCreate(FMOD_SYSTEM **system)
	{
		return FMOD_System_Create(system);
	}

	__declspec(dllexport) FMOD_RESULT fmodSystemRelease(FMOD_SYSTEM *system)
	{
		return FMOD_System_Release(system);
	}



	/*
		'System' API
	*/

	/*
		 Pre-init functions.
	*/

	__declspec(dllexport) FMOD_RESULT fmodSystemSetOutput(FMOD_SYSTEM *system, FMOD_OUTPUTTYPE output)
	{
		return FMOD_System_SetOutput(system, output);
	}

	__declspec(dllexport) FMOD_RESULT fmodSystemGetOutput(FMOD_SYSTEM *system, FMOD_OUTPUTTYPE *output)
	{
		return FMOD_System_GetOutput(system, output);
	}

	__declspec(dllexport) FMOD_RESULT fmodSystemGetNumDrivers(FMOD_SYSTEM *system, int *numdrivers)
	{
		return FMOD_System_GetNumDrivers(system, numdrivers);
	}

	__declspec(dllexport) FMOD_RESULT fmodSystemGetDriverName(FMOD_SYSTEM *system, int id, char *name, int namelen)
	{
		return FMOD_System_GetDriverName(system, id, name, namelen);
	}

	__declspec(dllexport) FMOD_RESULT fmodSystemGetDriverCaps(FMOD_SYSTEM *system, int id, FMOD_CAPS *caps,
		int *minfrequency, int *maxfrequency, FMOD_SPEAKERMODE *controlpanelspeakermode)
	{
		return FMOD_System_GetDriverCaps(system, id, caps, minfrequency, maxfrequency, controlpanelspeakermode);
	}

	__declspec(dllexport) FMOD_RESULT fmodSystemSetDriver(FMOD_SYSTEM *system, int driver)
	{
		return FMOD_System_SetDriver(system, driver);
	}

	__declspec(dllexport) FMOD_RESULT fmodSystemGetDriver(FMOD_SYSTEM *system, int *driver)
	{
		return FMOD_System_GetDriver(system, driver);
	}

	__declspec(dllexport) FMOD_RESULT fmodSystemSetHardwareChannels(FMOD_SYSTEM *system, int min2d, int max2d, int min3d, int max3d)
	{
		return FMOD_System_SetHardwareChannels(system, min2d, max2d, min3d, max3d);
	}

	__declspec(dllexport) FMOD_RESULT fmodSystemSetSoftwareChannels(FMOD_SYSTEM *system, int numsoftwarechannels)
	{
		return FMOD_System_SetSoftwareChannels(system, numsoftwarechannels);
	}

	__declspec(dllexport) FMOD_RESULT fmodSystemGetSoftwareChannels(FMOD_SYSTEM *system, int *numsoftwarechannels)
	{
		return FMOD_System_GetSoftwareChannels(system, numsoftwarechannels);
	}

	__declspec(dllexport) FMOD_RESULT fmodSystemSetSoftwareFormat(FMOD_SYSTEM *system, int samplerate, FMOD_SOUND_FORMAT format,
		int numoutputchannels, int maxinputchannels, FMOD_DSP_RESAMPLER resamplemethod)
	{
		return FMOD_System_SetSoftwareFormat(system, samplerate, format, numoutputchannels, maxinputchannels, resamplemethod);
	}

	__declspec(dllexport) FMOD_RESULT fmodSystemGetSoftwareFormat(FMOD_SYSTEM *system, int *samplerate, FMOD_SOUND_FORMAT *format,
		int *numoutputchannels, int *maxinputchannels, FMOD_DSP_RESAMPLER *resamplemethod, int *bits)
	{
		return FMOD_System_GetSoftwareFormat(system, samplerate, format, numoutputchannels, maxinputchannels, resamplemethod, bits);
	}

	__declspec(dllexport) FMOD_RESULT fmodSystemSetDSPBufferSize(FMOD_SYSTEM *system, unsigned int bufferlength, int numbuffers)
	{
		return FMOD_System_SetDSPBufferSize(system, bufferlength, numbuffers);
	}

	__declspec(dllexport) FMOD_RESULT fmodSystemGetDSPBufferSize(FMOD_SYSTEM *system, unsigned int *bufferlength, int *numbuffers)
	{
		return FMOD_System_GetDSPBufferSize(system, bufferlength, numbuffers);
	}

	__declspec(dllexport) FMOD_RESULT fmodSystemSetFileSystem(FMOD_SYSTEM *system, FMOD_FILE_OPENCALLBACK useropen,
		FMOD_FILE_CLOSECALLBACK userclose, FMOD_FILE_READCALLBACK userread, FMOD_FILE_SEEKCALLBACK userseek, int blocksize)
	{
		return FMOD_System_SetFileSystem(system, useropen, userclose, userread, userseek, blocksize);
	}

	__declspec(dllexport) FMOD_RESULT fmodSystemAttachFileSystem(FMOD_SYSTEM *system, FMOD_FILE_OPENCALLBACK useropen,
		FMOD_FILE_CLOSECALLBACK userclose, FMOD_FILE_READCALLBACK userread, FMOD_FILE_SEEKCALLBACK userseek)
	{
		return FMOD_System_AttachFileSystem(system, useropen, userclose, userread, userseek);
	}

	__declspec(dllexport) FMOD_RESULT fmodSystemSetAdvancedSettings(FMOD_SYSTEM *system, FMOD_ADVANCEDSETTINGS *settings)
	{
		return FMOD_System_SetAdvancedSettings(system, settings);
	}

	__declspec(dllexport) FMOD_RESULT fmodSystemGetAdvancedSettings(FMOD_SYSTEM *system, FMOD_ADVANCEDSETTINGS *settings)
	{
		return FMOD_System_GetAdvancedSettings(system, settings);
	}

	__declspec(dllexport) FMOD_RESULT fmodSystemSetSpeakerMode(FMOD_SYSTEM *system, FMOD_SPEAKERMODE speakermode)
	{
		return FMOD_System_SetSpeakerMode(system, speakermode);
	}

	__declspec(dllexport) FMOD_RESULT fmodSystemGetSpeakerMode(FMOD_SYSTEM *system, FMOD_SPEAKERMODE *speakermode)
	{
		return FMOD_System_GetSpeakerMode(system, speakermode);
	}


	/*
		 Plug-in support                       
	*/

	__declspec(dllexport) FMOD_RESULT fmodSystemSetPluginPath(FMOD_SYSTEM *system, const char *path)
	{
		return FMOD_System_SetPluginPath(system, path);
	}

	__declspec(dllexport) FMOD_RESULT fmodSystemLoadPlugin(FMOD_SYSTEM *system, const char *filename, FMOD_PLUGINTYPE *plugintype, int *index)
	{
		return FMOD_System_LoadPlugin(system, filename, plugintype, index);
	}

	__declspec(dllexport) FMOD_RESULT fmodSystemGetNumPlugins(FMOD_SYSTEM *system, FMOD_PLUGINTYPE plugintype, int *numplugins)
	{
		return FMOD_System_GetNumPlugins(system, plugintype, numplugins);
	}

	__declspec(dllexport) FMOD_RESULT fmodSystemGetPluginInfo(FMOD_SYSTEM *system, FMOD_PLUGINTYPE plugintype, int index, char *name,
		int namelen, unsigned int *version)
	{
		return FMOD_System_GetPluginInfo(system, plugintype, index, name, namelen, version);
	}

	__declspec(dllexport) FMOD_RESULT fmodSystemUnloadPlugin(FMOD_SYSTEM *system, FMOD_PLUGINTYPE plugintype, int index)
	{
		return FMOD_System_UnloadPlugin(system, plugintype, index);
	}

	__declspec(dllexport) FMOD_RESULT fmodSystemSetOutputByPlugin(FMOD_SYSTEM *system, int index)
	{
		return FMOD_System_SetOutputByPlugin(system, index);
	}

	__declspec(dllexport) FMOD_RESULT fmodSystemGetOutputByPlugin(FMOD_SYSTEM *system, int *index)
	{
		return FMOD_System_GetOutputByPlugin(system, index);
	}

	__declspec(dllexport) FMOD_RESULT fmodSystemCreateCodec(FMOD_SYSTEM *system, FMOD_CODEC_DESCRIPTION *description)
	{
		return FMOD_System_CreateCodec(system, description);
	}


	/*
		 Init/Close                            
	*/

	__declspec(dllexport) FMOD_RESULT fmodSystemInit(FMOD_SYSTEM *system, int maxchannels, FMOD_INITFLAGS flags, void *extradriverdata)
	{
		return FMOD_System_Init(system, maxchannels, flags, extradriverdata);
	}

	__declspec(dllexport) FMOD_RESULT fmodSystemClose(FMOD_SYSTEM *system)
	{
		return FMOD_System_Close(system);
	}


	/*
		 General post-init system functions    
	*/

	__declspec(dllexport) FMOD_RESULT fmodSystemUpdate(FMOD_SYSTEM *system)
	{
		return FMOD_System_Update(system);
	}


	__declspec(dllexport) FMOD_RESULT fmodSystemSet3DSettings(FMOD_SYSTEM *system, float dopplerscale, float distancefactor, float rolloffscale)
	{
		return FMOD_System_Set3DSettings(system, dopplerscale, distancefactor, rolloffscale);
	}

	__declspec(dllexport) FMOD_RESULT fmodSystemGet3DSettings(FMOD_SYSTEM *system, float *dopplerscale, float *distancefactor, float *rolloffscale)
	{
		return FMOD_System_Get3DSettings(system, dopplerscale, distancefactor, rolloffscale);
	}

	__declspec(dllexport) FMOD_RESULT fmodSystemSet3DNumListeners(FMOD_SYSTEM *system, int numlisteners)
	{
		return FMOD_System_Set3DNumListeners(system, numlisteners);
	}

	__declspec(dllexport) FMOD_RESULT fmodSystemGet3DNumListeners(FMOD_SYSTEM *system, int *numlisteners)
	{
		return FMOD_System_Get3DNumListeners(system, numlisteners);
	}

	__declspec(dllexport) FMOD_RESULT fmodSystemSet3DListenerAttributes(FMOD_SYSTEM *system, int listener, const FMOD_VECTOR *pos,
		const FMOD_VECTOR *vel, const FMOD_VECTOR *forward, const FMOD_VECTOR *up)
	{
		return FMOD_System_Set3DListenerAttributes(system, listener, pos, vel, forward, up);
	}

	__declspec(dllexport) FMOD_RESULT fmodSystemGet3DListenerAttributes(FMOD_SYSTEM *system, int listener, FMOD_VECTOR *pos, FMOD_VECTOR *vel,
		FMOD_VECTOR *forward, FMOD_VECTOR *up)
	{
		return FMOD_System_Get3DListenerAttributes(system, listener, pos, vel, forward, up);
	}


	__declspec(dllexport) FMOD_RESULT fmodSystemSetSpeakerPosition(FMOD_SYSTEM *system, FMOD_SPEAKER speaker, float x, float y)
	{
		return FMOD_System_SetSpeakerPosition(system, speaker, x, y);
	}

	__declspec(dllexport) FMOD_RESULT fmodSystemGetSpeakerPosition(FMOD_SYSTEM *system, FMOD_SPEAKER speaker, float *x, float *y)
	{
		return FMOD_System_GetSpeakerPosition(system, speaker, x, y);
	}

	__declspec(dllexport) FMOD_RESULT fmodSystemSetStreamBufferSize(FMOD_SYSTEM *system, unsigned int filebuffersize, FMOD_TIMEUNIT filebuffersizetype)
	{
		return FMOD_System_SetStreamBufferSize(system, filebuffersize, filebuffersizetype);
	}

	__declspec(dllexport) FMOD_RESULT fmodSystemGetStreamBufferSize(FMOD_SYSTEM *system, unsigned int *filebuffersize, FMOD_TIMEUNIT *filebuffersizetype)
	{
		return FMOD_System_GetStreamBufferSize(system, filebuffersize, filebuffersizetype);
	}


	/*
		 System information functions.        
	*/

	__declspec(dllexport) FMOD_RESULT fmodSystemGetVersion(FMOD_SYSTEM *system, unsigned int *version)
	{
		return FMOD_System_GetVersion(system, version);
	}

	__declspec(dllexport) FMOD_RESULT fmodSystemGetOutputHandle(FMOD_SYSTEM *system, void **handle)
	{
		return FMOD_System_GetOutputHandle(system, handle);
	}

	__declspec(dllexport) FMOD_RESULT fmodSystemGetChannelsPlaying(FMOD_SYSTEM *system, int *channels)
	{
		return FMOD_System_GetChannelsPlaying(system, channels);
	}

	__declspec(dllexport) FMOD_RESULT fmodSystemGetHardwareChannels(FMOD_SYSTEM *system, int *num2d, int *num3d, int *total)
	{
		return FMOD_System_GetHardwareChannels(system, num2d, num3d, total);
	}

	__declspec(dllexport) FMOD_RESULT fmodSystemGetCPUUsage(FMOD_SYSTEM *system, float *dsp, float *stream, float *update, float *total)
	{
		return FMOD_System_GetCPUUsage(system, dsp, stream, update, total);
	}

	__declspec(dllexport) FMOD_RESULT fmodSystemGetSoundRAM(FMOD_SYSTEM *system, int *currentalloced, int *maxalloced, int *total)
	{
		return FMOD_System_GetSoundRAM(system, currentalloced, maxalloced, total);
	}

	__declspec(dllexport) FMOD_RESULT fmodSystemGetNumCDROMDrives(FMOD_SYSTEM *system, int *numdrives)
	{
		return FMOD_System_GetNumCDROMDrives(system, numdrives);
	}

	__declspec(dllexport) FMOD_RESULT fmodSystemGetCDROMDriveName(FMOD_SYSTEM *system, int drive, char *drivename, int drivenamelen,
		char *scsiname, int scsinamelen, char *devicename, int devicenamelen)
	{
		return FMOD_System_GetCDROMDriveName(system, drive, drivename, drivenamelen, scsiname, scsinamelen, devicename, devicenamelen);
	}

	__declspec(dllexport) FMOD_RESULT fmodSystemGetSpectrum(FMOD_SYSTEM *system, float *spectrumarray, int numvalues,
		int channeloffset, FMOD_DSP_FFT_WINDOW windowtype)
	{
		return FMOD_System_GetSpectrum(system, spectrumarray, numvalues, channeloffset, windowtype);
	}

	__declspec(dllexport) FMOD_RESULT fmodSystemGetWaveData(FMOD_SYSTEM *system, float *wavearray, int numvalues, int channeloffset)
	{
		return FMOD_System_GetWaveData(system, wavearray, numvalues, channeloffset);
	}


	/*
		 Sound/DSP/Channel/FX creation and retrieval.       
	*/

	__declspec(dllexport) FMOD_RESULT fmodSystemCreateSound(FMOD_SYSTEM *system, const char *name_or_data, FMOD_MODE mode,
		FMOD_CREATESOUNDEXINFO *exinfo, FMOD_SOUND **sound)
	{
		return FMOD_System_CreateSound(system, name_or_data, mode, exinfo, sound);
	}

	__declspec(dllexport) FMOD_RESULT fmodSystemCreateStream(FMOD_SYSTEM *system, const char *name_or_data, FMOD_MODE mode,
		FMOD_CREATESOUNDEXINFO *exinfo, FMOD_SOUND **sound)
	{
		return FMOD_System_CreateStream(system, name_or_data, mode, exinfo, sound);
	}

	__declspec(dllexport) FMOD_RESULT fmodSystemCreateDSP(FMOD_SYSTEM *system, FMOD_DSP_DESCRIPTION *description, FMOD_DSP **dsp)
	{
		return FMOD_System_CreateDSP(system, description, dsp);
	}

	__declspec(dllexport) FMOD_RESULT fmodSystemCreateDSPByType(FMOD_SYSTEM *system, FMOD_DSP_TYPE type, FMOD_DSP **dsp)
	{
		return FMOD_System_CreateDSPByType(system, type, dsp);
	}

	__declspec(dllexport) FMOD_RESULT fmodSystemCreateDSPByIndex(FMOD_SYSTEM *system, int index, FMOD_DSP **dsp)
	{
		return FMOD_System_CreateDSPByIndex(system, index, dsp);
	}

	__declspec(dllexport) FMOD_RESULT fmodSystemCreateChannelGroup(FMOD_SYSTEM *system, const char *name, FMOD_CHANNELGROUP **channelgroup)
	{
		return FMOD_System_CreateChannelGroup(system, name, channelgroup);
	}


	__declspec(dllexport) FMOD_RESULT fmodSystemPlaySound(FMOD_SYSTEM *system, FMOD_CHANNELINDEX channelid, FMOD_SOUND *sound,
		FMOD_BOOL paused, FMOD_CHANNEL **channel)
	{
		return FMOD_System_PlaySound(system, channelid, sound, paused, channel);
	}

	__declspec(dllexport) FMOD_RESULT fmodSystemPlayDSP(FMOD_SYSTEM *system, FMOD_CHANNELINDEX channelid, FMOD_DSP *dsp,
		FMOD_BOOL paused, FMOD_CHANNEL **channel)
	{
		return FMOD_System_PlayDSP(system, channelid, dsp, paused, channel);
	}

	__declspec(dllexport) FMOD_RESULT fmodSystemGetChannel(FMOD_SYSTEM *system, int channelid, FMOD_CHANNEL **channel)
	{
		return FMOD_System_GetChannel(system, channelid, channel);
	}

	__declspec(dllexport) FMOD_RESULT fmodSystemGetMasterChannelGroup(FMOD_SYSTEM *system, FMOD_CHANNELGROUP **channelgroup)
	{
		return FMOD_System_GetMasterChannelGroup(system, channelgroup);
	}


	/*
		 Reverb API                           
	*/

	__declspec(dllexport) FMOD_RESULT fmodSystemSetReverbProperties(FMOD_SYSTEM *system, const FMOD_REVERB_PROPERTIES *prop)
	{
		return FMOD_System_SetReverbProperties(system, prop);
	}

	__declspec(dllexport) FMOD_RESULT fmodSystemGetReverbProperties(FMOD_SYSTEM *system, FMOD_REVERB_PROPERTIES *prop)
	{
		return FMOD_System_GetReverbProperties(system, prop);
	}


	/*
		 System level DSP access.
	*/

	__declspec(dllexport) FMOD_RESULT fmodSystemGetDSPHead(FMOD_SYSTEM *system, FMOD_DSP **dsp)
	{
		return FMOD_System_GetDSPHead(system, dsp);
	}

	__declspec(dllexport) FMOD_RESULT fmodSystemAddDSP(FMOD_SYSTEM *system, FMOD_DSP *dsp)
	{
		return FMOD_System_AddDSP(system, dsp);
	}

	__declspec(dllexport) FMOD_RESULT fmodSystemLockDSP(FMOD_SYSTEM *system)
	{
		return FMOD_System_LockDSP(system);
	}

	__declspec(dllexport) FMOD_RESULT fmodSystemUnlockDSP(FMOD_SYSTEM *system)
	{
		return FMOD_System_UnlockDSP(system);
	}


	/*
		 Recording API.
	*/

	__declspec(dllexport) FMOD_RESULT fmodSystemSetRecordDriver(FMOD_SYSTEM *system, int driver)
	{
		return FMOD_System_SetRecordDriver(system, driver);
	}

	__declspec(dllexport) FMOD_RESULT fmodSystemGetRecordDriver(FMOD_SYSTEM *system, int *driver)
	{
		return FMOD_System_GetRecordDriver(system, driver);
	}

	__declspec(dllexport) FMOD_RESULT fmodSystemGetRecordNumDrivers(FMOD_SYSTEM *system, int *numdrivers)
	{
		return FMOD_System_GetRecordNumDrivers(system, numdrivers);
	}

	__declspec(dllexport) FMOD_RESULT fmodSystemGetRecordDriverName(FMOD_SYSTEM *system, int id, char *name, int namelen)
	{
		return FMOD_System_GetRecordDriverName(system, id, name, namelen);
	}

	__declspec(dllexport) FMOD_RESULT fmodSystemGetRecordPosition(FMOD_SYSTEM *system, unsigned int *position)
	{
		return FMOD_System_GetRecordPosition(system, position);
	}


	__declspec(dllexport) FMOD_RESULT fmodSystemRecordStart(FMOD_SYSTEM *system, FMOD_SOUND *sound, FMOD_BOOL loop)
	{
		return FMOD_System_RecordStart(system, sound, loop);
	}

	__declspec(dllexport) FMOD_RESULT fmodSystemRecordStop(FMOD_SYSTEM *system)
	{
		return FMOD_System_RecordStop(system);
	}

	__declspec(dllexport) FMOD_RESULT fmodSystemIsRecording(FMOD_SYSTEM *system, FMOD_BOOL *recording)
	{
		return FMOD_System_IsRecording(system, recording);
	}


	/*
		 Geometry API.
	*/

	__declspec(dllexport) FMOD_RESULT fmodSystemCreateGeometry(FMOD_SYSTEM *system, int maxpolygons, int maxvertices, FMOD_GEOMETRY **geometry)
	{
		return FMOD_System_CreateGeometry(system, maxpolygons, maxvertices, geometry);
	}

	__declspec(dllexport) FMOD_RESULT fmodSystemSetGeometrySettings(FMOD_SYSTEM *system, float maxworldsize)
	{
		return FMOD_System_SetGeometrySettings(system, maxworldsize);
	}

	__declspec(dllexport) FMOD_RESULT fmodSystemGetGeometrySettings(FMOD_SYSTEM *system, float *maxworldsize)
	{
		return FMOD_System_GetGeometrySettings(system, maxworldsize);
	}

	__declspec(dllexport) FMOD_RESULT fmodSystemLoadGeometry(FMOD_SYSTEM *system, const void *data, int datasize, FMOD_GEOMETRY **geometry)
	{
		return FMOD_System_LoadGeometry(system, data, datasize, geometry);
	}


	/*
		 Network functions.
	*/

	__declspec(dllexport) FMOD_RESULT fmodSystemSetNetworkProxy(FMOD_SYSTEM *system, const char *proxy)
	{
		return FMOD_System_SetNetworkProxy(system, proxy);
	}

	__declspec(dllexport) FMOD_RESULT fmodSystemGetNetworkProxy(FMOD_SYSTEM *system, char *proxy, int proxylen)
	{
		return FMOD_System_GetNetworkProxy(system, proxy, proxylen);
	}

	__declspec(dllexport) FMOD_RESULT fmodSystemSetNetworkTimeout(FMOD_SYSTEM *system, int timeout)
	{
		return FMOD_System_SetNetworkTimeout(system, timeout);
	}

	__declspec(dllexport) FMOD_RESULT fmodSystemGetNetworkTimeout(FMOD_SYSTEM *system, int *timeout)
	{
		return FMOD_System_GetNetworkTimeout(system, timeout);
	}


	/*
		 Userdata set/get.
	*/

	__declspec(dllexport) FMOD_RESULT fmodSystemSetUserData(FMOD_SYSTEM *system, void *userdata)
	{
		return FMOD_System_SetUserData(system, userdata);
	}

	__declspec(dllexport) FMOD_RESULT fmodSystemGetUserData(FMOD_SYSTEM *system, void **userdata)
	{
		return FMOD_System_GetUserData(system, userdata);
	}


	/*
		'Sound' API
	*/

	__declspec(dllexport) FMOD_RESULT fmodSoundRelease(FMOD_SOUND *sound)
	{
		return FMOD_Sound_Release(sound);
	}

	__declspec(dllexport) FMOD_RESULT fmodSoundGetSystemObject(FMOD_SOUND *sound, FMOD_SYSTEM **system)
	{
		return FMOD_Sound_GetSystemObject(sound, system);
	}


	/*
		 Standard sound manipulation functions.                                                
	*/

	__declspec(dllexport) FMOD_RESULT fmodSoundLock(FMOD_SOUND *sound, unsigned int offset, unsigned int length, void **ptr1, void **ptr2,
		unsigned int *len1, unsigned int *len2)
	{
		return FMOD_Sound_Lock(sound, offset, length, ptr1, ptr2, len1, len2);
	}

	__declspec(dllexport) FMOD_RESULT fmodSoundUnlock(FMOD_SOUND *sound, void *ptr1, void *ptr2, unsigned int len1, unsigned int len2)
	{
		return FMOD_Sound_Unlock(sound, ptr1, ptr2, len1, len2);
	}

	__declspec(dllexport) FMOD_RESULT fmodSoundSetDefaults(FMOD_SOUND *sound, float frequency, float volume, float pan, int priority)
	{
		return FMOD_Sound_SetDefaults(sound, frequency, volume, pan, priority);
	}

	__declspec(dllexport) FMOD_RESULT fmodSoundGetDefaults(FMOD_SOUND *sound, float *frequency, float *volume, float *pan, int *priority)
	{
		return FMOD_Sound_GetDefaults(sound, frequency, volume, pan, priority);
	}

	__declspec(dllexport) FMOD_RESULT fmodSoundSetVariations(FMOD_SOUND *sound, float frequencyvar, float volumevar, float panvar)
	{
		return FMOD_Sound_SetVariations(sound, frequencyvar, volumevar, panvar);
	}

	__declspec(dllexport) FMOD_RESULT fmodSoundGetVariations(FMOD_SOUND *sound, float *frequencyvar, float *volumevar, float *panvar)
	{
		return FMOD_Sound_GetVariations(sound, frequencyvar, volumevar, panvar);
	}

	__declspec(dllexport) FMOD_RESULT fmodSoundSet3DMinMaxDistance(FMOD_SOUND *sound, float min, float max)
	{
		return FMOD_Sound_Set3DMinMaxDistance(sound, min, max);
	}

	__declspec(dllexport) FMOD_RESULT fmodSoundGet3DMinMaxDistance(FMOD_SOUND *sound, float *min, float *max)
	{
		return FMOD_Sound_Get3DMinMaxDistance(sound, min, max);
	}

	__declspec(dllexport) FMOD_RESULT fmodSoundSet3DConeSettings(FMOD_SOUND *sound, float insideconeangle, float outsideconeangle, float outsidevolume)
	{
		return FMOD_Sound_Set3DConeSettings(sound, insideconeangle, outsideconeangle, outsidevolume);
	}

	__declspec(dllexport) FMOD_RESULT fmodSoundGet3DConeSettings(FMOD_SOUND *sound, float *insideconeangle, float *outsideconeangle, float *outsidevolume)
	{
		return FMOD_Sound_Get3DConeSettings(sound, insideconeangle, outsideconeangle, outsidevolume);
	}

	__declspec(dllexport) FMOD_RESULT fmodSoundSet3DCustomRolloff(FMOD_SOUND *sound, FMOD_VECTOR *points, int numpoints)
	{
		return FMOD_Sound_Set3DCustomRolloff(sound, points, numpoints);
	}

	__declspec(dllexport) FMOD_RESULT fmodSoundGet3DCustomRolloff(FMOD_SOUND *sound, FMOD_VECTOR **points, int *numpoints)
	{
		return FMOD_Sound_Get3DCustomRolloff(sound, points, numpoints);
	}

	__declspec(dllexport) FMOD_RESULT fmodSoundSetSubSound(FMOD_SOUND *sound, int index, FMOD_SOUND *subsound)
	{
		return FMOD_Sound_SetSubSound(sound, index, subsound);
	}

	__declspec(dllexport) FMOD_RESULT fmodSoundGetSubSound(FMOD_SOUND *sound, int index, FMOD_SOUND **subsound)
	{
		return FMOD_Sound_GetSubSound(sound, index, subsound);
	}

	__declspec(dllexport) FMOD_RESULT fmodSoundSetSubSoundSentence(FMOD_SOUND *sound, int *subsoundlist, int numsubsounds)
	{
		return FMOD_Sound_SetSubSoundSentence(sound, subsoundlist, numsubsounds);
	}

	__declspec(dllexport) FMOD_RESULT fmodSoundGetName(FMOD_SOUND *sound, char *name, int namelen)
	{
		return FMOD_Sound_GetName(sound, name, namelen);
	}

	__declspec(dllexport) FMOD_RESULT fmodSoundGetLength(FMOD_SOUND *sound, unsigned int *length, FMOD_TIMEUNIT lengthtype)
	{
		return FMOD_Sound_GetLength(sound, length, lengthtype);
	}

	__declspec(dllexport) FMOD_RESULT fmodSoundGetFormat(FMOD_SOUND *sound, FMOD_SOUND_TYPE *type,
			FMOD_SOUND_FORMAT *format, int *channels, int *bits)
	{
		return FMOD_Sound_GetFormat(sound, type, format, channels, bits);
	}

	__declspec(dllexport) FMOD_RESULT fmodSoundGetNumSubSounds(FMOD_SOUND *sound, int *numsubsounds)
	{
		return FMOD_Sound_GetNumSubSounds(sound, numsubsounds);
	}

	__declspec(dllexport) FMOD_RESULT fmodSoundGetNumTags(FMOD_SOUND *sound, int *numtags, int *numtagsupdated)
	{
		return FMOD_Sound_GetNumTags(sound, numtags, numtagsupdated);
	}

	__declspec(dllexport) FMOD_RESULT fmodSoundGetTag(FMOD_SOUND *sound, const char *name, int index, FMOD_TAG *tag)
	{
		return FMOD_Sound_GetTag(sound, name, index, tag);
	}

	__declspec(dllexport) FMOD_RESULT fmodSoundGetOpenState(FMOD_SOUND *sound, FMOD_OPENSTATE *openstate,
			unsigned int *percentbuffered, FMOD_BOOL *starving)
	{
		return FMOD_Sound_GetOpenState(sound, openstate, percentbuffered, starving);
	}

	__declspec(dllexport) FMOD_RESULT fmodSoundReadData(FMOD_SOUND *sound, void *buffer, unsigned int lenbytes, unsigned int *read)
	{
		return FMOD_Sound_ReadData(sound, buffer, lenbytes, read);
	}

	__declspec(dllexport) FMOD_RESULT fmodSoundSeekData(FMOD_SOUND *sound, unsigned int pcm)
	{
		return FMOD_Sound_SeekData(sound, pcm);
	}


	/*
		 Synchronization point API.  These points can come from markers embedded in wav files, and can also generate channel callbacks.        
	*/

	__declspec(dllexport) FMOD_RESULT fmodSoundGetNumSyncPoints(FMOD_SOUND *sound, int *numsyncpoints)
	{
		return FMOD_Sound_GetNumSyncPoints(sound, numsyncpoints);
	}

	__declspec(dllexport) FMOD_RESULT fmodSoundGetSyncPoint(FMOD_SOUND *sound, int index, FMOD_SYNCPOINT **point)
	{
		return FMOD_Sound_GetSyncPoint(sound, index, point);
	}

	__declspec(dllexport) FMOD_RESULT fmodSoundGetSyncPointInfo(FMOD_SOUND *sound, FMOD_SYNCPOINT *point, char *name, int namelen,
			unsigned int *offset, FMOD_TIMEUNIT offsettype)
	{
		return FMOD_Sound_GetSyncPointInfo(sound, point, name, namelen, offset, offsettype);
	}

	__declspec(dllexport) FMOD_RESULT fmodSoundAddSyncPoint(FMOD_SOUND *sound, unsigned int offset, FMOD_TIMEUNIT offsettype,
			const char *name, FMOD_SYNCPOINT **point)
	{
		return FMOD_Sound_AddSyncPoint(sound, offset, offsettype, name, point);
	}

	__declspec(dllexport) FMOD_RESULT fmodSoundDeleteSyncPoint(FMOD_SOUND *sound, FMOD_SYNCPOINT *point)
	{
		return FMOD_Sound_DeleteSyncPoint(sound, point);
	}


	/*
		 Functions also in Channel class but here they are the 'default' to save having to change it in Channel all the time.
	*/

	__declspec(dllexport) FMOD_RESULT fmodSoundSetMode(FMOD_SOUND *sound, FMOD_MODE mode)
	{
		return FMOD_Sound_SetMode(sound, mode);
	}

	__declspec(dllexport) FMOD_RESULT fmodSoundGetMode(FMOD_SOUND *sound, FMOD_MODE *mode)
	{
		return FMOD_Sound_GetMode(sound, mode);
	}

	__declspec(dllexport) FMOD_RESULT fmodSoundSetLoopCount(FMOD_SOUND *sound, int loopcount)
	{
		return FMOD_Sound_SetLoopCount(sound, loopcount);
	}

	__declspec(dllexport) FMOD_RESULT fmodSoundGetLoopCount(FMOD_SOUND *sound, int *loopcount)
	{
		return FMOD_Sound_GetLoopCount(sound, loopcount);
	}

	__declspec(dllexport) FMOD_RESULT fmodSoundSetLoopPoints(FMOD_SOUND *sound, unsigned int loopstart, FMOD_TIMEUNIT loopstarttype,
			unsigned int loopend, FMOD_TIMEUNIT loopendtype)
	{
		return FMOD_Sound_SetLoopPoints(sound, loopstart, loopstarttype, loopend, loopendtype);
	}

	__declspec(dllexport) FMOD_RESULT fmodSoundGetLoopPoints(FMOD_SOUND *sound, unsigned int *loopstart, FMOD_TIMEUNIT loopstarttype,
			unsigned int *loopend, FMOD_TIMEUNIT loopendtype)
	{
		return FMOD_Sound_GetLoopPoints(sound, loopstart, loopstarttype, loopend, loopendtype);
	}


	/*
		 Userdata set/get.
	*/

	__declspec(dllexport) FMOD_RESULT fmodSoundSetUserData(FMOD_SOUND *sound, void *userdata)
	{
		return FMOD_Sound_SetUserData(sound, userdata);
	}

	__declspec(dllexport) FMOD_RESULT fmodSoundGetUserData(FMOD_SOUND *sound, void **userdata)
	{
		return FMOD_Sound_GetUserData(sound, userdata);
	}


	/*
		'Channel' API
	*/

	__declspec(dllexport) FMOD_RESULT fmodChannelGetSystemObject(FMOD_CHANNEL *channel, FMOD_SYSTEM **system)
	{
		return FMOD_Channel_GetSystemObject(channel, system);
	}


	__declspec(dllexport) FMOD_RESULT fmodChannelStop(FMOD_CHANNEL *channel)
	{
		return FMOD_Channel_Stop(channel);
	}

	__declspec(dllexport) FMOD_RESULT fmodChannelSetPaused(FMOD_CHANNEL *channel, FMOD_BOOL paused)
	{
		return FMOD_Channel_SetPaused(channel, paused);
	}

	__declspec(dllexport) FMOD_RESULT fmodChannelGetPaused(FMOD_CHANNEL *channel, FMOD_BOOL *paused)
	{
		return FMOD_Channel_GetPaused(channel, paused);
	}

	__declspec(dllexport) FMOD_RESULT fmodChannelSetVolume(FMOD_CHANNEL *channel, float volume)
	{
		return FMOD_Channel_SetVolume(channel, volume);
	}

	__declspec(dllexport) FMOD_RESULT fmodChannelGetVolume(FMOD_CHANNEL *channel, float *volume)
	{
		return FMOD_Channel_GetVolume(channel, volume);
	}

	__declspec(dllexport) FMOD_RESULT fmodChannelSetFrequency(FMOD_CHANNEL *channel, float frequency)
	{
		return FMOD_Channel_SetFrequency(channel, frequency);
	}

	__declspec(dllexport) FMOD_RESULT fmodChannelGetFrequency(FMOD_CHANNEL *channel, float *frequency)
	{
		return FMOD_Channel_GetFrequency(channel, frequency);
	}

	__declspec(dllexport) FMOD_RESULT fmodChannelSetPan(FMOD_CHANNEL *channel, float pan)
	{
		return FMOD_Channel_SetPan(channel, pan);
	}

	__declspec(dllexport) FMOD_RESULT fmodChannelGetPan(FMOD_CHANNEL *channel, float *pan)
	{
		return FMOD_Channel_GetPan(channel, pan);
	}

	__declspec(dllexport) FMOD_RESULT fmodChannelSetDelay(FMOD_CHANNEL *channel, unsigned int startdelay, unsigned int enddelay)
	{
		return FMOD_Channel_SetDelay(channel, startdelay, enddelay);
	}

	__declspec(dllexport) FMOD_RESULT fmodChannelGetDelay(FMOD_CHANNEL *channel, unsigned int *startdelay, unsigned int *enddelay)
	{
		return FMOD_Channel_GetDelay(channel, startdelay, enddelay);
	}

	__declspec(dllexport) FMOD_RESULT fmodChannelSetSpeakerMix(FMOD_CHANNEL *channel, float frontleft, float frontright, float center, float lfe,
			float backleft, float backright, float sideleft, float sideright)
	{
		return FMOD_Channel_SetSpeakerMix(channel, frontleft, frontright, center, lfe, backleft, backright, sideleft, sideright);
	}

	__declspec(dllexport) FMOD_RESULT fmodChannelGetSpeakerMix(FMOD_CHANNEL *channel, float *frontleft, float *frontright, float *center, float *lfe,
			float *backleft, float *backright, float *sideleft, float *sideright)
	{
		return FMOD_Channel_GetSpeakerMix(channel, frontleft, frontright, center, lfe, backleft, backright, sideleft, sideright);
	}

	__declspec(dllexport) FMOD_RESULT fmodChannelSetSpeakerLevels(FMOD_CHANNEL *channel, FMOD_SPEAKER speaker, float *levels, int numlevels)
	{
		return FMOD_Channel_SetSpeakerLevels(channel, speaker, levels, numlevels);
	}

	__declspec(dllexport) FMOD_RESULT fmodChannelGetSpeakerLevels(FMOD_CHANNEL *channel, FMOD_SPEAKER speaker, float *levels, int numlevels)
	{
		return FMOD_Channel_GetSpeakerLevels(channel, speaker, levels, numlevels);
	}

	__declspec(dllexport) FMOD_RESULT fmodChannelSetMute(FMOD_CHANNEL *channel, FMOD_BOOL mute)
	{
		return FMOD_Channel_SetMute(channel, mute);
	}

	__declspec(dllexport) FMOD_RESULT fmodChannelGetMute(FMOD_CHANNEL *channel, FMOD_BOOL *mute)
	{
		return FMOD_Channel_GetMute(channel, mute);
	}

	__declspec(dllexport) FMOD_RESULT fmodChannelSetPriority(FMOD_CHANNEL *channel, int priority)
	{
		return FMOD_Channel_SetPriority(channel, priority);
	}

	__declspec(dllexport) FMOD_RESULT fmodChannelGetPriority(FMOD_CHANNEL *channel, int *priority)
	{
		return FMOD_Channel_GetPriority(channel, priority);
	}

	__declspec(dllexport) FMOD_RESULT fmodChannelSetPosition(FMOD_CHANNEL *channel, unsigned int position, FMOD_TIMEUNIT postype)
	{
		return FMOD_Channel_SetPosition(channel, position, postype);
	}

	__declspec(dllexport) FMOD_RESULT fmodChannelGetPosition(FMOD_CHANNEL *channel, unsigned int *position, FMOD_TIMEUNIT postype)
	{
		return FMOD_Channel_GetPosition(channel, position, postype);
	}

	__declspec(dllexport) FMOD_RESULT fmodChannelSetReverbProperties(FMOD_CHANNEL *channel, const FMOD_REVERB_CHANNELPROPERTIES *prop)
	{
		return FMOD_Channel_SetReverbProperties(channel, prop);
	}

	__declspec(dllexport) FMOD_RESULT fmodChannelGetReverbProperties(FMOD_CHANNEL *channel, FMOD_REVERB_CHANNELPROPERTIES *prop)
	{
		return FMOD_Channel_GetReverbProperties(channel, prop);
	}

	__declspec(dllexport) FMOD_RESULT fmodChannelSetChannelGroup(FMOD_CHANNEL *channel, FMOD_CHANNELGROUP *channelgroup)
	{
		return FMOD_Channel_SetChannelGroup(channel, channelgroup);
	}

	__declspec(dllexport) FMOD_RESULT fmodChannelGetChannelGroup(FMOD_CHANNEL *channel, FMOD_CHANNELGROUP **channelgroup)
	{
		return FMOD_Channel_GetChannelGroup(channel, channelgroup);
	}

	__declspec(dllexport) FMOD_RESULT fmodChannelSetCallback(FMOD_CHANNEL *channel, FMOD_CHANNEL_CALLBACKTYPE type,
			FMOD_CHANNEL_CALLBACK callback, int command)
	{
		return FMOD_Channel_SetCallback(channel, type, callback, command);
	}


	/*
		 3D functionality.
	*/

	__declspec(dllexport) FMOD_RESULT fmodChannelSet3DAttributes(FMOD_CHANNEL *channel, const FMOD_VECTOR *pos, const FMOD_VECTOR *vel)
	{
		return FMOD_Channel_Set3DAttributes(channel, pos, vel);
	}

	__declspec(dllexport) FMOD_RESULT fmodChannelGet3DAttributes(FMOD_CHANNEL *channel, FMOD_VECTOR *pos, FMOD_VECTOR *vel)
	{
		return FMOD_Channel_Get3DAttributes(channel, pos, vel);
	}

	__declspec(dllexport) FMOD_RESULT fmodChannelSet3DMinMaxDistance(FMOD_CHANNEL *channel, float mindistance, float maxdistance)
	{
		return FMOD_Channel_Set3DMinMaxDistance(channel, mindistance, maxdistance);
	}

	__declspec(dllexport) FMOD_RESULT fmodChannelGet3DMinMaxDistance(FMOD_CHANNEL *channel, float *mindistance, float *maxdistance)
	{
		return FMOD_Channel_Get3DMinMaxDistance(channel, mindistance, maxdistance);
	}

	__declspec(dllexport) FMOD_RESULT fmodChannelSet3DConeSettings(FMOD_CHANNEL *channel, float insideconeangle, float outsideconeangle, float outsidevolume)
	{
		return FMOD_Channel_Set3DConeSettings(channel, insideconeangle, outsideconeangle, outsidevolume);
	}

	__declspec(dllexport) FMOD_RESULT fmodChannelGet3DConeSettings(FMOD_CHANNEL *channel, float *insideconeangle, float *outsideconeangle, float *outsidevolume)
	{
		return FMOD_Channel_Get3DConeSettings(channel, insideconeangle, outsideconeangle, outsidevolume);
	}

	__declspec(dllexport) FMOD_RESULT fmodChannelSet3DConeOrientation(FMOD_CHANNEL *channel, FMOD_VECTOR *orientation)
	{
		return FMOD_Channel_Set3DConeOrientation(channel, orientation);
	}

	__declspec(dllexport) FMOD_RESULT fmodChannelGet3DConeOrientation(FMOD_CHANNEL *channel, FMOD_VECTOR *orientation)
	{
		return FMOD_Channel_Get3DConeOrientation(channel, orientation);
	}

	__declspec(dllexport) FMOD_RESULT fmodChannelSet3DCustomRolloff(FMOD_CHANNEL *channel, FMOD_VECTOR *points, int numpoints)
	{
		return FMOD_Channel_Set3DCustomRolloff(channel, points, numpoints);
	}

	__declspec(dllexport) FMOD_RESULT fmodChannelGet3DCustomRolloff(FMOD_CHANNEL *channel, FMOD_VECTOR **points, int *numpoints)
	{
		return FMOD_Channel_Get3DCustomRolloff(channel, points, numpoints);
	}

	__declspec(dllexport) FMOD_RESULT fmodChannelSet3DOcclusion(FMOD_CHANNEL *channel, float directocclusion, float reverbocclusion)
	{
		return FMOD_Channel_Set3DOcclusion(channel, directocclusion, reverbocclusion);
	}

	__declspec(dllexport) FMOD_RESULT fmodChannelGet3DOcclusion(FMOD_CHANNEL *channel, float *directocclusion, float *reverbocclusion)
	{
		return FMOD_Channel_Get3DOcclusion(channel, directocclusion, reverbocclusion);
	}

	__declspec(dllexport) FMOD_RESULT fmodChannelSet3DSpread(FMOD_CHANNEL *channel, float angle)
	{
		return FMOD_Channel_Set3DSpread(channel, angle);
	}

	__declspec(dllexport) FMOD_RESULT fmodChannelGet3DSpread(FMOD_CHANNEL *channel, float *angle)
	{
		return FMOD_Channel_Get3DSpread(channel, angle);
	}

	__declspec(dllexport) FMOD_RESULT fmodChannelSet3DPanLevel(FMOD_CHANNEL *channel, float level)
	{
		return FMOD_Channel_Set3DPanLevel(channel, level);
	}

	__declspec(dllexport) FMOD_RESULT fmodChannelGet3DPanLevel(FMOD_CHANNEL *channel, float *level)
	{
		return FMOD_Channel_Get3DPanLevel(channel, level);
	}

	__declspec(dllexport) FMOD_RESULT fmodChannelSet3DDopplerLevel(FMOD_CHANNEL *channel, float level)
	{
		return FMOD_Channel_Set3DDopplerLevel(channel, level);
	}

	__declspec(dllexport) FMOD_RESULT fmodChannelGet3DDopplerLevel(FMOD_CHANNEL *channel, float *level)
	{
		return FMOD_Channel_Get3DDopplerLevel(channel, level);
	}


	/*
		 DSP functionality only for channels playing sounds created with FMOD_SOFTWARE.
	*/

	__declspec(dllexport) FMOD_RESULT fmodChannelGetDSPHead(FMOD_CHANNEL *channel, FMOD_DSP **dsp)
	{
		return FMOD_Channel_GetDSPHead(channel, dsp);
	}

	__declspec(dllexport) FMOD_RESULT fmodChannelAddDSP(FMOD_CHANNEL *channel, FMOD_DSP *dsp)
	{
		return FMOD_Channel_AddDSP(channel, dsp);
	}


	/*
		 Information only functions.
	*/

	__declspec(dllexport) FMOD_RESULT fmodChannelIsPlaying(FMOD_CHANNEL *channel, FMOD_BOOL *isplaying)
	{
		return FMOD_Channel_IsPlaying(channel, isplaying);
	}

	__declspec(dllexport) FMOD_RESULT fmodChannelIsVirtual(FMOD_CHANNEL *channel, FMOD_BOOL *isvirtual)
	{
		return FMOD_Channel_IsVirtual(channel, isvirtual);
	}

	__declspec(dllexport) FMOD_RESULT fmodChannelGetAudibility(FMOD_CHANNEL *channel, float *audibility)
	{
		return FMOD_Channel_GetAudibility(channel, audibility);
	}

	__declspec(dllexport) FMOD_RESULT fmodChannelGetCurrentSound(FMOD_CHANNEL *channel, FMOD_SOUND **sound)
	{
		return FMOD_Channel_GetCurrentSound(channel, sound);
	}

	__declspec(dllexport) FMOD_RESULT fmodChannelGetSpectrum(FMOD_CHANNEL *channel, float *spectrumarray, int numvalues, int channeloffset,
			FMOD_DSP_FFT_WINDOW windowtype)
	{
		return FMOD_Channel_GetSpectrum(channel, spectrumarray, numvalues, channeloffset, windowtype);
	}

	__declspec(dllexport) FMOD_RESULT fmodChannelGetWaveData(FMOD_CHANNEL *channel, float *wavearray, int numvalues, int channeloffset)
	{
		return FMOD_Channel_GetWaveData(channel, wavearray, numvalues, channeloffset);
	}

	__declspec(dllexport) FMOD_RESULT fmodChannelGetIndex(FMOD_CHANNEL *channel, int *index)
	{
		return FMOD_Channel_GetIndex(channel, index);
	}


	/*
		 Functions also found in Sound class but here they can be set per channel.
	*/

	__declspec(dllexport) FMOD_RESULT fmodChannelSetMode(FMOD_CHANNEL *channel, FMOD_MODE mode)
	{
		return FMOD_Channel_SetMode(channel, mode);
	}

	__declspec(dllexport) FMOD_RESULT fmodChannelGetMode(FMOD_CHANNEL *channel, FMOD_MODE *mode)
	{
		return FMOD_Channel_GetMode(channel, mode);
	}

	__declspec(dllexport) FMOD_RESULT fmodChannelSetLoopCount(FMOD_CHANNEL *channel, int loopcount)
	{
		return FMOD_Channel_SetLoopCount(channel, loopcount);
	}

	__declspec(dllexport) FMOD_RESULT fmodChannelGetLoopCount(FMOD_CHANNEL *channel, int *loopcount)
	{
		return FMOD_Channel_GetLoopCount(channel, loopcount);
	}

	__declspec(dllexport) FMOD_RESULT fmodChannelSetLoopPoints(FMOD_CHANNEL *channel, unsigned int loopstart, FMOD_TIMEUNIT loopstarttype,
			unsigned int loopend, FMOD_TIMEUNIT loopendtype)
	{
		return FMOD_Channel_SetLoopPoints(channel, loopstart, loopstarttype, loopend, loopendtype);
	}

	__declspec(dllexport) FMOD_RESULT fmodChannelGetLoopPoints(FMOD_CHANNEL *channel, unsigned int *loopstart, FMOD_TIMEUNIT loopstarttype,
			unsigned int *loopend, FMOD_TIMEUNIT loopendtype)
	{
		return FMOD_Channel_GetLoopPoints(channel, loopstart, loopstarttype, loopend, loopendtype);
	}


	/*
		 Userdata set/get.                                                
	*/

	__declspec(dllexport) FMOD_RESULT fmodChannelSetUserData(FMOD_CHANNEL *channel, void *userdata)
	{
		return FMOD_Channel_SetUserData(channel, userdata);
	}

	__declspec(dllexport) FMOD_RESULT fmodChannelGetUserData(FMOD_CHANNEL *channel, void **userdata)
	{
		return FMOD_Channel_GetUserData(channel, userdata);
	}


	/*
		'ChannelGroup' API
	*/

	__declspec(dllexport) FMOD_RESULT fmodChannelGroupRelease(FMOD_CHANNELGROUP *channelgroup)
	{
		return FMOD_ChannelGroup_Release(channelgroup);
	}

	__declspec(dllexport) FMOD_RESULT fmodChannelGroupGetSystemObject(FMOD_CHANNELGROUP *channelgroup, FMOD_SYSTEM **system)
	{
		return FMOD_ChannelGroup_GetSystemObject(channelgroup, system);
	}


	/*
		 Channelgroup scale values.  (changes attributes relative to the channels, doesn't overwrite them)
	*/

	__declspec(dllexport) FMOD_RESULT fmodChannelGroupSetVolume(FMOD_CHANNELGROUP *channelgroup, float volume)
	{
		return FMOD_ChannelGroup_SetVolume(channelgroup, volume);
	}

	__declspec(dllexport) FMOD_RESULT fmodChannelGroupGetVolume(FMOD_CHANNELGROUP *channelgroup, float *volume)
	{
		return FMOD_ChannelGroup_GetVolume(channelgroup, volume);
	}

	__declspec(dllexport) FMOD_RESULT fmodChannelGroupSetPitch(FMOD_CHANNELGROUP *channelgroup, float pitch)
	{
		return FMOD_ChannelGroup_SetPitch(channelgroup, pitch);
	}

	__declspec(dllexport) FMOD_RESULT fmodChannelGroupGetPitch(FMOD_CHANNELGROUP *channelgroup, float *pitch)
	{
		return FMOD_ChannelGroup_GetPitch(channelgroup, pitch);
	}


	/*
		 Channelgroup override values.  (recursively overwrites whatever settings the channels had)
	*/

	__declspec(dllexport) FMOD_RESULT fmodChannelGroupStop(FMOD_CHANNELGROUP *channelgroup)
	{
		return FMOD_ChannelGroup_Stop(channelgroup);
	}

	__declspec(dllexport) FMOD_RESULT fmodChannelGroupOverridePaused(FMOD_CHANNELGROUP *channelgroup, FMOD_BOOL paused)
	{
		return FMOD_ChannelGroup_OverridePaused(channelgroup, paused);
	}

	__declspec(dllexport) FMOD_RESULT fmodChannelGroupOverrideVolume(FMOD_CHANNELGROUP *channelgroup, float volume)
	{
		return FMOD_ChannelGroup_OverrideVolume(channelgroup, volume);
	}

	__declspec(dllexport) FMOD_RESULT fmodChannelGroupOverrideFrequency(FMOD_CHANNELGROUP *channelgroup, float frequency)
	{
		return FMOD_ChannelGroup_OverrideFrequency(channelgroup, frequency);
	}

	__declspec(dllexport) FMOD_RESULT fmodChannelGroupOverridePan(FMOD_CHANNELGROUP *channelgroup, float pan)
	{
		return FMOD_ChannelGroup_OverridePan(channelgroup, pan);
	}

	__declspec(dllexport) FMOD_RESULT fmodChannelGroupOverrideMute(FMOD_CHANNELGROUP *channelgroup, FMOD_BOOL mute)
	{
		return FMOD_ChannelGroup_OverrideMute(channelgroup, mute);
	}

	__declspec(dllexport) FMOD_RESULT fmodChannelGroupOverrideReverbProperties(FMOD_CHANNELGROUP *channelgroup, const FMOD_REVERB_CHANNELPROPERTIES *prop)
	{
		return FMOD_ChannelGroup_OverrideReverbProperties(channelgroup, prop);
	}

	__declspec(dllexport) FMOD_RESULT fmodChannelGroupOverride3DAttributes(FMOD_CHANNELGROUP *channelgroup, const FMOD_VECTOR *pos, const FMOD_VECTOR *vel)
	{
		return FMOD_ChannelGroup_Override3DAttributes(channelgroup, pos, vel);
	}

	__declspec(dllexport) FMOD_RESULT fmodChannelGroupOverrideSpeakerMix(FMOD_CHANNELGROUP *channelgroup, float frontleft, float frontright, float center,
			float lfe, float backleft, float backright, float sideleft, float sideright)
	{
		return FMOD_ChannelGroup_OverrideSpeakerMix(channelgroup, frontleft, frontright, center, lfe, backleft, backright,
			sideleft, sideright);
	}


	/*
		 Nested channel groups.
	*/

	__declspec(dllexport) FMOD_RESULT fmodChannelGroupAddGroup(FMOD_CHANNELGROUP *channelgroup, FMOD_CHANNELGROUP *group)
	{
		return FMOD_ChannelGroup_AddGroup(channelgroup, group);
	}

	__declspec(dllexport) FMOD_RESULT fmodChannelGroupGetNumGroups(FMOD_CHANNELGROUP *channelgroup, int *numgroups)
	{
		return FMOD_ChannelGroup_GetNumGroups(channelgroup, numgroups);
	}

	__declspec(dllexport) FMOD_RESULT fmodChannelGroupGetGroup(FMOD_CHANNELGROUP *channelgroup, int index, FMOD_CHANNELGROUP **group)
	{
		return FMOD_ChannelGroup_GetGroup(channelgroup, index, group);
	}


	/*
		 DSP functionality only for channel groups playing sounds created with FMOD_SOFTWARE.
	*/

	__declspec(dllexport) FMOD_RESULT fmodChannelGroupGetDSPHead(FMOD_CHANNELGROUP *channelgroup, FMOD_DSP **dsp)
	{
		return FMOD_ChannelGroup_GetDSPHead(channelgroup, dsp);
	}

	__declspec(dllexport) FMOD_RESULT fmodChannelGroupAddDSP(FMOD_CHANNELGROUP *channelgroup, FMOD_DSP *dsp)
	{
		return FMOD_ChannelGroup_AddDSP(channelgroup, dsp);
	}


	/*
		 Information only functions.
	*/

	__declspec(dllexport) FMOD_RESULT fmodChannelGroupGetName(FMOD_CHANNELGROUP *channelgroup, char *name, int namelen)
	{
		return FMOD_ChannelGroup_GetName(channelgroup, name, namelen);
	}

	__declspec(dllexport) FMOD_RESULT fmodChannelGroupGetNumChannels(FMOD_CHANNELGROUP *channelgroup, int *numchannels)
	{
		return FMOD_ChannelGroup_GetNumChannels(channelgroup, numchannels);
	}

	__declspec(dllexport) FMOD_RESULT fmodChannelGroupGetChannels(FMOD_CHANNELGROUP *channelgroup, int index, FMOD_CHANNEL **channel)
	{
		return FMOD_ChannelGroup_GetChannel(channelgroup, index, channel);
	}

	__declspec(dllexport) FMOD_RESULT fmodChannelGroupGetSpectrum(FMOD_CHANNELGROUP *channelgroup, float *spectrumarray, int numvalues,
			int channeloffset, FMOD_DSP_FFT_WINDOW windowtype)
	{
		return FMOD_ChannelGroup_GetSpectrum(channelgroup, spectrumarray, numvalues, channeloffset, windowtype);
	}

	__declspec(dllexport) FMOD_RESULT fmodChannelGroupGetWaveData(FMOD_CHANNELGROUP *channelgroup, float *wavearray, int numvalues, int channeloffset)
	{
		return FMOD_ChannelGroup_GetWaveData(channelgroup, wavearray, numvalues, channeloffset);
	}


	/*
		 Userdata set/get.
	*/

	__declspec(dllexport) FMOD_RESULT fmodChannelGroupSetUserData(FMOD_CHANNELGROUP *channelgroup, void *userdata)
	{
		return FMOD_ChannelGroup_SetUserData(channelgroup, userdata);
	}

	__declspec(dllexport) FMOD_RESULT fmodChannelGroupGetUserData(FMOD_CHANNELGROUP *channelgroup, void **userdata)
	{
		return FMOD_ChannelGroup_GetUserData(channelgroup, userdata);
	}


	/*
		'DSP' API
	*/

	__declspec(dllexport) FMOD_RESULT fmodDSPRelease(FMOD_DSP *dsp)
	{
		return FMOD_DSP_Release(dsp);
	}

	__declspec(dllexport) FMOD_RESULT fmodDSPGetSystemObject(FMOD_DSP *dsp, FMOD_SYSTEM **system)
	{
		return FMOD_DSP_GetSystemObject(dsp, system);
	}


	/*
		 Connection / disconnection / input and output enumeration.
	*/

	__declspec(dllexport) FMOD_RESULT fmodDSPAddInput(FMOD_DSP *dsp, FMOD_DSP *target)
	{
		return FMOD_DSP_AddInput(dsp, target);
	}

	__declspec(dllexport) FMOD_RESULT fmodDSPDisconnectFrom(FMOD_DSP *dsp, FMOD_DSP *target)
	{
		return FMOD_DSP_DisconnectFrom(dsp, target);
	}

	__declspec(dllexport) FMOD_RESULT fmodDSPDisconnectAll(FMOD_DSP *dsp, FMOD_BOOL inputs, FMOD_BOOL outputs)
	{
		return FMOD_DSP_DisconnectAll(dsp, inputs, outputs);
	}

	__declspec(dllexport) FMOD_RESULT fmodDSPRemove(FMOD_DSP *dsp)
	{
		return FMOD_DSP_Remove(dsp);
	}

	__declspec(dllexport) FMOD_RESULT fmodDSPGetNumInputs(FMOD_DSP *dsp, int *numinputs)
	{
		return FMOD_DSP_GetNumInputs(dsp, numinputs);
	}

	__declspec(dllexport) FMOD_RESULT fmodDSPGetNumOutputs(FMOD_DSP *dsp, int *numoutputs)
	{
		return FMOD_DSP_GetNumOutputs(dsp, numoutputs);
	}

	__declspec(dllexport) FMOD_RESULT fmodDSPGetInput(FMOD_DSP *dsp, int index, FMOD_DSP **input)
	{
		return FMOD_DSP_GetInput(dsp, index, input);
	}

	__declspec(dllexport) FMOD_RESULT fmodDSPGetOutput(FMOD_DSP *dsp, int index, FMOD_DSP **output)
	{
		return FMOD_DSP_GetOutput(dsp, index, output);
	}

	__declspec(dllexport) FMOD_RESULT fmodDSPSetInputMix(FMOD_DSP *dsp, int index, float volume)
	{
		return FMOD_DSP_SetInputMix(dsp, index, volume);
	}

	__declspec(dllexport) FMOD_RESULT fmodDSPGetInputMix(FMOD_DSP *dsp, int index, float *volume)
	{
		return FMOD_DSP_GetInputMix(dsp, index, volume);
	}

	__declspec(dllexport) FMOD_RESULT fmodDSPSetInputLevels(FMOD_DSP *dsp, int index, FMOD_SPEAKER speaker, float *levels, int numlevels)
	{
		return FMOD_DSP_SetInputLevels(dsp, index, speaker, levels, numlevels);
	}

	__declspec(dllexport) FMOD_RESULT fmodDSPGetInputLevels(FMOD_DSP *dsp, int index, FMOD_SPEAKER speaker, float *levels, int numlevels)
	{
		return FMOD_DSP_GetInputLevels(dsp, index, speaker, levels, numlevels);
	}

	__declspec(dllexport) FMOD_RESULT fmodDSPSetOutputMix(FMOD_DSP *dsp, int index, float volume)
	{
		return FMOD_DSP_SetOutputMix(dsp, index, volume);
	}

	__declspec(dllexport) FMOD_RESULT fmodDSPGetOutputMix(FMOD_DSP *dsp, int index, float *volume)
	{
		return FMOD_DSP_GetOutputMix(dsp, index, volume);
	}

	__declspec(dllexport) FMOD_RESULT fmodDSPSetOutputLevels(FMOD_DSP *dsp, int index, FMOD_SPEAKER speaker, float *levels, int numlevels)
	{
		return FMOD_DSP_SetOutputLevels(dsp, index, speaker, levels, numlevels);
	}

	__declspec(dllexport) FMOD_RESULT fmodDSPGetOutputLevels(FMOD_DSP *dsp, int index, FMOD_SPEAKER speaker, float *levels, int numlevels)
	{
		return FMOD_DSP_GetOutputLevels(dsp, index, speaker, levels, numlevels);
	}


	/*
		 DSP unit control.
	*/

	__declspec(dllexport) FMOD_RESULT fmodDSPSetActive(FMOD_DSP *dsp, FMOD_BOOL active)
	{
		return FMOD_DSP_SetActive(dsp, active);
	}

	__declspec(dllexport) FMOD_RESULT fmodDSPGetActive(FMOD_DSP *dsp, FMOD_BOOL *active)
	{
		return FMOD_DSP_GetActive(dsp, active);
	}

	__declspec(dllexport) FMOD_RESULT fmodDSPSetBypass(FMOD_DSP *dsp, FMOD_BOOL bypass)
	{
		return FMOD_DSP_SetBypass(dsp, bypass);
	}

	__declspec(dllexport) FMOD_RESULT fmodDSPGetBypass(FMOD_DSP *dsp, FMOD_BOOL *bypass)
	{
		return FMOD_DSP_GetBypass(dsp, bypass);
	}

	__declspec(dllexport) FMOD_RESULT fmodDSPReset(FMOD_DSP *dsp)
	{
		return FMOD_DSP_Reset(dsp);
	}


	/*
		 DSP parameter control.
	*/

	__declspec(dllexport) FMOD_RESULT fmodDSPSetParameter(FMOD_DSP *dsp, int index, float value)
	{
		return FMOD_DSP_SetParameter(dsp, index, value);
	}

	__declspec(dllexport) FMOD_RESULT fmodDSPGetParameter(FMOD_DSP *dsp, int index, float *value, char *valuestr, int valuestrlen)
	{
		return FMOD_DSP_GetParameter(dsp, index, value, valuestr, valuestrlen);
	}

	__declspec(dllexport) FMOD_RESULT fmodDSPGetNumParameters(FMOD_DSP *dsp, int *numparams)
	{
		return FMOD_DSP_GetNumParameters(dsp, numparams);
	}

	__declspec(dllexport) FMOD_RESULT fmodDSPGetParameterInfo(FMOD_DSP *dsp, int index, char *name, char *label, char *description,
			int descriptionlen, float *min, float *max)
	{
		return FMOD_DSP_GetParameterInfo(dsp, index, name, label, description, descriptionlen, min, max);
	}

	__declspec(dllexport) FMOD_RESULT fmodDSPShowConfigDialog(FMOD_DSP *dsp, void *hwnd, FMOD_BOOL show)
	{
		return FMOD_DSP_ShowConfigDialog(dsp, hwnd, show);
	}


	/*
		 DSP attributes.        
	*/

	__declspec(dllexport) FMOD_RESULT fmodDSPGetInfo(FMOD_DSP *dsp, char *name, unsigned int *version, int *channels, int *configwidth,
			int *configheight)
	{
		return FMOD_DSP_GetInfo(dsp, name, version, channels, configwidth, configheight);
	}

	__declspec(dllexport) FMOD_RESULT fmodDSPGetType(FMOD_DSP *dsp, FMOD_DSP_TYPE *type)
	{
		return FMOD_DSP_GetType(dsp, type);
	}

	__declspec(dllexport) FMOD_RESULT fmodDSPSetDefaults(FMOD_DSP *dsp, float frequency, float volume, float pan, int priority)
	{
		return FMOD_DSP_SetDefaults(dsp, frequency, volume, pan, priority);
	}

	__declspec(dllexport) FMOD_RESULT fmodDSPGetDefaults(FMOD_DSP *dsp, float *frequency, float *volume, float *pan, int *priority)
	{
		return FMOD_DSP_GetDefaults(dsp, frequency, volume, pan, priority);
	}


	/*
		 Userdata set/get.
	*/

	__declspec(dllexport) FMOD_RESULT fmodDSPSetUserData(FMOD_DSP *dsp, void *userdata)
	{
		return FMOD_DSP_SetUserData(dsp, userdata);
	}

	__declspec(dllexport) FMOD_RESULT fmodDSPGetUserData(FMOD_DSP *dsp, void **userdata)
	{
		return FMOD_DSP_GetUserData(dsp, userdata);
	}


	/*
		'Geometry' API
	*/

	__declspec(dllexport) FMOD_RESULT fmodGeometryRelease(FMOD_GEOMETRY *geometry)
	{
		return FMOD_Geometry_Release(geometry);
	}


	__declspec(dllexport) FMOD_RESULT fmodGeometryAddPolygon(FMOD_GEOMETRY *geometry, float directocclusion, float reverbocclusion,
			FMOD_BOOL doublesided, int numvertices, const FMOD_VECTOR *vertices, int *polygonindex)
	{
		return FMOD_Geometry_AddPolygon(geometry, directocclusion, reverbocclusion, doublesided, numvertices, vertices, polygonindex);
	}

	__declspec(dllexport) FMOD_RESULT fmodGeometryGetNumPolygons(FMOD_GEOMETRY *geometry, int *numpolygons)
	{
		return FMOD_Geometry_GetNumPolygons(geometry, numpolygons);
	}

	__declspec(dllexport) FMOD_RESULT fmodGeometryGetMaxPolygons(FMOD_GEOMETRY *geometry, int *maxpolygons, int *maxvertices)
	{
		return FMOD_Geometry_GetMaxPolygons(geometry, maxpolygons, maxvertices);
	}

	__declspec(dllexport) FMOD_RESULT fmodGeometryGetPolygonNumVertices(FMOD_GEOMETRY *geometry, int index, int *numvertices)
	{
		return FMOD_Geometry_GetPolygonNumVertices(geometry, index, numvertices);
	}

	__declspec(dllexport) FMOD_RESULT fmodGeometrySetPolygonVertex(FMOD_GEOMETRY *geometry, int index, int vertexindex, const FMOD_VECTOR *vertex)
	{
		return FMOD_Geometry_SetPolygonVertex(geometry, index, vertexindex, vertex);
	}

	__declspec(dllexport) FMOD_RESULT fmodGeometryGetPolygonVertex(FMOD_GEOMETRY *geometry, int index, int vertexindex, FMOD_VECTOR *vertex)
	{
		return FMOD_Geometry_GetPolygonVertex(geometry, index, vertexindex, vertex);
	}

	__declspec(dllexport) FMOD_RESULT fmodGeometrySetPolygonAttributes(FMOD_GEOMETRY *geometry, int index, float directocclusion, float reverbocclusion,
			FMOD_BOOL doublesided)
	{
		return FMOD_Geometry_SetPolygonAttributes(geometry, index, directocclusion, reverbocclusion, doublesided);
	}

	__declspec(dllexport) FMOD_RESULT fmodGeometryGetPolygonAttributes(FMOD_GEOMETRY *geometry, int index, float *directocclusion, float *reverbocclusion,
			FMOD_BOOL *doublesided)
	{
		return FMOD_Geometry_GetPolygonAttributes(geometry, index, directocclusion, reverbocclusion, doublesided);
	}


	__declspec(dllexport) FMOD_RESULT fmodGeometrySetActive(FMOD_GEOMETRY *geometry, FMOD_BOOL active)
	{
		return FMOD_Geometry_SetActive(geometry, active);
	}

	__declspec(dllexport) FMOD_RESULT fmodGeometryGetActive(FMOD_GEOMETRY *geometry, FMOD_BOOL *active)
	{
		return FMOD_Geometry_GetActive(geometry, active);
	}

	__declspec(dllexport) FMOD_RESULT fmodGeometrySetRotation(FMOD_GEOMETRY *geometry, const FMOD_VECTOR *forward, const FMOD_VECTOR *up)
	{
		return FMOD_Geometry_SetRotation(geometry, forward, up);
	}

	__declspec(dllexport) FMOD_RESULT fmodGeometryGetRotation(FMOD_GEOMETRY *geometry, FMOD_VECTOR *forward, FMOD_VECTOR *up)
	{
		return FMOD_Geometry_GetRotation(geometry, forward, up);
	}

	__declspec(dllexport) FMOD_RESULT fmodGeometrySetPosition(FMOD_GEOMETRY *geometry, const FMOD_VECTOR *position)
	{
		return FMOD_Geometry_SetPosition(geometry, position);
	}

	__declspec(dllexport) FMOD_RESULT fmodGeometryGetPosition(FMOD_GEOMETRY *geometry, FMOD_VECTOR *position)
	{
		return FMOD_Geometry_GetPosition(geometry, position);
	}

	__declspec(dllexport) FMOD_RESULT fmodGeometrySetScale(FMOD_GEOMETRY *geometry, const FMOD_VECTOR *scale)
	{
		return FMOD_Geometry_SetScale(geometry, scale);
	}

	__declspec(dllexport) FMOD_RESULT fmodGeometryGetScale(FMOD_GEOMETRY *geometry, FMOD_VECTOR *scale)
	{
		return FMOD_Geometry_GetScale(geometry, scale);
	}

	__declspec(dllexport) FMOD_RESULT fmodGeometrySave(FMOD_GEOMETRY *geometry, void *data, int *datasize)
	{
		return FMOD_Geometry_Save(geometry, data, datasize);
	}


	/*
		 Userdata set/get.
	*/

	__declspec(dllexport) FMOD_RESULT fmodGeometrySetUserData(FMOD_GEOMETRY *geometry, void *userdata)
	{
		return FMOD_Geometry_SetUserData(geometry, userdata);
	}

	__declspec(dllexport) FMOD_RESULT fmodGeometryGetUserData(FMOD_GEOMETRY *geometry, void **userdata)
	{
		return FMOD_Geometry_GetUserData(geometry, userdata);
	}
}
