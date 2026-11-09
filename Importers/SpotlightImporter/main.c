// 본 제품은 한글과컴퓨터의 한글 문서 파일(.hwp) 공개 문서를 참고하여 개발하였습니다.
//
// CFPlugIn boilerplate for a Spotlight importer (Spotlight Importer
// Programming Guide). macOS does not run CoreSpotlight import extensions for
// files, so .hwp/.hwpx text reaches Spotlight through this plugin, which the
// app bundle carries in Contents/Library/Spotlight.

#include <CoreFoundation/CoreFoundation.h>
#include <CoreFoundation/CFPlugInCOM.h>
#include <CoreServices/CoreServices.h>

#define PLUGIN_ID "D012FA37-247E-44F3-A4DE-3E21219EAA4A"

Boolean GetMetadataForFile(void *thisInterface, CFMutableDictionaryRef attributes,
                           CFStringRef contentTypeUTI, CFStringRef pathToFile);

typedef struct {
    MDImporterInterfaceStruct *interface;
    CFUUIDRef factoryID;
    UInt32 refCount;
} ImporterPlugin;

static HRESULT QueryInterface(void *thisInstance, REFIID iid, LPVOID *ppv);
static ULONG AddRef(void *thisInstance);
static ULONG Release(void *thisInstance);

static MDImporterInterfaceStruct importerInterface = {
    NULL, QueryInterface, AddRef, Release, GetMetadataForFile,
};

static ImporterPlugin *AllocImporterPlugin(CFUUIDRef factoryID) {
    ImporterPlugin *plugin = calloc(1, sizeof(ImporterPlugin));
    plugin->interface = malloc(sizeof(MDImporterInterfaceStruct));
    memcpy(plugin->interface, &importerInterface, sizeof(MDImporterInterfaceStruct));
    plugin->factoryID = CFRetain(factoryID);
    CFPlugInAddInstanceForFactory(factoryID);
    plugin->refCount = 1;
    return plugin;
}

static void DeallocImporterPlugin(ImporterPlugin *plugin) {
    CFUUIDRef factoryID = plugin->factoryID;
    free(plugin->interface);
    free(plugin);
    if (factoryID) {
        CFPlugInRemoveInstanceForFactory(factoryID);
        CFRelease(factoryID);
    }
}

static HRESULT QueryInterface(void *thisInstance, REFIID iid, LPVOID *ppv) {
    CFUUIDRef interfaceID = CFUUIDCreateFromUUIDBytes(kCFAllocatorDefault, iid);
    HRESULT result = E_NOINTERFACE;
    *ppv = NULL;
    if (CFEqual(interfaceID, kMDImporterInterfaceID) || CFEqual(interfaceID, IUnknownUUID)) {
        AddRef(thisInstance);
        *ppv = thisInstance;
        result = S_OK;
    }
    CFRelease(interfaceID);
    return result;
}

static ULONG AddRef(void *thisInstance) {
    return ++((ImporterPlugin *)thisInstance)->refCount;
}

static ULONG Release(void *thisInstance) {
    ImporterPlugin *plugin = thisInstance;
    if (--plugin->refCount == 0) {
        DeallocImporterPlugin(plugin);
        return 0;
    }
    return plugin->refCount;
}

void *MetadataImporterPluginFactory(CFAllocatorRef allocator, CFUUIDRef typeID) {
    if (!CFEqual(typeID, kMDImporterTypeID)) {
        return NULL;
    }
    CFUUIDRef factoryID = CFUUIDCreateFromString(kCFAllocatorDefault, CFSTR(PLUGIN_ID));
    ImporterPlugin *plugin = AllocImporterPlugin(factoryID);
    CFRelease(factoryID);
    return plugin;
}
