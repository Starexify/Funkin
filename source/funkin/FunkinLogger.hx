package funkin;

import haxe.Log;
import haxe.PosInfos;

class FunkinLogger
{
  public static function log(v:Dynamic, ?tag:String = '', ?infos:PosInfos):Void
  {
    print('', tag, v, infos);
  }

  public static function warn(v:Dynamic, ?tag:String = '', ?infos:PosInfos):Void
  {
    print(' WARN '.warning(), tag, v, infos);
  }

  public static function error(v:Dynamic, ?tag:String = '', ?infos:PosInfos):Void
  {
    print(' ERROR '.error(), tag, v, infos);
  }

  public static function info(v:Dynamic, ?tag:String = '', ?infos:PosInfos):Void
  {
    print(' INFO '.info(), tag, v, infos);
  }

  public static function fatal(v:Dynamic, ?tag:String = '', ?infos:PosInfos):Void
  {
    print(' FATAL '.bold().bg_red(), tag, v, infos);

    var tagStr = tag != '' ? '[$tag] ' : '';
    throw '$tagStr$v';
  }

  static function print(level:String, tag:String, message:Dynamic, ?infos:PosInfos):Void
  {
    final levelLabel = level != '' ? level + ' ' : '';
    final tagLabel = tag != '' ? tag + ' ' : '';

    Log.trace(levelLabel + tagLabel + message, infos);
  }
}
