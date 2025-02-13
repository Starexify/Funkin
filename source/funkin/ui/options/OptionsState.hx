package funkin.ui.options;

import funkin.ui.transition.LoadingState;
import funkin.ui.debug.latency.LatencyState;
import flixel.FlxSprite;
import flixel.FlxSubState;
import flixel.group.FlxGroup;
import flixel.util.FlxSignal;
import funkin.audio.FunkinSound;
import funkin.ui.mainmenu.MainMenuState;
import funkin.ui.MusicBeatState;
import funkin.graphics.shaders.HSVShader;
import funkin.input.Controls;
#if FEATURE_NEWGROUNDS
import funkin.api.newgrounds.NewgroundsClient;
#end

class OptionsState extends MusicBeatState
{
  var pages = new Map<PageName, Page>();
  var currentName:PageName = Options;
  var currentPage(get, never):Page;

  inline function get_currentPage():Page
    return pages[currentName];

  override function create():Void
  {
    persistentUpdate = true;

    var menuBG = new FlxSprite().loadGraphic(Paths.image('menuBG'));
    var hsv = new HSVShader();
    hsv.hue = -0.6;
    hsv.saturation = 0.9;
    hsv.value = 3.6;
    menuBG.shader = hsv;
    FlxG.debugger.track(hsv);
    menuBG.setGraphicSize(Std.int(menuBG.width * 1.1));
    menuBG.updateHitbox();
    menuBG.screenCenter();
    menuBG.scrollFactor.set(0, 0);
    add(menuBG);

    var options = addPage(Options, new OptionsMenu());
    var preferences = addPage(Preferences, new PreferencesMenu());
    var controls = addPage(Controls, new ControlsMenu());

    if (options.hasMultipleOptions())
    {
      options.onExit.add(exitToMainMenu);
      controls.onExit.add(exitControls);
      preferences.onExit.add(switchPage.bind(Options));
    }
    else
    {
      // No need to show Options page
      controls.onExit.add(exitToMainMenu);
      setPage(Controls);
    }

    super.create();
  }

  function addPage<T:Page>(name:PageName, page:T)
  {
    page.onSwitch.add(switchPage);
    pages[name] = page;
    add(page);
    page.exists = currentName == name;
    return page;
  }

  function setPage(name:PageName)
  {
    if (pages.exists(currentName))
    {
      currentPage.exists = false;
      currentPage.visible = false;
    }

    currentName = name;

    if (pages.exists(currentName))
    {
      currentPage.exists = true;
      currentPage.visible = true;
    }
  }

  function switchPage(name:PageName)
  {
    // TODO: Animate this transition?
    setPage(name);
  }

  function exitControls():Void
  {
    // Apply any changes to the controls.
    PlayerSettings.reset();
    PlayerSettings.init();

    switchPage(Options);
  }

  function exitToMainMenu()
  {
    currentPage.enabled = false;
    // TODO: Animate this transition?
    FlxG.switchState(() -> new MainMenuState());
  }
}

class Page extends FlxGroup
{
  public var onSwitch(default, null) = new FlxTypedSignal<PageName->Void>();
  public var onExit(default, null) = new FlxSignal();

  public var enabled(default, set) = true;
  public var canExit = true;

  var controls(get, never):Controls;

  inline function get_controls()
    return PlayerSettings.player1.controls;

  var subState:FlxSubState;

  inline function switchPage(name:PageName)
  {
    onSwitch.dispatch(name);
  }

  inline function exit()
  {
    onExit.dispatch();
  }

  override function update(elapsed:Float)
  {
    super.update(elapsed);

    if (enabled) updateEnabled(elapsed);
  }

  function updateEnabled(elapsed:Float)
  {
    if (canExit && controls.BACK)
    {
      exit();
      FunkinSound.playOnce(Paths.sound('cancelMenu'));
    }
  }

  function set_enabled(value:Bool)
  {
    return this.enabled = value;
  }

  function openPrompt(prompt:Prompt, onClose:Void->Void)
  {
    enabled = false;
    prompt.closeCallback = function() {
      enabled = true;
      if (onClose != null) onClose();
    }

    FlxG.state.openSubState(prompt);
  }

  override function destroy()
  {
    super.destroy();
    onSwitch.removeAll();
  }
}

class OptionsMenu extends Page
{
  var items:TextMenuList;

  public function new()
  {
    super();

    add(items = new TextMenuList());
    createItem("PREFERENCES", function() switchPage(Preferences));
    createItem("CONTROLS", function() switchPage(Controls));
    createItem("INPUT OFFSETS", function() {
      #if web
      LoadingState.transitionToState(() -> new LatencyState());
      #else
      FlxG.state.openSubState(new LatencyState());
      #end
    });

    #if FEATURE_NEWGROUNDS
    if (NewgroundsClient.instance.isLoggedIn())
    {
      createItem("LOGOUT OF NG", function() {
        NewgroundsClient.instance.logout(function() {
          // Reset the options menu when logout succeeds.
          // This means the login option will be displayed.
          FlxG.resetState();
        }, function() {
          FlxG.log.warn("Newgrounds logout failed!");
        });
      });
    }
    else
    {
      createItem("LOGIN TO NG", function() {
        NewgroundsClient.instance.login(function() {
          // Reset the options menu when login succeeds.
          // This means the logout option will be displayed.

          // NOTE: If the user presses login and opens the browser,
          // then navigates the UI
          FlxG.resetState();
        }, function() {
          FlxG.log.warn("Newgrounds login failed!");
        });
      });
    }
    #end

    createItem("EXIT", exit);
  }

  function createItem(name:String, callback:Void->Void, fireInstantly = false)
  {
    var item = items.createItem(0, 100 + items.length * 100, name, BOLD, callback);
    item.fireInstantly = fireInstantly;
    item.screenCenter(X);
    return item;
  }

  override function set_enabled(value:Bool)
  {
    items.enabled = value;
    return super.set_enabled(value);
  }

  /**
   * True if this page has multiple options, excluding the exit option.
   * If false, there's no reason to ever show this page.
   */
  public function hasMultipleOptions():Bool
  {
    return items.length > 2;
  }
}

enum abstract PageName(String)
{
  var Options = "options";
  var Controls = "controls";
  var Colors = "colors";
  var Mods = "mods";
  var Preferences = "preferences";
}
