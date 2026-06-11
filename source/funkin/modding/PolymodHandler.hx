package funkin.modding;

import polymod.fs.ZipFileSystem;
import funkin.data.dialogue.ConversationRegistry;
import funkin.data.dialogue.DialogueBoxRegistry;
import funkin.data.dialogue.SpeakerRegistry;
import funkin.data.event.SongEventRegistry;
import funkin.data.story.level.LevelRegistry;
import funkin.data.notestyle.NoteStyleRegistry;
import funkin.play.notes.notekind.NoteKindManager;
import funkin.data.song.SongRegistry;
import funkin.data.freeplay.player.PlayerRegistry;
import funkin.data.freeplay.style.FreeplayStyleRegistry;
import funkin.data.stage.StageRegistry;
import funkin.data.stickers.StickerRegistry;
import funkin.data.freeplay.album.AlbumRegistry;
import funkin.data.character.CharacterData.CharacterDataParser;
import funkin.save.Save;
import funkin.util.FileUtil;
import polymod.backends.PolymodAssets.PolymodAssetType;
import polymod.format.ParseRules.TextFileFormat;
import polymod.Polymod;

/**
 * A class for interacting with Polymod, the atomic modding framework for Haxe.
 */
@:nullSafety
class PolymodHandler
{
  /**
   * The API version for the current version of the game. Since 0.5.0, we've just made this the game version!
   * Minor updates rarely impact mods but major versions sometimes do.
   */
  public static var API_VERSION(get, never):String;

  static function get_API_VERSION():String
  {
    return Constants.VERSION;
  }

  /**
   * The Semantic Versioning rule
   * Indicates which mods are compatible with this version of the game.
   * Using more complex rules allows mods from older compatible versions to stay functioning,
   * while preventing mods made for future versions from being installed.
   */
  public static final API_VERSION_RULE:String = '>=0.8.0 <0.9.0';

  /**
   * Where relative to the executable that mods are located.
   */
  static final MOD_FOLDER:String =
    #if (REDIRECT_ASSETS_FOLDER && mac)
    '../../../../../../../example_mods'
    #elseif REDIRECT_ASSETS_FOLDER
    '../../../../example_mods'
    #else
    'mods'
    #end;

  static final CORE_FOLDER:Null<String> =
    #if (REDIRECT_ASSETS_FOLDER && mac)
    '../../../../../../../assets'
    #elseif REDIRECT_ASSETS_FOLDER
    '../../../../assets'
    #else
    null
    #end;

  /**
   * Populated with the directories of mods once they're successfully loaded.
   */
  public static var loadedModDirs:Array<String> = [];

  /**
   * Populated with the IDs of mods once they're successfully loaded.
   */
  public static var loadedModIds:Array<String> = [];

  // Use SysZipFileSystem on native and MemoryZipFilesystem on web.
  static var modFileSystem:Null<ZipFileSystem> = null;

  /**
   * If the mods folder doesn't exist, create it.
   */
  public static function createModRoot():Void
  {
    FileUtil.createDirIfNotExists(MOD_FOLDER);
  }

  /**
   * Loads the game with ALL mods enabled with Polymod.
   */
  public static function loadAllMods():Void
  {
    #if sys
    // Create the mod root if it doesn't exist.
    createModRoot();
    #end
    trace('Initializing Polymod (using all mods)...');
    loadModsByDir(getAllModDirs());
  }

  /**
   * Loads the game with configured mods enabled with Polymod.
   */
  public static function loadEnabledMods():Void
  {
    #if sys
    // Create the mod root if it doesn't exist.
    createModRoot();
    #end
    trace('Initializing Polymod (using configured mods)...');
    loadModsByDir(Save.instance.enabledModDirs.value);
  }

  /**
   * Loads the game without any mods enabled with Polymod.
   */
  public static function loadNoMods():Void
  {
    #if sys
    // Create the mod root if it doesn't exist.
    createModRoot();
    #end
    // We still need to configure the debug print calls etc.
    trace('Initializing Polymod (using no mods)...');
    loadModsByDir([]);
  }

  /**
   * Load all the mods with the directories they're in.
   * @param dirs The ORDERED list of mod ids to load.
   */
  public static function loadModsByDir(dirs:Array<String>):Void
  {
    if (dirs.length == 0)
    {
      trace('You attempted to load zero mods.');
    }
    else
    {
      trace('Attempting to load ${dirs.length} mods...');
    }

    if (modFileSystem == null) modFileSystem = buildFileSystem();

    var loadedModList:Array<ModMetadata> = polymod.Polymod.init({
      // Root directory for all mods.
      modRoot: MOD_FOLDER,
      // The directories for one or more mods to load.
      dirs: dirs,
      // Framework being used to load assets.
      framework: OPENFL,
      // The current version of our API.
      apiVersionRule: API_VERSION_RULE,
      // Call this function any time an error occurs.
      // Enforce semantic version patterns for each mod.
      // modVersions: null,
      // A map telling Polymod what the asset type is for unfamiliar file extensions.
      // extensionMap: [],

      customFilesystem: modFileSystem,

      frameworkParams: buildFrameworkParams(),

      // List of filenames to ignore in mods. Use the default list to ignore the metadata file, etc.
      ignoredFiles: buildIgnoreList(),

      // Parsing rules for various data formats.
      parseRules: buildParseRules(),

      skipDependencyErrors: true,

      // Parse hxc files and register the scripted classes in them.
      useScriptedClasses: false,
      loadScriptsAsync: #if html5 true #else false #end,
    });

    if (loadedModList == null)
    {
      trace('An error occurred! Failed when loading mods!');
    }
    else
    {
      if (loadedModList.length == 0)
      {
        trace('Mod loading complete. We loaded no mods / ${dirs.length} mods.');
      }
      else
      {
        trace('Mod loading complete. We loaded ${loadedModList.length} / ${dirs.length} mods.');
      }
    }

    loadedModIds = [];
    loadedModDirs = [];
    for (mod in loadedModList)
    {
      trace(' * ${mod.title} v${mod.modVersion} [${mod.id}]');
      loadedModDirs.push(mod.dirName);
      loadedModIds.push(mod.id);
    }

    #if FEATURE_DEBUG_FUNCTIONS
    var fileList:Array<String> = Polymod.listModFiles(PolymodAssetType.IMAGE);
    trace('Installed mods have replaced ${fileList.length} images.');
    for (item in fileList)
    {
      trace(' * $item');
    }

    fileList = Polymod.listModFiles(PolymodAssetType.TEXT);
    trace('Installed mods have added/replaced ${fileList.length} text files.');
    for (item in fileList)
    {
      trace(' * $item');
    }

    fileList = Polymod.listModFiles(PolymodAssetType.AUDIO_MUSIC);
    trace('Installed mods have replaced ${fileList.length} music files.');
    for (item in fileList)
    {
      trace(' * $item');
    }

    fileList = Polymod.listModFiles(PolymodAssetType.AUDIO_SOUND);
    trace('Installed mods have replaced ${fileList.length} sound files.');
    for (item in fileList)
    {
      trace(' * $item');
    }

    fileList = Polymod.listModFiles(PolymodAssetType.AUDIO_GENERIC);
    trace('Installed mods have replaced ${fileList.length} generic audio files.');
    for (item in fileList)
    {
      trace(' * $item');
    }
    #end
  }

  static function buildFileSystem():polymod.fs.ZipFileSystem
  {
    polymod.Polymod.onError = PolymodErrorHandler.onPolymodError;
    return new ZipFileSystem({
      modRoot: MOD_FOLDER,
      autoScan: true
    });
  }

  /**
   * Build a list of file paths that will be ignored in mods.
   */
  static function buildIgnoreList():Array<String>
  {
    var result = Polymod.getDefaultIgnoreList();

    result.push('.vscode');
    result.push('.idea');
    result.push('.git');
    result.push('.gitignore');
    result.push('.gitattributes');
    result.push('README.md');

    return result;
  }

  static function buildParseRules():polymod.format.ParseRules
  {
    var output:polymod.format.ParseRules = polymod.format.ParseRules.getDefault();
    // Ensure TXT files have merge support.
    output.addType('txt', TextFileFormat.LINES);

    // You can specify the format of a specific file, with file extension.
    // output.addFile("data/introText.txt", TextFileFormat.LINES)
    return output;
  }

  static inline function buildFrameworkParams():polymod.Polymod.FrameworkParams
  {
    return {
      assetLibraryPaths: [
        'default' => 'preload',
        'shared' => 'shared',
        'songs' => 'songs',
        'videos' => 'videos',
        'tutorial' => 'tutorial',
        'week1' => 'week1',
        'week2' => 'week2',
        'week3' => 'week3',
        'week4' => 'week4',
        'week5' => 'week5',
        'week6' => 'week6',
        'week7' => 'week7',
        'weekend1' => 'weekend1',
        'sserafim' => 'sserafim'
      ],
      coreAssetRedirect: CORE_FOLDER,
    }
  }

  /**
   * Retrieve a list of metadata for ALL installed mods, including disabled mods.
   * @return An array of mod metadata
   */
  public static function getAllMods():Array<ModMetadata>
  {
    trace('Scanning the mods folder...');

    if (modFileSystem == null) modFileSystem = buildFileSystem();

    var modMetadata:Array<ModMetadata> = Polymod.scan({
      modRoot: MOD_FOLDER,
      apiVersionRule: API_VERSION_RULE,
      fileSystem: modFileSystem,
      errorCallback: PolymodErrorHandler.onPolymodError
    });
    trace('Found ${modMetadata.length} mods when scanning.');
    return modMetadata;
  }

  /**
   * Retrieve a list of ALL mod IDs, including disabled mods.
   * @return An array of mod IDs
   */
  public static function getAllModIds():Array<String>
  {
    var modIds:Array<String> = [for (i in getAllMods()) i.id];
    return modIds;
  }

  /**
   * Retrieve a list of ALL mod directory names, including disabled mods.
   * @return An array of mod direcotry names
   */
  public static function getAllModDirs():Array<String>
  {
    var modDirs:Array<String> = [
      for (i in getAllMods()) i.dirName
    ];
    return modDirs;
  }

  /**
   * Retrieve a list of metadata for all enabled mods.
   * @return An array of mod metadata
   */
  public static function getEnabledMods():Array<ModMetadata>
  {
    var modDirs:Array<String> = Save.instance.enabledModDirs.value;
    var modMetadata:Array<ModMetadata> = getAllMods();
    var enabledMods:Array<ModMetadata> = [];
    for (item in modMetadata)
    {
      if (modDirs.indexOf(item.dirName) != -1)
      {
        enabledMods.push(item);
      }
    }
    return enabledMods;
  }

  /**
   * Clear and reload from disk all data assets.
   * Useful for "hot reloading" for fast iteration!
   */
  public static function forceReloadAssets():Void
  {
    // Forcibly reload Polymod so it finds any new files.
    // This will also register all scripts.
    // TODO: Replace this with loadEnabledMods().
    funkin.modding.PolymodHandler.loadAllMods();

    // Reload everything that is cached.
    // Currently this freezes the game for a second but I guess that's tolerable?

    // TODO: Reload event callbacks

    // These MUST be imported at the top of the file and not referred to by fully qualified name,
    // to ensure build macros work properly.
    SongEventRegistry.loadEventCache();

    SongRegistry.instance.loadEntries();
    LevelRegistry.instance.loadEntries();
    NoteStyleRegistry.instance.loadEntries();
    PlayerRegistry.instance.loadEntries();
    ConversationRegistry.instance.loadEntries();
    DialogueBoxRegistry.instance.loadEntries();
    SpeakerRegistry.instance.loadEntries();
    AlbumRegistry.instance.loadEntries();
    StageRegistry.instance.loadEntries();
    StickerRegistry.instance.loadEntries();
    FreeplayStyleRegistry.instance.loadEntries();

    CharacterDataParser.loadCharacterCache(); // TODO: Migrate characters to BaseRegistry.
    NoteKindManager.initialize();
  }
}
