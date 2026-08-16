#include <globals.h>
#include <gamelib/include/gamelib.h>
inherit WAP_ROOM;
string room_race="third";
protected int room_level=61;
protected void create(){
	name=object_name(this_object());
	name_cn="东胜朝生港";
	desc="城中人晨生、午壮、暮老、夜逝，却仍认真相爱、守城和告别。有限的一日被他们活得比千年不老更完整。\n";
	exits["east"]=ROOT "/gamelib/d/illusion_s1/abyss_garden.pike";
	exits["south"]=ROOT "/gamelib/d/illusion_s1/dongsheng_fusang_altar.pike";
}
string query_links(){ return "[聆听朝生之誓:illusion_realm witness]\n"; }
