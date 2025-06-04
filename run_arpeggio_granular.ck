0 => int id;
if ( me.args() )
{
  me.arg(0) => Std.atoi => id;
}
Machine.add( "sound_files.ck" );
// if (!(me.args() >= 2 && me.arg(1) == "g")) // flag to just run arpeggio
// {
//   Machine.add( "arpeggio_hive.ck:"+id );
// }
// if (!(me.args() >= 2 && me.arg(1) == "a")) // flag to just run arpeggio
// {
//   Machine.add( "granular.ck:"+id );
// }
Machine.add( "granular.ck:"+id );

